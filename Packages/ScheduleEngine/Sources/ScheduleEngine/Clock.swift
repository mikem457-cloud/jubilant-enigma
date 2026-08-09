import Foundation

/// The only source of time in this package. Engine functions never call
/// `Date()` — every function takes a clock, which is what makes "does it
/// survive DST?" a test rather than a hope (01-ARCHITECTURE.md §4). The single
/// sanctioned `Date()` call lives in `SystemClock`, the production boundary.
public protocol ScheduleEngineClock: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
    var timeZone: TimeZone { get }
}

/// Fixed clock for tests and previews.
public struct FixedClock: ScheduleEngineClock {
    public let now: Date
    public let calendar: Calendar
    public let timeZone: TimeZone

    public init(now: Date, timeZoneIdentifier: String) {
        guard let zone = TimeZone(identifier: timeZoneIdentifier) else {
            preconditionFailure("Unknown time zone identifier: \(timeZoneIdentifier)")
        }
        self.init(now: now, timeZone: zone)
    }

    public init(now: Date, timeZone: TimeZone) {
        self.now = now
        self.timeZone = timeZone
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        self.calendar = cal
    }
}

/// The app's live clock. Constructed in `AppEnvironment`; the device zone is
/// re-read on each access so zone changes take effect without restart.
public struct SystemClock: ScheduleEngineClock {
    public init() {}

    public var now: Date { Date() }
    public var timeZone: TimeZone { TimeZone.current }
    public var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        return cal
    }
}
