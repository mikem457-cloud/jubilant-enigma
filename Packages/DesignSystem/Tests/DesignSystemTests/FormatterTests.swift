import Foundation
import Testing
@testable import DesignSystem

@Suite("FSFormat")
struct FormatterTests {

    @Test("Weight renders one decimal in the chosen unit")
    func weight() {
        #expect(FSFormat.weight(grams: 12_400, unit: .kilograms) == "12.4 kg")
        #expect(FSFormat.weight(grams: 12_400, unit: .pounds) == "27.3 lb")
        #expect(FSFormat.weight(grams: 1000, unit: .kilograms) == "1 kg")
        #expect(FSFormat.weight(grams: 453, unit: .pounds) == "1 lb")
    }

    @Test("Dose amounts pluralize count nouns and leave abbreviations alone")
    func doseAmounts() {
        #expect(FSFormat.doseAmount(value: 1, unit: "tablet") == "1 tablet")
        #expect(FSFormat.doseAmount(value: 1.5, unit: "tablet") == "1.5 tablets")
        #expect(FSFormat.doseAmount(value: 0.5, unit: "tablet") == "0.5 tablets")
        #expect(FSFormat.doseAmount(value: 2, unit: "chew") == "2 chews")
        #expect(FSFormat.doseAmount(value: 2, unit: "mg") == "2 mg")
        #expect(FSFormat.doseAmount(value: 2.5, unit: "mL") == "2.5 mL")
        #expect(FSFormat.doseAmount(value: 3, unit: "IU") == "3 IU")
        #expect(FSFormat.doseAmount(value: 2, unit: "units") == "2 units")
    }

    @Test("Numbers trim trailing zeros without grouping separators")
    func numbers() {
        #expect(FSFormat.number(1.0, maxFractionDigits: 2) == "1")
        #expect(FSFormat.number(1.50, maxFractionDigits: 2) == "1.5")
        #expect(FSFormat.number(0.25, maxFractionDigits: 2) == "0.25")
        #expect(FSFormat.number(1234.5, maxFractionDigits: 1) == "1234.5")
    }

    @Test("Time of day in both clock styles, including midnight and noon")
    func times() {
        #expect(FSFormat.timeOfDay(hour: 8, minute: 5, style: .twelveHour) == "8:05 AM")
        #expect(FSFormat.timeOfDay(hour: 20, minute: 0, style: .twelveHour) == "8:00 PM")
        #expect(FSFormat.timeOfDay(hour: 0, minute: 30, style: .twelveHour) == "12:30 AM")
        #expect(FSFormat.timeOfDay(hour: 12, minute: 0, style: .twelveHour) == "12:00 PM")
        #expect(FSFormat.timeOfDay(hour: 8, minute: 5, style: .twentyFourHour) == "08:05")
        #expect(FSFormat.timeOfDay(hour: 20, minute: 0, style: .twentyFourHour) == "20:00")
    }
}
