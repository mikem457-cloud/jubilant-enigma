import Foundation
import Testing
@testable import ScheduleEngine

@Suite("everyNDays, cyclic, taper, monthly")
struct PatternTests {

    @Test("Every 3 days strides from the anchor day")
    func everyThreeDays() {
        let s = spec(.everyNDays(n: 3, times: [TimeOfDay(hour: 9, minute: 0)], amount: oneTablet),
                     anchor: utc(2026, 1, 1))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 1), to: utc(2026, 1, 10),
                                             using: clock("UTC"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 1, 1, 9, 0),
            utc(2026, 1, 4, 9, 0),
            utc(2026, 1, 7, 9, 0),
        ])
    }

    @Test("Cyclic 5-on/2-off: off days produce nothing, cycle wraps correctly")
    func cyclicFiveTwo() {
        let s = spec(.cyclic(daysOn: 5, daysOff: 2, times: [TimeOfDay(hour: 9, minute: 0)], amount: oneTablet),
                     anchor: utc(2026, 1, 1))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 1), to: utc(2026, 1, 15),
                                             using: clock("UTC"))
        // Days 1–5 on, 6–7 off, 8–12 on, 13–14 off.
        let days = occ.map { utcCalendar.component(.day, from: $0.scheduledAt) }
        #expect(days == [1, 2, 3, 4, 5, 8, 9, 10, 11, 12])
        #expect(occ.count == 10)
    }

    @Test("Prednisone taper: stage boundaries, per-stage amounts and labels, continuous sequence")
    func prednisoneTaper() {
        let stages = [
            TaperStage(durationDays: 3,
                       times: [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)],
                       amount: DoseAmount(value: 20, unit: "mg"),
                       label: "20 mg twice daily"),
            TaperStage(durationDays: 3,
                       times: [TimeOfDay(hour: 8, minute: 0)],
                       amount: DoseAmount(value: 10, unit: "mg"),
                       label: "10 mg once daily"),
            TaperStage(durationDays: nil,   // open-ended maintenance
                       times: [TimeOfDay(hour: 8, minute: 0)],
                       amount: DoseAmount(value: 5, unit: "mg"),
                       label: "5 mg maintenance"),
        ]
        let s = spec(.taper(stages: stages), anchor: utc(2026, 1, 1))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 1), to: utc(2026, 1, 9),
                                             using: clock("UTC"))
        // Days 1–3: two doses; days 4–6: one dose; days 7–8: one dose (maintenance).
        #expect(occ.count == 6 + 3 + 2)
        #expect(occ.map(\.sequenceIndex) == Array(0...10))

        let day1 = occ.filter { utcCalendar.component(.day, from: $0.scheduledAt) == 1 }
        #expect(day1.count == 2)
        #expect(day1.allSatisfy { $0.stageLabel == "20 mg twice daily" && $0.amount.value == 20 })

        let day4 = occ.filter { utcCalendar.component(.day, from: $0.scheduledAt) == 4 }
        #expect(day4.map(\.stageLabel) == ["10 mg once daily"])

        let day7 = occ.filter { utcCalendar.component(.day, from: $0.scheduledAt) == 7 }
        #expect(day7.map(\.stageLabel) == ["5 mg maintenance"])
        #expect(day7.map(\.amount.value) == [5])
    }

    @Test("A taper with no open-ended stage terminates after its last stage")
    func taperFiniteEnds() {
        let stages = [
            TaperStage(durationDays: 2, times: [TimeOfDay(hour: 8, minute: 0)],
                       amount: DoseAmount(value: 10, unit: "mg"), label: "10 mg"),
            TaperStage(durationDays: 2, times: [TimeOfDay(hour: 8, minute: 0)],
                       amount: DoseAmount(value: 5, unit: "mg"), label: "5 mg"),
        ]
        let s = spec(.taper(stages: stages), anchor: utc(2026, 1, 1))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 1), to: utc(2026, 2, 1),
                                             using: clock("UTC"))
        #expect(occ.count == 4)
        #expect(occ.last?.scheduledAt == utc(2026, 1, 4, 8, 0))
    }

    @Test("Monthly day-31 clamps to short months without skipping or rolling over")
    func monthlyClamp31() {
        let s = spec(.monthly(day: 31, time: TimeOfDay(hour: 9, minute: 0), amount: oneTablet),
                     anchor: utc(2026, 1, 15))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2026, 1, 1), to: utc(2026, 5, 15),
                                             using: clock("UTC"))
        #expect(occ.map(\.scheduledAt) == [
            utc(2026, 1, 31, 9, 0),
            utc(2026, 2, 28, 9, 0),   // 2026 is not a leap year
            utc(2026, 3, 31, 9, 0),
            utc(2026, 4, 30, 9, 0),
        ])
        #expect(occ.map(\.sequenceIndex) == [0, 1, 2, 3])
    }

    @Test("Monthly day-30 lands on Feb 29 in a leap year")
    func monthlyLeapFeb() {
        let s = spec(.monthly(day: 30, time: TimeOfDay(hour: 9, minute: 0), amount: oneTablet),
                     anchor: utc(2028, 1, 1))
        let occ = ScheduleEngine.occurrences(for: s, from: utc(2028, 2, 1), to: utc(2028, 3, 1),
                                             using: clock("UTC"))
        #expect(occ.map(\.scheduledAt) == [utc(2028, 2, 29, 9, 0)])
    }
}
