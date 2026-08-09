import Foundation

/// Pure occurrence generation. No `Date()`, no stored state, no side effects.
public enum ScheduleEngine {

    /// Safety valve: no honest query needs more days than this (~10 years).
    private static let maxDaySpan = 3700

    // MARK: - Single revision

    /// All occurrences of `spec` with `windowStart <= scheduledAt < windowEnd`.
    ///
    /// - `lastCompleted`: the actual time of the most recent given dose. Drives
    ///   `.interval` chaining and `.asNeeded` gap enforcement; ignored by
    ///   calendar patterns.
    /// - `priorDoseCount`: for `.interval` + `.afterTotalDoses` only — the count
    ///   of doses already logged before `lastCompleted`, because a drifting
    ///   chain cannot reconstruct its own past. Calendar patterns count their
    ///   own occurrences from the anchor and ignore this.
    public static func occurrences(
        for spec: ScheduleSpec,
        from windowStart: Date,
        to windowEnd: Date,
        lastCompleted: Date? = nil,
        priorDoseCount: Int = 0,
        using clock: some ScheduleEngineClock
    ) -> [DoseOccurrence] {
        guard windowStart < windowEnd else { return [] }
        let cal = clock.calendar

        // The course's hard end instant, if any (end-of-day, exclusive).
        let courseEnd: Date? = {
            if case .onDate(let d) = spec.endPolicy {
                return endOfDay(d, calendar: cal)
            }
            return nil
        }()
        let effectiveEnd = [windowEnd, courseEnd].compactMap { $0 }.min()!

        switch spec.schedule {
        case .fixedTimes(let times, let days, let amount):
            return calendarPattern(spec: spec, times: times, amount: amount,
                                   from: windowStart, to: effectiveEnd, calendar: cal) {
                dayIndex, weekday in
                _ = dayIndex
                return days.contains(calendarWeekday: weekday)
            }

        case .everyNDays(let n, let times, let amount):
            guard n >= 1 else { return [] }
            return calendarPattern(spec: spec, times: times, amount: amount,
                                   from: windowStart, to: effectiveEnd, calendar: cal) {
                dayIndex, _ in dayIndex % n == 0
            }

        case .cyclic(let daysOn, let daysOff, let times, let amount):
            guard daysOn >= 1, daysOff >= 0 else { return [] }
            let cycle = daysOn + daysOff
            return calendarPattern(spec: spec, times: times, amount: amount,
                                   from: windowStart, to: effectiveEnd, calendar: cal) {
                dayIndex, _ in dayIndex % cycle < daysOn
            }

        case .taper(let stages):
            return taperOccurrences(spec: spec, stages: stages,
                                    from: windowStart, to: effectiveEnd, calendar: cal)

        case .monthly(let day, let time, let amount):
            return monthlyOccurrences(spec: spec, day: day, time: time, amount: amount,
                                      from: windowStart, to: effectiveEnd, calendar: cal)

        case .interval(let hours, let amount):
            return intervalOccurrences(spec: spec, hours: hours, amount: amount,
                                       from: windowStart, to: effectiveEnd,
                                       lastCompleted: lastCompleted,
                                       priorDoseCount: priorDoseCount, calendar: cal)

        case .asNeeded(let gap, let maxPerDay, let amount):
            guard let available = nextAllowedDose(
                minimumGapHours: gap, maxPerDay: maxPerDay,
                lastCompleted: lastCompleted, dosesToday: nil, using: clock
            ) else { return [] }
            let at = max(available, windowStart)
            guard at < effectiveEnd else { return [] }
            return [DoseOccurrence(medicationID: spec.medicationID, scheduledAt: at,
                                   sequenceIndex: 0, amount: amount, stageLabel: nil)]
        }
    }

    // MARK: - Revision composition

    /// Occurrences across an ordered revision history (02-DATA-MODEL.md §3.1).
    /// Each revision governs `[effectiveFrom, next.effectiveFrom)`.
    public static func occurrences(
        forRevisions revisions: [ScheduleSpec],
        from windowStart: Date,
        to windowEnd: Date,
        lastCompleted: Date? = nil,
        priorDoseCount: Int = 0,
        using clock: some ScheduleEngineClock
    ) -> [DoseOccurrence] {
        let sorted = revisions.sorted { $0.effectiveFrom < $1.effectiveFrom }
        var result: [DoseOccurrence] = []
        for (i, spec) in sorted.enumerated() {
            let revEnd = i + 1 < sorted.count ? sorted[i + 1].effectiveFrom : windowEnd
            let start = max(windowStart, spec.effectiveFrom)
            let end = min(windowEnd, revEnd)
            guard start < end else { continue }
            result.append(contentsOf: occurrences(
                for: spec, from: start, to: end,
                lastCompleted: lastCompleted, priorDoseCount: priorDoseCount,
                using: clock))
        }
        return result.sorted { $0.scheduledAt < $1.scheduledAt }
    }

    // MARK: - PRN

