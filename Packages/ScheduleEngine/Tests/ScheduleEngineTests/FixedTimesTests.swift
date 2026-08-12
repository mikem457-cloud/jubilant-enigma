import Foundation
import Testing
@testable import ScheduleEngine

@Suite("fixedTimes — daily, weekday sets, DST, exotic zones")
struct FixedTimesTests {

    @Test("Twice daily in UTC: six occurrences over three days, sequential indexes")
    func twiceDailyBasic() {
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
                                 days: .daily, amount: oneTablet),
                     anchor: utc(2026, 1, 5))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 5), to: utc(2026, 1, 8),
                                             using: clock("UTC"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 1, 5, 8, 0), utc(2026, 1, 5, 20, 0),
            utc(2026, 1, 6, 8, 0), utc(2026, 1, 6, 20, 0),
            utc(2026, 1, 7, 8, 0), utc(2026, 1, 7, 20, 0),
        ])
        #expect(occ.map(\.sequenceIndex) == [0, 1, 2, 3, 4, 5])
    }

    @Test("Times on the anchor day earlier than the anchor instant are not occurrences")
    func anchorMidDay() {
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
                                 days: .daily, amount: oneTablet),
                     anchor: utc(2026, 1, 5, 12, 0))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 5), to: utc(2026, 1, 6),
                                             using: clock("UTC"))
        #expect(occ.map(\.scheduledAt) == [utc(2026, 1, 5, 20, 0)])
        #expect(occ.first?.sequenceIndex == 0)
    }

    @Test("Mon/Wed/Fri weekday set fires only on those days")
    func weekdaySet() {
        // 2026-01-05 is a Monday.
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 9, minute: 0)],
                                 days: .weekdays([.monday, .wednesday, .friday]),
                                 amount: oneTablet),
                     anchor: utc(2026, 1, 5))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 5), to: utc(2026, 1, 12),
                                             using: clock("UTC"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 1, 5, 9, 0),   // Mon
            utc(2026, 1, 7, 9, 0),   // Wed
            utc(2026, 1, 9, 9, 0),   // Fri
        ])
    }

    @Test("Chicago spring-forward: nonexistent 02:30 fires at 03:00 CDT")
    func springForwardGap() {
        // US DST begins 2026-03-08: 02:00 CST → 03:00 CDT.
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 2, minute: 30)],
                                 days: .daily, amount: oneTablet),
                     anchor: wall(2026, 3, 7, 0, 0, in: "America/Chicago"))
        let occ = ScheduleEngine.occurrences(
            for: s,
            from: utc(2026, 3, 7), to: utc(2026, 3, 10),
            using: clock("America/Chicago"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 3, 7, 8, 30),   // 02:30 CST (UTC-6)
            utc(2026, 3, 8, 8, 0),    // gap day → 03:00 CDT (UTC-5)
            utc(2026, 3, 9, 7, 30),   // 02:30 CDT
        ])
    }

    @Test("Chicago fall-back: repeated 01:30 fires once, at the first occurrence")
    func fallBackRepeat() {
        // US DST ends 2026-11-01: 02:00 CDT → 01:00 CST; 01:30 exists twice.
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 1, minute: 30)],
                                 days: .daily, amount: oneTablet),
                     anchor: wall(2026, 10, 31, 0, 0, in: "America/Chicago"))
        let occ = ScheduleEngine.occurrences(
            for: s,
            from: utc(2026, 10, 31), to: utc(2026, 11, 3),
            using: clock("America/Chicago"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 10, 31, 6, 30),  // 01:30 CDT
            utc(2026, 11, 1, 6, 30),   // first 01:30 (CDT), not the 07:30 UTC repeat
            utc(2026, 11, 2, 7, 30),   // 01:30 CST
        ])
        // Exactly one occurrence on the fall-back day.
        let fallBackDay = occ.filter { $0.scheduledAt >= utc(2026, 11, 1) && $0.scheduledAt < utc(2026, 11, 2) }
        #expect(fallBackDay.count == 1)
    }

    @Test("Lord Howe: half-hour DST shift moves the UTC instant by 30 minutes")
    func lordHoweHalfHourDST() {
        // LHST +10:30 → LHDT +11:00 on 2026-10-04 (02:00 → 02:30).
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 8, minute: 0)],
                                 days: .daily, amount: oneTablet),
                     anchor: wall(2026, 10, 2, 0, 0, in: "Australia/Lord_Howe"))
        let occ = ScheduleEngine.occurrences(
            for: s,
            from: utc(2026, 10, 2), to: utc(2026, 10, 5, 12, 0),
            using: clock("Australia/Lord_Howe"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 10, 2, 21, 30),  // Oct 3 08:00 +10:30
            utc(2026, 10, 3, 21, 0),   // Oct 4 08:00 +11:00 — shifted 30 min
            utc(2026, 10, 4, 21, 0),   // Oct 5 08:00 +11:00
        ])
    }

    @Test("Kolkata: no DST, +05:30 offset is stable year-round")
    func kolkataStable() {
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 9, minute: 0)],
                                 days: .daily, amount: oneTablet),
                     anchor: wall(2026, 3, 1, 0, 0, in: "Asia/Kolkata"))
        let occ = ScheduleEngine.occurrences(
            for: s,
            from: utc(2026, 3, 1), to: utc(2026, 3, 4),
            using: clock("Asia/Kolkata"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 3, 1, 3, 30),
            utc(2026, 3, 2, 3, 30),
            utc(2026, 3, 3, 3, 30),
        ])
    }

    @Test("Kiritimati (UTC+14): occurrences land on the correct side of the date line")
    func kiritimatiDateLine() {
        let anchor = wall(2026, 1, 5, 0, 0, in: "Pacific/Kiritimati")  // = 2026-01-04 10:00 UTC
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 8, minute: 0)],
                                 days: .daily, amount: oneTablet),
                     anchor: anchor)
        let occ = ScheduleEngine.occurrences(
            for: s,
            from: anchor, to: utc(2026, 1, 6, 10, 0),
            using: clock("Pacific/Kiritimati"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 1, 4, 18, 0),   // local Jan 5, 08:00
            utc(2026, 1, 5, 18, 0),   // local Jan 6, 08:00
        ])
    }
}
