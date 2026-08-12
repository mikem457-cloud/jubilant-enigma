import Foundation
import Testing
@testable import ScheduleEngine

@Suite("Finite courses, intervals, PRN, revisions, run-out")
struct CourseIntervalTests {

    // MARK: Finite courses

    @Test("'14 tablets then stop': exactly 14 occurrences, then silence forever")
    func fourteenDosesThenStop() {
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
                                 days: .daily, amount: oneTablet),
                     anchor: utc(2026, 1, 1),
                     end: .afterTotalDoses(14))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 1), to: utc(2026, 2, 1),
                                             using: clock("UTC"))
        #expect(occ.count == 14)
        #expect(occ.last?.scheduledAt == utc(2026, 1, 7, 20, 0))
        #expect(occ.last?.sequenceIndex == 13)

        // A window entirely after the course end sees nothing.
        let after = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 8), to: utc(2026, 2, 1),
                                               using: clock("UTC"))
        #expect(after.isEmpty)
    }

    @Test("A count-limited window deep into a course still terminates correctly")
    func finiteCourseWindowStraddle() {
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
                                 days: .daily, amount: oneTablet),
                     anchor: utc(2026, 1, 1),
                     end: .afterTotalDoses(14))
        // Window covers days 6–10; the course ends day 7 evening.
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 6), to: utc(2026, 1, 11),
                                             using: clock("UTC"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 1, 6, 8, 0), utc(2026, 1, 6, 20, 0),
            utc(2026, 1, 7, 8, 0), utc(2026, 1, 7, 20, 0),
        ])
        #expect(occ.map(\.sequenceIndex) == [10, 11, 12, 13])
    }

    @Test("endPolicy.onDate includes the whole last day, excludes the next")
    func endOnDate() {
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 8, minute: 0)], days: .daily, amount: oneTablet),
                     anchor: utc(2026, 1, 1),
                     end: .onDate(DateOnly(year: 2026, month: 1, day: 7)))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 1), to: utc(2026, 2, 1),
                                             using: clock("UTC"))
        #expect(occ.count == 7)
        #expect(occ.last?.scheduledAt == utc(2026, 1, 7, 8, 0))
    }

    // MARK: Interval

    @Test("Every 12 h from the anchor when no dose has been given yet")
    func intervalFromAnchor() {
        let s = spec(.interval(hours: 12, amount: oneTablet), anchor: utc(2026, 1, 5, 8, 0))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 5), to: utc(2026, 1, 7),
                                             using: clock("UTC"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 1, 5, 8, 0), utc(2026, 1, 5, 20, 0),
            utc(2026, 1, 6, 8, 0), utc(2026, 1, 6, 20, 0),
        ])
        #expect(occ.map(\.sequenceIndex) == [0, 1, 2, 3])
    }

    @Test("A late dose pushes the whole chain later — the interval drifts with reality")
    func intervalAfterLateDose() {
        let s = spec(.interval(hours: 12, amount: oneTablet), anchor: utc(2026, 1, 5, 8, 0))
        // Scheduled 08:00 dose actually given at 09:30.
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 5), to: utc(2026, 1, 6, 12, 0),
                                             lastCompleted: utc(2026, 1, 5, 9, 30),
                                             using: clock("UTC"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 1, 5, 21, 30),
            utc(2026, 1, 6, 9, 30),
        ])
        #expect(occ.first?.sequenceIndex == 1)
    }

    @Test("12 elapsed hours across spring-forward is 12 real hours, 13 wall hours")
    func intervalAcrossDST() {
        let s = spec(.interval(hours: 12, amount: oneTablet),
                     anchor: wall(2026, 3, 7, 20, 0, in: "America/Chicago"))
        // Dose given 20:00 CST Mar 7 (= 02:00 UTC Mar 8); DST begins during the night.
        let occ = ScheduleEngine.occurrences(
            for: s,
            from: utc(2026, 3, 8), to: utc(2026, 3, 8, 20, 0),
            lastCompleted: wall(2026, 3, 7, 20, 0, in: "America/Chicago"),
            using: clock("America/Chicago"))
        // 02:00 UTC + 12h = 14:00 UTC = 09:00 CDT — 13 hours on the wall clock.
        #expect(occ.first?.scheduledAt == utc(2026, 3, 8, 14, 0))
    }

    // MARK: PRN

    @Test("PRN gap: next allowed dose is lastCompleted + minimum gap")
    func prnGap() {
        let now = utc(2026, 1, 5, 12, 0)
        let next = ScheduleEngine.nextAllowedDose(
            minimumGapHours: 6, maxPerDay: nil,
            lastCompleted: utc(2026, 1, 5, 10, 0), dosesToday: 2,
            using: clock("UTC", now: now))
        #expect(next == utc(2026, 1, 5, 16, 0))
    }

    @Test("PRN daily cap reached: next allowed dose is tomorrow")
    func prnCap() {
        let now = utc(2026, 1, 5, 12, 0)
        let next = ScheduleEngine.nextAllowedDose(
            minimumGapHours: 4, maxPerDay: 3,
            lastCompleted: utc(2026, 1, 5, 11, 0), dosesToday: 3,
            using: clock("UTC", now: now))
        #expect(next == utc(2026, 1, 6, 0, 0))
    }

    @Test("PRN with no history is available now")
    func prnNoHistory() {
        let now = utc(2026, 1, 5, 12, 0)
        let next = ScheduleEngine.nextAllowedDose(
            minimumGapHours: 6, maxPerDay: nil,
            lastCompleted: nil, dosesToday: 0,
            using: clock("UTC", now: now))
        #expect(next == now)
    }

    // MARK: Revisions

    @Test("Revision boundary: old schedule governs before effectiveFrom, new after")
    func revisionSwitch() {
        let revA = spec(.fixedTimes(times: [TimeOfDay(hour: 8, minute: 0)], days: .daily, amount: oneTablet),
                        anchor: utc(2026, 1, 1))
        let revB = spec(.fixedTimes(times: [TimeOfDay(hour: 20, minute: 0)], days: .daily,
                                    amount: DoseAmount(value: 0.5, unit: "tablet")),
                        anchor: utc(2026, 1, 4), effectiveFrom: utc(2026, 1, 4))
        let occ = ScheduleEngine.occurrences(
            forRevisions: [revA, revB],
            from: utc(2026, 1, 1), to: utc(2026, 1, 7),
            using: clock("UTC"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 1, 1, 8, 0), utc(2026, 1, 2, 8, 0), utc(2026, 1, 3, 8, 0),
            utc(2026, 1, 4, 20, 0), utc(2026, 1, 5, 20, 0), utc(2026, 1, 6, 20, 0),
        ])
        #expect(occ.suffix(3).allSatisfy { $0.amount.value == 0.5 })
    }

    // MARK: Run-out projection

    @Test("Run-out is the first dose the remaining stock can't cover")
    func projectRunOut() {
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
                                 days: .daily, amount: oneTablet),
                     anchor: utc(2026, 1, 1))
        let runOut = ScheduleEngine.projectRunOut(
            unitsOnHand: 5, spec: s,
            using: clock("UTC", now: utc(2026, 1, 1)))
        // Doses 1–5 consume the stock; the 6th (day 3, 20:00) has nothing left.
        #expect(runOut == utc(2026, 1, 3, 20, 0))
    }

    @Test("Ample stock for a finite course never runs out")
    func projectRunOutFiniteCourse() {
        let s = spec(.fixedTimes(times: [TimeOfDay(hour: 8, minute: 0)], days: .daily, amount: oneTablet),
                     anchor: utc(2026, 1, 1),
                     end: .afterTotalDoses(10))
        let runOut = ScheduleEngine.projectRunOut(
            unitsOnHand: 20, spec: s,
            using: clock("UTC", now: utc(2026, 1, 1)))
        #expect(runOut == nil)
    }
}
