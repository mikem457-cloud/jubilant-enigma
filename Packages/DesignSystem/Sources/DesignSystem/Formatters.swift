import Foundation

/// All user-facing value formatting goes through here — never string
/// interpolation in views (01-ARCHITECTURE.md §9). Pure Foundation, so the
/// rules are testable on any platform.
public enum FSFormat {

    public enum WeightUnit: String, Codable, Sendable {
        case kilograms, pounds
    }

    public enum ClockStyle: String, Codable, Sendable {
        case twelveHour, twentyFourHour
    }

    private static let gramsPerPound = 453.59237

    /// Canonical grams → display string. One decimal, unit suffix.
    /// 12_400 g → "12.4 kg" · "27.3 lb"
    public static func weight(grams: Int, unit: WeightUnit) -> String {
        let value: Double
        let suffix: String
        switch unit {
        case .kilograms:
            value = Double(grams) / 1000
            suffix = "kg"
        case .pounds:
            value = Double(grams) / gramsPerPound
            suffix = "lb"
        }
        return "\(number(value, maxFractionDigits: 1)) \(suffix)"
    }

    /// Dose amount → display string, unit verbatim from what the user typed.
    /// Pluralizes only obvious count nouns: an all-lowercase alphabetic unit of
    /// ≥3 letters not already ending in "s" ("tablet" → "tablets"); leaves
    /// abbreviations and symbols alone ("mg", "mL", "IU", "units").
    public static func doseAmount(value: Double, unit: String) -> String {
        var displayUnit = unit
        let isCountNoun = unit.count >= 3
            && unit == unit.lowercased()
            && unit.allSatisfy(\.isLetter)
            && !unit.hasSuffix("s")
        if isCountNoun && value != 1 {
            displayUnit += "s"
        }
        return "\(number(value, maxFractionDigits: 2)) \(displayUnit)"
    }

    /// Wall-clock time of day. Deterministic (not locale-driven) so schedules
    /// read identically everywhere; the *choice* of style is the user setting.
    /// (8, 5, .twelveHour) → "8:05 AM" · (20, 0, .twentyFourHour) → "20:00"
    public static func timeOfDay(hour: Int, minute: Int, style: ClockStyle) -> String {
        let mm = String(format: "%02d", minute)
        switch style {
        case .twentyFourHour:
            return String(format: "%02d:%@", hour, mm)
        case .twelveHour:
            let period = hour < 12 ? "AM" : "PM"
            var h = hour % 12
            if h == 0 { h = 12 }
            return "\(h):\(mm) \(period)"
        }
    }

    /// Trims trailing zeros: 1.0 → "1", 1.50 → "1.5", 0.25 → "0.25".
    static func number(_ value: Double, maxFractionDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
