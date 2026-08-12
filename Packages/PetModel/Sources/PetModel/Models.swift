#if canImport(SwiftData)
import Foundation
import SwiftData
import ScheduleEngine

// Every rule from 02-DATA-MODEL.md §1 applies here: defaults or optionals on
// every property, no .unique attributes, optional relationships with declared
// inverses, attachments by relative path. CloudKit-readiness is why
// (01-ARCHITECTURE.md §7) — violating it here costs a migration later.

@Model
public final class Pet {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var name: String = ""
    public var species: Species = Species.dog
    public var breed: String = ""
    public var sex: Sex = Sex.unknown
    public var birthDate: DateOnly?
    public var adoptionDate: DateOnly?
    public var color: String = ""
    public var distinguishingMarks: String = ""
    public var microchipNumber: String = ""
    public var microchipRegistry: String = ""
    public var photoPath: String?
    public var idPhotoPaths: [String] = []
    public var isArchived: Bool = false
    public var sortOrder: Int = 0
    public var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \Medication.pet)
    public var medications: [Medication]? = []
    @Relationship(deleteRule: .cascade, inverse: \WeightEntry.pet)
    public var weights: [WeightEntry]? = []
    @Relationship(deleteRule: .cascade, inverse: \Vaccination.pet)
    public var vaccinations: [Vaccination]? = []
    @Relationship(deleteRule: .cascade, inverse: \Condition.pet)
    public var conditions: [Condition]? = []
    @Relationship(deleteRule: .cascade, inverse: \Allergy.pet)
    public var allergies: [Allergy]? = []
    @Relationship(deleteRule: .cascade, inverse: \VetVisit.pet)
    public var visits: [VetVisit]? = []
    @Relationship(deleteRule: .cascade, inverse: \LabResult.pet)
    public var labs: [LabResult]? = []
    @Relationship(deleteRule: .cascade, inverse: \PetDocument.pet)
    public var documents: [PetDocument]? = []
    @Relationship(deleteRule: .cascade, inverse: \ComplianceItem.pet)
    public var complianceItems: [ComplianceItem]? = []
    @Relationship(deleteRule: .cascade, inverse: \GroomingProfile.pet)
    public var groomingProfile: GroomingProfile?
    @Relationship(deleteRule: .cascade, inverse: \GroomingAppointment.pet)
    public var groomingAppointments: [GroomingAppointment]? = []
    @Relationship(deleteRule: .cascade, inverse: \FeedingPlan.pet)
    public var feedingPlan: FeedingPlan?
    public var contacts: [Contact]? = []

    public init() {}
}

@Model
public final class WeightEntry {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var pet: Pet?
    public var measuredAt: Date = Date.distantPast
    public var grams: Int = 0
    public var bodyConditionScore: Int?
    public var source: WeightSource = WeightSource.home
    public var notes: String = ""

    public init() {}
}

@Model
public final class Medication {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var pet: Pet?
    public var name: String = ""
    public var strength: String = ""
    public var form: MedForm = MedForm.tablet
    public var purpose: String = ""
    public var prescribedBy: Contact?
    public var pharmacy: Contact?
    public var isActive: Bool = true
    public var priority: MedPriority = MedPriority.critical
    public var timeZonePolicy: TimeZonePolicy = TimeZonePolicy.localWallClock
    public var weightAtDoseSet: Int?
    public var userWarnings: String = ""
    public var notes: String = ""

    @Relationship(deleteRule: .cascade, inverse: \ScheduleRevision.medication)
    public var revisions: [ScheduleRevision]? = []
    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medication)
    public var logs: [DoseLog]? = []
    @Relationship(deleteRule: .cascade, inverse: \InventoryState.medication)
    public var inventory: InventoryState?

    public init() {}
}

@Model
public final class ScheduleRevision {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var medication: Medication?
    public var effectiveFrom: Date = Date.distantPast
    /// Codable `DoseSchedule` (ScheduleEngine). Encoded, not relational, so the
    /// engine's types never leak into the schema. Append-only: revisions are
    /// never edited or deleted while their medication lives (02-DATA-MODEL §3.1).
    public var scheduleData: Data = Data()
    public var anchorDate: Date = Date.distantPast
    /// Codable `EndPolicy` (ScheduleEngine).
    public var endPolicyData: Data = Data()
    public var authorNote: String = ""

    public init() {}
}

@Model
public final class DoseLog {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var medication: Medication?
    /// Binds to the computed occurrence by (medication.id, scheduledAt).
    /// nil for PRN doses, which have no scheduled slot.
    public var scheduledAt: Date?
    public var outcome: DoseOutcome = DoseOutcome.given
    public var actualAt: Date = Date.distantPast
    public var amountValue: Double?
    public var amountUnit: String?
    public var caregiver: Caregiver?
    public var notes: String = ""

    public init() {}
}

