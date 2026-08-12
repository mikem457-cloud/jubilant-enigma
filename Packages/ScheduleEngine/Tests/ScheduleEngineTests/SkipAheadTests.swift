import Foundation
import Testing
@testable import ScheduleEngine

@Suite("Skip-ahead: old anchors stay fast and sequence-correct")
struct SkipAheadTests {

    @Test("A two-year-old daily schedule yields correct instants and sequence indexes")
    func oldAnchorDailySequence() {
        // Anchored mid-day so day 0 contributes only the evening dose —
        // the skip-ahead must count that day precisely.
        let anchor = utc(2024, 1, 1, 12, 0)
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
                                 days: .daily, amount: oneTablet),
                     anchor: anchor)
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 5), to: utc(2026, 1, 6),
                                             using: clock("UTC"))
        #expect(occ.map(\.scheduledAt) == [utc(2026, 1, 5, 8, 0), utc(2026, 1, 5, 20, 0)])

        // Independent count: day 0 emits 1 (20:00 only), every full day after
        // emits 2, so Jan 5 2026's 08:00 dose is number (fullDays-1)*2 + 1.
        let fullDays = utcCalendar.dateComponents([.day], from: utc(2024, 1, 1), to: utc(2026, 1, 5)).day!
        let expectedFirst = (fullDays - 1) * 2 + 1
        #expect(occ.map(\.sequenceIndex) == [expectedFirst, expectedFirst + 1])
    }

    @Test("Skip-ahead agrees exactly with the unskipped (capped) path")
    func skipMatchesUnskippedPath() {
        // .afterTotalDoses disables skip-ahead, forcing the full day walk.
        // A generous cap that never binds must produce identical output.
        let anchor = utc(2025, 3, 10, 9, 30)
        let schedule = DoseSchedule.fixedTimes(
            times: [TimeOfDay(hour: 7, minute: 0), TimeOfDay(hour: 19, minute: 0)],
            days: .weekdays([.monday, .wednesday, .friday]),
            amount: oneTablet)
        let open = spec(schedule, anchor: anchor)
        let capped = spec(schedule, anchor: anchor, end: .afterTotalDoses(100_000))

        let windowStart = utc(2026, 2, 2)
        let windowEnd = utc(2026, 2, 9)
        let fast = ScheduleEngine.occurrences(for: open, from: windowStart, to: windowEnd,
                                              using: clock("America/Chicago"))
        let slow = ScheduleEngine.occurrences(for: capped, from: windowStart, to: windowEnd,
                                              using: clock("America/Chicago"))
        #expect(!fast.isEmpty)
        #expect(fast.map(\.scheduledAt) == slow.map(\.scheduledAt))
        #expect(fast.map(\.sequenceIndex) == slow.map(\.sequenceIndex))
    }

    @Test("Weekday-set skip counts only matching days toward the sequence")
    func weekdaySkipSequence() {
        // Anchor Mon 2026-01-05; Mon/Wed/Fri at 09:00. By Fri Jan 30 (day 25),
        // 11 occurrences precede it (indices 0,2,4,7,9,11,14,16,18,21,23).
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 9, minute: 0)],
                                 days: .weekdays([.monday, .wednesday, .friday]),
                                 amount: oneTablet),
                     anchor: utc(2026, 1, 5))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 30), to: utc(2026, 1, 31),
                                             using: clock("UTC"))
        #expect(occ.map(\.scheduledAt) == [utc(2026, 1, 30, 9, 0)])
        #expect(occ.first?.sequenceIndex == 11)
    }

    @Test("An old cyclic schedule keeps its on/off phase through the skip")
    func cyclicSkipKeepsPhase() {
        // 5 on / 2 off anchored 2025-01-01. Day index of 2026-01-05 is 369;
        // 369 % 7 = 5 → an off day. 2026-01-07 (371; 371 % 7 = 0) is on.
        let s = spec(.cyclic(daysOn: 5, daysOff: 2, times: [TimeOfDay(hour: 9, minute: 0)],
                             amount: oneTablet),
                     anchor: utc(2025, 1, 1))
        let offDay = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 5), to: utc(2026, 1, 6),
                                                using: clock("UTC"))
        #expect(offDay.isEmpty)
        let onDay = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 7), to: utc(2026, 1, 8),
                                               using: clock("UTC"))
        #expect(onDay.map(\.scheduledAt) == [utc(2026, 1, 7, 9, 0)])
    }
}