    /// Earliest instant a PRN dose is allowed. `nil` only when the daily cap is
    /// exhausted and the next day hasn't been reached — callers pass
    /// `dosesToday` when they have today's log count; `nil` skips cap checks.
    public static func nextAllowedDose(
        minimumGapHours: Double,
        maxPerDay: Int?,
        lastCompleted: Date?,
        dosesToday: Int?,
        using clock: some ScheduleEngineClock
    ) -> Date? {
        let gapSeconds = Int((minimumGapHours * 3600).rounded())
        var candidate: Date
        if let last = lastCompleted {
            candidate = clock.calendar.date(byAdding: .second, value: gapSeconds, to: last) ?? last
        } else {
            candidate = clock.now
        }
        candidate = max(candidate, clock.now)

        if let cap = maxPerDay, let taken = dosesToday, taken >= cap {
            // Capped out: next allowed is the start of tomorrow (or the gap, whichever is later).
            let todayStart = clock.calendar.startOfDay(for: clock.now)
            guard let tomorrow = clock.calendar.date(byAdding: .day, value: 1, to: todayStart) else {
                return nil
            }
            candidate = max(candidate, tomorrow)
        }
        return candidate
    }

    // MARK: - Inventory projection

    /// Projected run-out instant: walks future occurrences decrementing
    /// `unitsOnHand` by each occurrence's amount. `nil` = no run-out within a
    /// year (or the course ends first).
    public static func projectRunOut(
        unitsOnHand: Double,
        spec: ScheduleSpec,
        lastCompleted: Date? = nil,
        using clock: some ScheduleEngineClock
    ) -> Date? {
        guard unitsOnHand > 0 else { return clock.now }
        guard let horizon = clock.calendar.date(byAdding: .day, value: 366, to: clock.now) else {
            return nil
        }
        var remaining = unitsOnHand
        let future = occurrences(for: spec, from: clock.now, to: horizon,
                                 lastCompleted: lastCompleted, using: clock)
        for occ in future {
            remaining -= occ.amount.value
            if remaining < 0 { return occ.scheduledAt }
        }
        return nil
    }

    // MARK: - Calendar-day patterns (fixedTimes / everyNDays / cyclic)

    /// Walks calendar days from the anchor day, asking `includeDay(dayIndex,
    /// calendarWeekday)` for each, emitting each listed time. Day stepping uses
    /// `Calendar.date(byAdding: .day)` — never `+86400` — so 23- and 25-hour
    /// DST days count as exactly one day.
    private static func calendarPattern(
        spec: ScheduleSpec,
        times: [TimeOfDay],
        amount: DoseAmount,
        from windowStart: Date,
        to windowEnd: Date,
        calendar cal: Calendar,
        includeDay: (Int, Int) -> Bool
    ) -> [DoseOccurrence] {
        guard !times.isEmpty else { return [] }
        let sortedTimes = times.sorted()
        let anchorDay = cal.startOfDay(for: spec.anchor)
        let totalCap = totalDoseCap(spec.endPolicy)

        var result: [DoseOccurrence] = []
        var sequence = 0
        for dayIndex in 0..<maxDaySpan {
            guard let dayStart = cal.date(byAdding: .day, value: dayIndex, to: anchorDay) else { break }
            if dayStart >= windowEnd { break }
            if let cap = totalCap, sequence >= cap { break }

            let weekday = cal.component(.weekday, from: dayStart)
            guard includeDay(dayIndex, weekday) else { continue }

            for t in sortedTimes {
                guard let at = instant(of: t, onDayStarting: dayStart, calendar: cal) else { continue }
                if at < spec.anchor { continue }        // regimen hasn't started yet
                if let cap = totalCap, sequence >= cap { break }
                if at >= windowStart && at < windowEnd {
                    result.append(DoseOccurrence(
                        medicationID: spec.medicationID, scheduledAt: at,
                        sequenceIndex: sequence, amount: amount, stageLabel: nil))
                }
                sequence += 1
            }
        }
        return result
    }

    // MARK: - Taper

    private static func taperOccurrences(
        spec: ScheduleSpec,
        stages: [TaperStage],
        from windowStart: Date,
        to windowEnd: Date,
        calendar cal: Calendar
    ) -> [DoseOccurrence] {
        guard !stages.isEmpty else { return [] }
        let anchorDay = cal.startOfDay(for: spec.anchor)
        let totalCap = totalDoseCap(spec.endPolicy)

        // Precompute each stage's first day index.
        var stageStartDay: [Int] = []
        var running = 0
        for stage in stages {
            stageStartDay.append(running)
            running += stage.durationDays ?? maxDaySpan
        }
        let lastStageIsOpen = stages.last?.durationDays == nil
        let totalDays = lastStageIsOpen ? maxDaySpan : min(running, maxDaySpan)

        var result: [DoseOccurrence] = []
        var sequence = 0
        for dayIndex in 0..<totalDays {
            guard let dayStart = cal.date(byAdding: .day, value: dayIndex, to: anchorDay) else { break }
            if dayStart >= windowEnd { break }
            if let cap = totalCap, sequence >= cap { break }

            // Which stage owns this day?
            guard let stageIdx = stageStartDay.lastIndex(where: { $0 <= dayIndex }) else { continue }
            let stage = stages[stageIdx]

            for t in stage.times.sorted() {
                guard let at = instant(of: t, onDayStarting: dayStart, calendar: cal) else { continue }
                if at < spec.anchor { continue }
                if let cap = totalCap, sequence >= cap { break }
                if at >= windowStart && at < windowEnd {
                    result.append(DoseOccurrence(
                        medicationID: spec.medicationID, scheduledAt: at,
                        sequenceIndex: sequence, amount: stage.amount,
                        stageLabel: stage.label))
                }
                sequence += 1
            }
        }
        return result
    }

