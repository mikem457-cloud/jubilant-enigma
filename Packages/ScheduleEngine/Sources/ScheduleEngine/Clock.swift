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

/// The app's live clock. The device zone is captured at init — construct a
/// fresh SystemClock per unit of work (views already do) so zone changes are
/// picked up, while repeated `calendar` accesses inside one computation stay
/// free instead of rebuilding a Calendar each time.
public struct SystemClock: ScheduleEngineClock {
    public let timeZone: TimeZone
    public let calendar: Calendar

    public init() {
        let zone = TimeZone.current
        self.timeZone = zone
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = zone
        self.calendar = cal
    }

    public var now: Date { Date() }
}
