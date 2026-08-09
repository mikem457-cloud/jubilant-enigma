#if canImport(SwiftData)
import Foundation
import SwiftData

/// Versioned from day one so the v2 migration is a new enum case, not a
/// retrofit (01-ARCHITECTURE.md §3).
public enum SchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Pet.self, WeightEntry.self,
            Medication.self, ScheduleRevision.self, DoseLog.self, InventoryState.self,
            Vaccination.self, Condition.self, Allergy.self, VetVisit.self,
            LabResult.self, PetDocument.self,
            Contact.self,
            GroomingProfile.self, GroomingAppointment.self,
            ComplianceItem.self, FeedingPlan.self,
            Caregiver.self, CustomField.self,
        ]
    }
}

public enum FloofSyncMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    public static var stages: [MigrationStage] {
        []   // v1 → v2 gets the first stage
    }
}
#endif