    // MARK: - Monthly

    private static func monthlyOccurrences(
        spec: ScheduleSpec,
        day: Int,
        time: TimeOfDay,
        amount: DoseAmount,
        from windowStart: Date,
        to windowEnd: Date,
        calendar cal: Calendar
    ) -> [DoseOccurrence] {
        guard (1...31).contains(day) else { return [] }
        let totalCap = totalDoseCap(spec.endPolicy)

        var comps = cal.dateComponents([.year, .month], from: spec.anchor)
        comps.day = 1
        guard let anchorMonthStart = cal.date(from: comps) else { return [] }

        var result: [DoseOccurrence] = []
        var sequence = 0
        for monthOffset in 0..<123 {   // ~10 years
            guard let monthStart = cal.date(byAdding: .month, value: monthOffset, to: anchorMonthStart),
                  let dayRange = cal.range(of: .day, in: .month, for: monthStart)
            else { break }
            if monthStart >= windowEnd { break }
            if let cap = totalCap, sequence >= cap { break }

            let clamped = min(day, dayRange.count)
            guard let dayStart = cal.date(byAdding: .day, value: clamped - 1, to: monthStart),
                  let at = instant(of: time, onDayStarting: dayStart, calendar: cal)
            else { continue }
            if at < spec.anchor { continue }
            if at >= windowStart && at < windowEnd {
                result.append(DoseOccurrence(
                    medicationID: spec.medicationID, scheduledAt: at,
                    sequenceIndex: sequence, amount: amount, stageLabel: nil))
            }
            sequence += 1
        }
        return result
    }

    // MARK: - Interval

    /// Chains in elapsed real time from `lastCompleted ?? anchor`. Deliberately
    /// not calendar arithmetic: 12 hours is 12 hours through a DST transition.
    private static func intervalOccurrences(
        spec: ScheduleSpec,
        hours: Double,
        amount: DoseAmount,
        from windowStart: Date,
        to windowEnd: Date,
        lastCompleted: Date?,
        priorDoseCount: Int,
        calendar cal: Calendar
    ) -> [DoseOccurrence] {
        guard hours > 0 else { return [] }
        let stepSeconds = Int((hours * 3600).rounded())
        let totalCap = totalDoseCap(spec.endPolicy)

        // The chain restarts from each actual dose; before any dose it starts
        // at the anchor itself (the anchor is the first scheduled dose).
        var at: Date
        var sequence: Int
        if let last = lastCompleted {
            guard let next = cal.date(byAdding: .second, value: stepSeconds, to: last) else { return [] }
            at = next
            sequence = priorDoseCount + 1
        } else {
            at = spec.anchor
            sequence = 0
        }

        var result: [DoseOccurrence] = []
        for _ in 0..<20_000 {
            if at >= windowEnd { break }
            if let cap = totalCap, sequence >= cap { break }
            if at >= windowStart {
                result.append(DoseOccurrence(
                    medicationID: spec.medicationID, scheduledAt: at,
                    sequenceIndex: sequence, amount: amount, stageLabel: nil))
            }
            sequence += 1
            guard let next = cal.date(byAdding: .second, value: stepSeconds, to: at) else { break }
            at = next
        }
        return result
    }

    // MARK: - Shared helpers

    private static func totalDoseCap(_ policy: EndPolicy) -> Int? {
        if case .afterTotalDoses(let n) = policy { return n }
        return nil
    }

    /// Resolves a wall-clock time on a given day to an instant. Spring-forward
    /// gaps resolve to the first existing instant after the gap; fall-back
    /// repeats resolve to the first (earlier-offset) occurrence.
    private static func instant(of time: TimeOfDay, onDayStarting dayStart: Date, calendar cal: Calendar) -> Date? {
        cal.date(bySettingHour: time.hour, minute: time.minute, second: 0,
                 of: dayStart,
                 matchingPolicy: .nextTime,
                 repeatedTimePolicy: .first,
                 direction: .forward)
    }

    /// Exclusive end instant of a `DateOnly` (start of the following day).
    private static func endOfDay(_ d: DateOnly, calendar cal: Calendar) -> Date? {
        var comps = DateComponents()
        comps.year = d.year
        comps.month = d.month
        comps.day = d.day
        guard let dayStart = cal.date(from: comps) else { return nil }
        return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: dayStart))
    }
}
