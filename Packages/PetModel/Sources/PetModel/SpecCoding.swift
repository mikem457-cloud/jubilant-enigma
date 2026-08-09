#if canImport(SwiftData)
import Foundation
import ScheduleEngine

// The bridge between the persisted revision row and the engine's value types.
// Encoding is JSON: stable, diffable in exports, and bit-preserved by the
// .floofsync backup format (06-RECORDS-REPORTS-EXPORT.md §4).

extension ScheduleRevision {

    /// Decodes this revision into the engine-facing spec. `nil` means the
    /// stored data is unreadable — callers should treat the medication as
    /// unscheduled and surface it, not crash.
    public func spec(medicationID: UUID) -> ScheduleSpec? {
        guard let schedule = try? JSONDecoder().decode(DoseSchedule.self, from: scheduleData) else {
            return nil
        }
        let endPolicy = (try? JSONDecoder().decode(EndPolicy.self, from: endPolicyData)) ?? .openEnded
        return ScheduleSpec(
            medicationID: medicationID,
            schedule: schedule,
            anchor: anchorDate,
            endPolicy: endPolicy,
            effectiveFrom: effectiveFrom
        )
    }

    /// Builds a fully-encoded revision. Returns nil only if encoding fails,
    /// which for these Codable value types means programmer error.
    public static func make(
        schedule: DoseSchedule,
        anchor: Date,
        endPolicy: EndPolicy = .openEnded,
        effectiveFrom: Date? = nil,
        authorNote: String = "",
        createdAt: Date
    ) -> ScheduleRevision? {
        guard let scheduleData = try? JSONEncoder().encode(schedule),
              let endPolicyData = try? JSONEncoder().encode(endPolicy)
        else { return nil }
        let revision = ScheduleRevision()
        revision.createdAt = createdAt
        revision.effectiveFrom = effectiveFrom ?? anchor
        revision.scheduleData = scheduleData
        revision.anchorDate = anchor
        revision.endPolicyData = endPolicyData
        revision.authorNote = authorNote
        return revision
    }
}

extension Medication {
    /// All decodable revisions as engine specs, ordered by effectiveFrom.
    public func scheduleSpecs() -> [ScheduleSpec] {
        (revisions ?? [])
            .compactMap { $0.spec(medicationID: id) }
            .sorted { $0.effectiveFrom < $1.effectiveFrom }
    }
}
#endif
