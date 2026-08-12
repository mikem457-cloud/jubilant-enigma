import Foundation
@testable import ScheduleEngine

let utcCalendar: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
}()

/// An unambiguous instant, expressed in UTC. All test expectations are written
/// as UTC instants so DST-ambiguous wall times can't blur what's asserted.
func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
    var c = DateComponents()
    c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
    return utcCalendar.date(from: c)!
}

/// An instant from wall-clock components in a named zone. Only used where the
/// wall time is unambiguous (no DST gap/repeat at that instant).
func wall(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, in zoneID: String) -> Date {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: zoneID)!
    var c = DateComponents()
    c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute
    return cal.date(from: c)!
}

func clock(_ zoneID: String, now: Date = utc(2026, 1, 1)) -> FixedClock {
    FixedClock(now: now, timeZoneIdentifier: zoneID)
}

let medID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
let oneTablet = DoseAmount(value: 1, unit: "tablet")

func spec(
    _ schedule: DoseSchedule,
    anchor: Date,
    end: EndPolicy = .openEnded,
    effectiveFrom: Date? = nil
) -> ScheduleSpec {
    ScheduleSpec(medicationID: medID, schedule: schedule, anchor: anchor,
                 endPolicy: end, effectiveFrom: effectiveFrom)
}
