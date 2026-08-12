import Foundation

/// The seven dose patterns (02-DATA-MODEL.md §3.2). A schedule is pure data;
/// occurrence generation lives in `ScheduleEngine.occurrences`.
public enum DoseSchedule: Codable, Hashable, Sendable {
    /// 1. Fixed clock times, daily or on selected weekdays.
    case fixedTimes(times: [TimeOfDay], days: DaySelection, amount: DoseAmount)

    /// 2. Elapsed-time interval chained from the *actual* previous dose.
    ///    "Every 12 hours" is a pharmacological statement, not a wall-clock one.
    case interval(hours: Double, amount: DoseAmount)

    /// 3. Calendar-day stride from the anchor: "every 3 days at 9:00".
    case everyNDays(n: Int, times: [TimeOfDay], amount: DoseAmount)

    /// 4. On/off day blocks from the anchor: "5 days on, 2 days off".
    case cyclic(daysOn: Int, daysOff: Int, times: [TimeOfDay], amount: DoseAmount)

    /// 5. Ordered stages, each with its own times and amount.
    case taper(stages: [TaperStage])

    /// 6. Day-of-month, clamped to short months: day 31 fires Apr 30, Feb 28/29.
    case monthly(day: Int, time: TimeOfDay, amount: DoseAmount)

    /// 7. PRN with an enforced minimum gap and optional daily cap.
    case asNeeded(minimumGapHours: Double, maxPerDay: Int?, amount: DoseAmount)
}

/// One revision of a medication's schedule, decoded from
/// `ScheduleRevision` (02-DATA-MODEL.md §3.1).
public struct ScheduleSpec: Codable, Hashable, Sendable {
    public var medicationID: UUID
    public var schedule: DoseSchedule
    /// Regimen anchor: day 0 for cycles/tapers/strides, chain start for intervals.
    public var anchor: Date
    public var endPolicy: EndPolicy
    /// Instant this revision takes effect. Defaults to the anchor.
    public var effectiveFrom: Date

    public init(
        medicationID: UUID,
        schedule: DoseSchedule,
        anchor: Date,
        endPolicy: EndPolicy = .openEnded,
        effectiveFrom: Date? = nil
    ) {
        self.medicationID = medicationID
        self.schedule = schedule
        self.anchor = anchor
        self.endPolicy = endPolicy
        self.effectiveFrom = effectiveFrom ?? anchor
    }
}

/// A computed occurrence. Never persisted — logs bind to it by
/// `(medicationID, scheduledAt)`.
public struct DoseOccurrence: Hashable, Sendable {
    public var medicationID: UUID
    public var scheduledAt: Date
    /// 0-based position in the series generated from the revision anchor.
    public var sequenceIndex: Int
    public var amount: DoseAmount
    /// Taper stage label ("20 mg twice daily"); nil for other patterns.
    public var stageLabel: String?
}
