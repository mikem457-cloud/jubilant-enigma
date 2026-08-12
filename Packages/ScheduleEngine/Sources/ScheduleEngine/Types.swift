import Foundation

/// A wall-clock time of day. Never a `Date` — "8:00 AM" is not an instant.
public struct TimeOfDay: Codable, Hashable, Sendable, Comparable {
    public var hour: Int
    public var minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}

/// A calendar date with no time component. Never a midnight `Date`.
public struct DateOnly: Codable, Hashable, Sendable, Comparable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    public init(of instant: Date, in calendar: Calendar) {
        let c = calendar.dateComponents([.year, .month, .day], from: instant)
        self.init(year: c.year ?? 1, month: c.month ?? 1, day: c.day ?? 1)
    }

    public static func < (lhs: DateOnly, rhs: DateOnly) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// ISO weekday numbering: Monday = 1 ... Sunday = 7.
public enum Weekday: Int, Codable, Hashable, Sendable, CaseIterable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday

    /// Foundation `Calendar.component(.weekday)` numbering (Sunday = 1 ... Saturday = 7).
    public var calendarWeekday: Int {
        self == .sunday ? 1 : rawValue + 1
    }

    public init?(calendarWeekday: Int) {
        self.init(rawValue: calendarWeekday == 1 ? 7 : calendarWeekday - 1)
    }
}

public enum DaySelection: Codable, Hashable, Sendable {
    case daily
    case weekdays(Set<Weekday>)

    func contains(calendarWeekday: Int) -> Bool {
        switch self {
        case .daily:
            return true
        case .weekdays(let set):
            guard let day = Weekday(calendarWeekday: calendarWeekday) else { return false }
            return set.contains(day)
        }
    }
}

/// What the vet prescribed, as entered by the user. The unit is display text —
/// the app never parses, converts, or computes doses (00-OVERVIEW.md §5).
public struct DoseAmount: Codable, Hashable, Sendable {
    public var value: Double
    public var unit: String

    public init(value: Double, unit: String) {
        self.value = value
        self.unit = unit
    }
}

public struct TaperStage: Codable, Hashable, Sendable {
    /// nil = final open-ended maintenance stage.
    public var durationDays: Int?
    public var times: [TimeOfDay]
    public var amount: DoseAmount
    public var label: String

    public init(durationDays: Int?, times: [TimeOfDay], amount: DoseAmount, label: String) {
        self.durationDays = durationDays
        self.times = times
        self.amount = amount
        self.label = label
    }
}

public enum EndPolicy: Codable, Hashable, Sendable {
    case openEnded
    /// "14 tablets then stop" — counts occurrences from the revision anchor.
    case afterTotalDoses(Int)
    /// Last day inclusive, evaluated in the clock's zone.
    case onDate(DateOnly)
}

public enum TimeZonePolicy: Codable, Hashable, Sendable {
    /// "8 AM wherever the phone is" — right for most medications.
    case localWallClock
    /// "8 AM Chicago time" — strict-interval regimens while travelling.
    case fixedZone(identifier: String)
}
