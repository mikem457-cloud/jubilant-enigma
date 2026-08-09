import Foundation
import SwiftData
import PetModel

/// The single ModelActor for all background writes (01-ARCHITECTURE.md §3).
/// Views use the main context for simple UI-driven CRUD; anything that runs
/// off the main thread — notification re-planning, import, OCR indexing, the
/// nightly missed-dose materialization — goes through here, always by
/// PersistentIdentifier, never by passing @Model instances across.
@ModelActor
actor DataActor {

    func petCount() throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<Pet>())
    }

    /// Nightly maintenance (02-DATA-MODEL.md §4): occurrences older than 48h
    /// with no log become DoseLog(.missed) so history survives schedule edits.
    /// Wired to a real trigger in Phase 2 alongside ReminderKit.
    func materializeMissedDoses(now: Date) throws {
        // Placeholder for the Phase 2 implementation.
    }
}
