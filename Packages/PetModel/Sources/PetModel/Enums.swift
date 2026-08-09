import Foundation

// Pure value types — build on every platform. String raw values are the
// persisted representation; renaming a case is a schema migration.

public enum Species: String, Codable, Sendable, CaseIterable {
    case dog, cat, rabbit, ferret, bird, reptile, horse, other
}

public enum Sex: String, Codable, Sendable, CaseIterable {
    case male, maleNeutered, female, femaleSpayed, unknown
}

public enum WeightSource: String, Codable, Sendable {
    case home, vet
}

public enum MedForm: String, Codable, Sendable, CaseIterable {
    case tablet, capsule, liquid, injection, topical, chew, other
}

/// Drives notification culling order (03-NOTIFICATIONS.md §5).
public enum MedPriority: String, Codable, Sendable, CaseIterable {
    case critical, standard, flexible
}

public enum DoseOutcome: String, Codable, Sendable, CaseIterable {
    case given, partial, refused, skipped, missed
}

public enum ConditionStatus: String, Codable, Sendable, CaseIterable {
    case active, managed, resolved
}

public enum AllergySeverity: String, Codable, Sendable, CaseIterable {
    case mild, moderate, severe
}

public enum AllergyKind: String, Codable, Sendable, CaseIterable {
    case food, medication, environmental, other
}

public enum DocumentKind: String, Codable, Sendable, CaseIterable {
    case invoice, vaccineRecord, labResult, dischargeInstructions, prescription,
         insurance, registration, photo, other
}

public enum ContactKind: String, Codable, Sendable, CaseIterable {
    case primaryVet, emergencyVet, specialist, pharmacy, poisonControl,
         insurance, microchipRegistry, boarder, sitter, trainer, groomer, other
}

public enum ComplianceKind: String, Codable, Sendable, CaseIterable {
    case countyLicense, rabiesCert, microchipReg, insurance, boardingVaccines, other
}

public enum GroomingTask: String, Codable, Sendable, CaseIterable {
    case bath, nails, ears, glands, fullGroom, teeth
}

// Codable structs stored inside models.

public struct LabValue: Codable, Hashable, Sendable {
    public var name: String
    public var value: String
    public var unit: String
    public var refLow: String
    public var refHigh: String

    public init(name: String, value: String, unit: String = "",
                refLow: String = "", refHigh: String = "") {
        self.name = name
        self.value = value
        self.unit = unit
        self.refLow = refLow
        self.refHigh = refHigh
    }
}

public struct GroomingCadence: Codable, Hashable, Sendable {
    public var task: GroomingTask
    public var intervalDays: Int

    public init(task: GroomingTask, intervalDays: Int) {
        self.task = task
        self.intervalDays = intervalDays
    }
}

public struct FoodItem: Codable, Hashable, Sendable {
    public var name: String
    public var brand: String
    public var isPrescription: Bool
    public var portionText: String

    public init(name: String, brand: String = "", isPrescription: Bool = false,
                portionText: String = "") {
        self.name = name
        self.brand = brand
        self.isPrescription = isPrescription
        self.portionText = portionText
    }
}