@Model
public final class InventoryState {
    public var id: UUID = UUID()
    public var updatedAt: Date = Date.distantPast
    public var medication: Medication?
    public var unitsOnHand: Double = 0
    public var unitsPerRefill: Double = 0
    public var refillLeadDays: Int = 7
    public var lastRefillAt: Date?
    public var trackingEnabled: Bool = false

    public init() {}
}

@Model
public final class Vaccination {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var pet: Pet?
    public var name: String = ""
    public var administeredOn: DateOnly?
    public var expiresOn: DateOnly?
    public var administeredBy: Contact?
    public var lotNumber: String = ""
    public var attachmentPath: String?
    public var notes: String = ""

    public init() {}
}

@Model
public final class Condition {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var pet: Pet?
    public var name: String = ""
    public var diagnosedOn: DateOnly?
    public var status: ConditionStatus = ConditionStatus.active
    public var diagnosedBy: Contact?
    public var notes: String = ""

    public init() {}
}

@Model
public final class Allergy {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var pet: Pet?
    public var allergen: String = ""
    public var reaction: String = ""
    public var severity: AllergySeverity = AllergySeverity.mild
    public var kind: AllergyKind = AllergyKind.other
    public var notes: String = ""

    public init() {}
}

@Model
public final class VetVisit {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var pet: Pet?
    public var visitedAt: Date = Date.distantPast
    public var clinic: Contact?
    public var reason: String = ""
    public var diagnosis: String = ""
    public var followUpOn: DateOnly?
    public var costCents: Int?
    public var attachmentPaths: [String] = []
    public var notes: String = ""

    @Relationship(deleteRule: .nullify, inverse: \LabResult.visit)
    public var labResults: [LabResult]? = []

    public init() {}
}

@Model
public final class LabResult {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var pet: Pet?
    public var takenOn: DateOnly?
    public var panel: String = ""
    public var visit: VetVisit?
    public var values: [LabValue] = []
    public var attachmentPath: String?
    public var notes: String = ""

    public init() {}
}

@Model
public final class PetDocument {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var pet: Pet?
    public var title: String = ""
    public var kind: DocumentKind = DocumentKind.other
    public var documentDate: DateOnly?
    public var attachmentPath: String?
    public var ocrText: String = ""
    public var ocrConfidence: Double?
    public var tags: [String] = []
    public var sourceClinic: Contact?
    public var notes: String = ""

    public init() {}
}

@Model
public final class Contact {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var kind: ContactKind = ContactKind.other
    public var name: String = ""
    public var organization: String = ""
    public var phone: String = ""
    public var phoneAlt: String = ""
    public var email: String = ""
    public var address: String = ""
    public var portalURL: String = ""
    public var hoursText: String = ""
    public var isEmergencyCard: Bool = false
    public var notes: String = ""

    @Relationship(inverse: \Pet.contacts)
    public var pets: [Pet]? = []

    public init() {}
}

@Model
public final class GroomingProfile {
    public var id: UUID = UUID()
    public var updatedAt: Date = Date.distantPast
    public var pet: Pet?
    public var groomer: Contact?
    public var styleNotes: String = ""
    public var referencePhotoPaths: [String] = []
    public var bladeLengths: String = ""
    public var shampooNotes: String = ""
    public var behaviorNotes: String = ""
    public var cadences: [GroomingCadence] = []

    public init() {}
}

@Model
public final class GroomingAppointment {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var pet: Pet?
    public var scheduledAt: Date?
    public var completedAt: Date?
    public var tasks: [String] = []
    public var groomer: Contact?
    public var costCents: Int?
    public var notes: String = ""

    public init() {}
}

@Model
public final class ComplianceItem {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var pet: Pet?
    public var kind: ComplianceKind = ComplianceKind.other
    public var title: String = ""
    public var issuedOn: DateOnly?
    public var expiresOn: DateOnly?
    public var registryURL: String = ""
    public var policyNumber: String = ""
    public var attachmentPath: String?
    public var reminderLeadDays: [Int] = [30, 7]
    public var notes: String = ""

    public init() {}
}

@Model
public final class FeedingPlan {
    public var id: UUID = UUID()
    public var updatedAt: Date = Date.distantPast
    public var pet: Pet?
    public var foods: [FoodItem] = []
    public var mealTimes: [TimeOfDay] = []
    public var restrictions: String = ""
    public var treatRules: String = ""
    public var notes: String = ""

    public init() {}
}

@Model
public final class Caregiver {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var name: String = ""
    public var colorHex: String = ""
    public var isDefault: Bool = false

    @Relationship(deleteRule: .nullify, inverse: \DoseLog.caregiver)
    public var doseLogs: [DoseLog]? = []

    public init() {}
}

@Model
public final class CustomField {
    public var id: UUID = UUID()
    public var createdAt: Date = Date.distantPast
    public var updatedAt: Date = Date.distantPast
    public var entityKind: String = ""
    public var entityID: UUID?
    public var label: String = ""
    public var value: String = ""
    public var sortOrder: Int = 0

    public init() {}
}
#endif
