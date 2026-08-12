# Data Model

Every persisted entity, the `DoseSchedule` algebra, and the rules that keep the
store CloudKit-ready. Entities live in the `PetModel` package as SwiftData
`@Model` classes; the schedule algebra lives in `ScheduleEngine` as plain value
types with **no** SwiftData dependency (see `01-ARCHITECTURE.md` §2 and §4).

## 1. Ground rules

Applied to every `@Model` in `PetModel`, per `01-ARCHITECTURE.md` §3 and §7:

- Every property is optional **or** has a default value. No `@Attribute(.unique)`.
  Uniqueness (e.g. one inventory row per medication) is enforced in `DataActor`.
- Every relationship is optional and declares an inverse. Delete rules are
  explicit: `Pet` cascades to everything it owns; attachment *files* are reaped
  by `DocumentStore.deleteOrphans()` on launch.
- Every entity carries `id: UUID` (app-generated, stable across export/import)
  and `createdAt`/`updatedAt` stamps set by `DataActor`, never by views.
- Wall-clock times of day are stored as `hour: Int` + `minute: Int`, never as
  `Date`. Calendar dates without a time (birthdays, expiry dates) are stored as
  `year/month/day` components (`DateOnly`), never as midnight `Date`s.
- Attachments are files in App Support referenced by relative path
  (`attachmentPath: String?`), never `Data` blobs in the store.
- Free-text `notes: String` exists on every user-facing entity. This is the
  pressure valve that keeps "just a note" from becoming a feature request.

## 2. Pet and body metrics

```swift
@Model final class Pet {
    var id: UUID = UUID()
    var name: String = ""
    var species: Species = Species.dog        // dog, cat, rabbit, ferret, bird, reptile, horse, other
    var breed: String = ""
    var sex: Sex = Sex.unknown                // male, maleNeutered, female, femaleSpayed, unknown
    var birthDate: DateOnly?                  // approximate OK; UI offers "age in years" entry
    var adoptionDate: DateOnly?
    var color: String = ""
    var distinguishingMarks: String = ""
    var microchipNumber: String = ""
    var microchipRegistry: String = ""        // registry name; URL lives in ComplianceItem
    var photoPath: String?                    // primary profile photo
    var idPhotoPaths: [String] = []           // multi-angle shots for the lost-pet kit
    var isArchived: Bool = false              // deceased/rehomed pets keep their history
    var sortOrder: Int = 0
    var notes: String = ""
    // inverse relationships: medications, weights, vaccinations, conditions,
    // allergies, visits, labs, documents, complianceItems, groomingProfile,
    // feedingPlan, contacts (many-to-many links) — all optional arrays, cascade delete
}

@Model final class WeightEntry {
    var id: UUID = UUID()
    var pet: Pet?
    var measuredAt: Date = Date.distantPast   // set by DataActor at insert
    var grams: Int = 0                        // canonical unit; UI converts kg/lb
    var bodyConditionScore: Int?              // 1–9 scale, optional
    var source: WeightSource = WeightSource.home   // home, vet
    var notes: String = ""
}
```

Weight is stored in **grams as `Int`** — no floating-point drift, no unit
ambiguity. `DesignSystem.Formatters` owns all conversion and display.

## 3. Medication and the schedule algebra

```swift
@Model final class Medication {
    var id: UUID = UUID()
    var pet: Pet?
    var name: String = ""
    var strength: String = ""                 // "75 mg tablet" — display text, never parsed
    var form: MedForm = MedForm.tablet        // tablet, capsule, liquid, injection, topical, chew, other
    var purpose: String = ""                  // "seizures", "heartworm prevention"
    var prescribedBy: Contact?
    var pharmacy: Contact?
    var isActive: Bool = true                 // discontinued meds keep history
    var priority: MedPriority = MedPriority.critical   // critical, standard, flexible — drives culling (03-NOTIFICATIONS.md §5)
    var timeZonePolicy: TimeZonePolicy = TimeZonePolicy.localWallClock
    var weightAtDoseSet: Int?                 // grams; drives the weight-drift advisory
    var userWarnings: String = ""             // owner's own free-text cautions
    var revisions: [ScheduleRevision]? = []   // ordered by effectiveFrom; §3.1
    var inventory: InventoryState?
    var logs: [DoseLog]? = []
    var notes: String = ""
}
```

### 3.1 Immutable schedule revisions

A medication's schedule is **never edited in place**. Every change appends a
`ScheduleRevision`; occurrence generation picks the revision in force at each
instant. This is why a mid-course taper adjustment still reports history
honestly, and why editing a schedule cannot corrupt the adherence ledger.

```swift
@Model final class ScheduleRevision {
    var id: UUID = UUID()
    var medication: Medication?
    var effectiveFrom: Date = Date.distantPast
    var scheduleData: Data = Data()           // Codable DoseSchedule (ScheduleEngine value type)
    var anchorDate: Date = Date.distantPast   // regimen anchor for cycles/tapers/intervals
    var endPolicyData: Data = Data()          // Codable EndPolicy
    var authorNote: String = ""               // "vet reduced dose at recheck"
}
```

The engine-facing decoded form is `ScheduleSpec` (a value type):
`(schedule: DoseSchedule, anchor: Date, endPolicy: EndPolicy, effectiveFrom: Date)`.

### 3.2 `DoseSchedule` — the seven patterns

Defined in `ScheduleEngine`, pure `Codable`/`Sendable`/`Equatable` value types.
Every pattern the product promises (`00-OVERVIEW.md` §7) maps to exactly one case:

```swift
public struct TimeOfDay: Codable, Hashable, Sendable, Comparable {
    public var hour: Int      // 0...23
    public var minute: Int    // 0...59
}

public struct DoseAmount: Codable, Hashable, Sendable {
    public var value: Double          // 1.5
    public var unit: String           // "tablet", "mL", "click" — display text
}

public enum DaySelection: Codable, Hashable, Sendable {
    case daily
    case weekdays(Set<Weekday>)       // Weekday: mon...sun, ISO numbering
}

public struct TaperStage: Codable, Hashable, Sendable {
    public var durationDays: Int?     // nil = final open-ended maintenance stage
    public var times: [TimeOfDay]
    public var amount: DoseAmount
    public var label: String          // "20 mg twice daily", shown on Today rows
}

public enum DoseSchedule: Codable, Hashable, Sendable {
    /// 1. Fixed clock times, daily or on selected weekdays. "8:00 and 20:00, Mon–Fri."
    case fixedTimes(times: [TimeOfDay], days: DaySelection, amount: DoseAmount)

    /// 2. Elapsed-time interval anchored to the *actual* previous dose. "Every 12 hours."
    ///    Drifts with reality: a dose given late pushes the next one later.
    case interval(hours: Double, amount: DoseAmount)

    /// 3. Calendar-day stride from the anchor. "Every 3 days at 9:00."
    case everyNDays(n: Int, times: [TimeOfDay], amount: DoseAmount)

    /// 4. Cyclic on/off blocks from the anchor. "5 days on, 2 days off."
    case cyclic(daysOn: Int, daysOff: Int, times: [TimeOfDay], amount: DoseAmount)

    /// 5. Ordered taper stages from the anchor; amounts and times per stage.
    case taper(stages: [TaperStage])

    /// 6. Monthly on a day-of-month, clamped to short months. "The 1st, at 9:00."
    case monthly(day: Int, time: TimeOfDay, amount: DoseAmount)   // day 1...31

    /// 7. PRN with an enforced minimum gap and optional daily cap.
    ///    Generates no scheduled occurrences — only an "available from" instant.
    case asNeeded(minimumGapHours: Double, maxPerDay: Int?, amount: DoseAmount)
}

public enum EndPolicy: Codable, Hashable, Sendable {
    case openEnded
    case afterTotalDoses(Int)         // "14 tablets then stop" — finite course
    case onDate(DateOnly)             // last day inclusive, in the medication's zone
}
```

Rules the engine enforces (tested exhaustively, `07-BUILD-ROADMAP.md`):

- **Occurrences are computed, never stored.** `occurrences(...)` is a pure
  function of `(spec, window, lastCompleted, clock)`.
- **`afterTotalDoses` counts from the revision's anchor**, including occurrences
  before the query window, so a window query deep into a course terminates
  correctly.
- **Monthly clamping**: `day: 31` in April fires on the 30th; `day: 29–31` in
  February fires on the 28th/29th. Never skips a month, never rolls over.
- **DST**: a scheduled 02:30 that doesn't exist on spring-forward day fires at
  the first existing instant after the gap; on fall-back days it fires at the
  *first* occurrence of the repeated wall time. No `+86400` day math anywhere.
- **`interval` chains from `lastCompleted ?? anchor`** in elapsed real time —
  deliberately not calendar time, because "every 12 hours" is a
  pharmacological statement, not a wall-clock one.
- **`asNeeded`** yields `nextAllowed = lastCompleted + minimumGap` (and blocks
  when the daily cap is reached), surfaced on Today as "available now / at 14:30".

### 3.3 Time-zone policy

```swift
public enum TimeZonePolicy: Codable, Sendable {
    case localWallClock   // "8 AM wherever the phone is" — default, right for most meds
    case fixedZone(identifier: String)  // "8 AM Chicago time" — for strict-interval regimens while travelling
}
```

Stored per medication, applied by `ReminderKit` when materializing occurrence
instants into notification triggers.

## 4. The outcome ledger — `DoseLog`

Only *events* are persisted. A log row binds to its computed occurrence by the
stable composite key `(medicationID, scheduledAt)`; it survives schedule edits.

```swift
@Model final class DoseLog {
    var id: UUID = UUID()
    var medication: Medication?
    var scheduledAt: Date?            // nil for PRN doses (no scheduled slot)
    var outcome: DoseOutcome = DoseOutcome.given
    var actualAt: Date = Date.distantPast     // when it really happened
    var amountValue: Double?          // actual amount if it differed (partial dose)
    var amountUnit: String?
    var caregiver: Caregiver?
    var notes: String = ""            // "spat out half, re-dosed with cheese"
}

enum DoseOutcome: Codable { case given, partial, refused, skipped, missed }
```

- **`missed` is derived, then materialized.** An occurrence past its grace
  window with no log *renders* as missed; a nightly maintenance pass writes
  `DoseLog(.missed)` for occurrences older than 48 h so adherence history is
  frozen against later schedule edits.
- `skipped` is a deliberate user action ("vet said pause it"); `refused` is an
  attempt that failed; `partial` records `amountValue` actually taken.
- The adherence report (06) is a fold over logs + computed occurrences per
  revision — no separate adherence table.

## 5. Inventory

```swift
@Model final class InventoryState {
    var id: UUID = UUID()
    var medication: Medication?
    var unitsOnHand: Double = 0       // decremented by each .given/.partial log
    var unitsPerRefill: Double = 0
    var refillLeadDays: Int = 7       // fire refill reminder this many days before run-out
    var lastRefillAt: Date?
    var trackingEnabled: Bool = false // off by default — zero-config rule
}
```

Run-out projection = pure function of `(unitsOnHand, live schedule occurrences)`,
computed by `ScheduleEngine.projectRunOut(...)`, displayed on the med detail and
used by `ReminderKit` for the refill reminder. Never stored.

## 6. Health record

```swift
@Model final class Vaccination {
    var id: UUID = UUID(); var pet: Pet?
    var name: String = ""                     // "Rabies", "DHPP"
    var administeredOn: DateOnly?
    var expiresOn: DateOnly?                  // drives lead-time reminders
    var administeredBy: Contact?
    var lotNumber: String = ""
    var attachmentPath: String?               // certificate scan
    var notes: String = ""
}

@Model final class Condition {
    var id: UUID = UUID(); var pet: Pet?
    var name: String = ""; var diagnosedOn: DateOnly?
    var status: ConditionStatus = ConditionStatus.active   // active, managed, resolved
    var diagnosedBy: Contact?; var notes: String = ""
}

@Model final class Allergy {
    var id: UUID = UUID(); var pet: Pet?
    var allergen: String = ""; var reaction: String = ""
    var severity: AllergySeverity = AllergySeverity.mild   // mild, moderate, severe
    var kind: AllergyKind = AllergyKind.other              // food, medication, environmental, other
    var notes: String = ""
}

@Model final class VetVisit {
    var id: UUID = UUID(); var pet: Pet?
    var visitedAt: Date = Date.distantPast
    var clinic: Contact?; var reason: String = ""
    var diagnosis: String = ""; var followUpOn: DateOnly?
    var costCents: Int?; var attachmentPaths: [String] = []
    var notes: String = ""
}

@Model final class LabResult {
    var id: UUID = UUID(); var pet: Pet?
    var takenOn: DateOnly?; var panel: String = ""         // "CBC", "Chem 17", "T4"
    var visit: VetVisit?
    var values: [LabValue] = []                            // Codable struct: name, value, unit, refLow, refHigh
    var attachmentPath: String?; var notes: String = ""
}

@Model final class PetDocument {                           // the vault (06-RECORDS-REPORTS-EXPORT.md)
    var id: UUID = UUID(); var pet: Pet?
    var title: String = ""; var kind: DocumentKind = DocumentKind.other
    var documentDate: DateOnly?
    var attachmentPath: String?                            // PDF or image
    var ocrText: String = ""                               // full recognized text, searchable
    var ocrConfidence: Double?                             // 0–1; below threshold → no auto-suggestions
    var tags: [String] = []
    var sourceClinic: Contact?; var notes: String = ""
}
```

`ocrText` feeds a simple in-store full-text search (`contains`, tokenized) in
v1 — no separate index. Revisit only if search is slow at realistic volumes
(hundreds of documents, not thousands).

## 7. Contacts

```swift
@Model final class Contact {
    var id: UUID = UUID()
    var kind: ContactKind = ContactKind.other  // primaryVet, emergencyVet, specialist, pharmacy,
                                               // poisonControl, insurance, microchipRegistry,
                                               // boarder, sitter, trainer, groomer, other
    var name: String = ""; var organization: String = ""
    var phone: String = ""; var phoneAlt: String = ""
    var email: String = ""; var address: String = ""
    var portalURL: String = ""; var hoursText: String = ""
    var pets: [Pet]? = []                      // many-to-many; empty = household-wide
    var isEmergencyCard: Bool = false          // pinned on the Emergency screen
    var notes: String = ""
}
```

The Emergency screen (two taps from anywhere, `04-SCREENS.md`) shows: contacts
with `isEmergencyCard`, each pet's critical meds and allergies, microchip
numbers, and poison-control numbers seeded at first launch from bundled JSON.

## 8. Grooming

```swift
@Model final class GroomingProfile {
    var id: UUID = UUID(); var pet: Pet?
    var groomer: Contact?
    var styleNotes: String = ""; var referencePhotoPaths: [String] = []
    var bladeLengths: String = ""; var shampooNotes: String = ""
    var behaviorNotes: String = ""
    var cadences: [GroomingCadence] = []       // Codable: task (bath, nails, ears, glands, fullGroom), intervalDays
}

@Model final class GroomingAppointment {
    var id: UUID = UUID(); var pet: Pet?
    var scheduledAt: Date?; var completedAt: Date?
    var tasks: [String] = []; var groomer: Contact?
    var costCents: Int?; var notes: String = ""
}
```

"Next due" is projected from **last completed + interval**, never from a fixed
calendar — a bath done late doesn't stack the next one early.

## 9. Compliance and renewals

```swift
@Model final class ComplianceItem {
    var id: UUID = UUID(); var pet: Pet?
    var kind: ComplianceKind = ComplianceKind.other  // countyLicense, rabiesCert, microchipReg,
                                                     // insurance, boardingVaccines, other
    var title: String = ""
    var issuedOn: DateOnly?; var expiresOn: DateOnly?
    var registryURL: String = ""; var policyNumber: String = ""
    var attachmentPath: String?
    var reminderLeadDays: [Int] = [30, 7]            // one reminder per lead value
    var notes: String = ""
}
```

## 10. Feeding

```swift
@Model final class FeedingPlan {
    var id: UUID = UUID(); var pet: Pet?
    var foods: [FoodItem] = []            // Codable: name, brand, isPrescription, portionText
    var mealTimes: [TimeOfDay] = []
    var restrictions: String = ""         // "no chicken", "grain-free per vet"
    var treatRules: String = ""
    var notes: String = ""
}
```

Feeding reminders are optional and off by default; when on, they ride the same
`ReminderKit` pipeline as meds at `MedPriority.flexible`.

## 11. Household

```swift
@Model final class Caregiver {
    var id: UUID = UUID()
    var name: String = ""                 // local label only — no account, no auth
    var colorHex: String = ""
    var isDefault: Bool = false           // preselected in the log sheet
}
```

Who-did-what is the `caregiver` reference on `DoseLog` plus timestamps that
already exist on every entity — there is no separate activity-log table in v1.

## 12. Custom fields (power layer)

```swift
@Model final class CustomField {
    var id: UUID = UUID()
    var entityKind: String = ""           // "Pet", "Medication", ...
    var entityID: UUID?
    var label: String = ""
    var value: String = ""                // free text; typed fields are post-v1
    var sortOrder: Int = 0
}
```

Deliberately stringly-typed and dumb. Custom fields render in a "More" section
on the owning entity's detail screen and export with everything else. They are
invisible until the user creates one (progressive disclosure).

## 13. Settings

Not SwiftData — a `Codable` struct in `UserDefaults` via `SettingsStore`
(`05-SETTINGS.md` has the full tree):

```swift
struct AppSettings: Codable {
    var weightUnit: WeightUnit = .auto        // auto = follow locale
    var temperatureUnit: TemperatureUnit = .auto
    var clockStyle: ClockStyle = .auto
    var appearance: Appearance = .system
    var defaultGraceMinutes: Int = 60         // missed-dose grace window
    var defaultSnoozeMinutes: Int = 10
    var appLockEnabled: Bool = false
    var toxicityWarningsEnabled: Bool = true
    var weeklyAutoBackup: Bool = false
    // per-medication overrides live on the entities, not here
}
```

Purchase state is **never** persisted here or in SwiftData — it is read live
from StoreKit 2 `Transaction.currentEntitlements` (see `00-OVERVIEW.md` §8).

## 14. Seed data

Bundled JSON in `App/Resources`, loaded once on first launch:

- Poison-control contacts (ASPCA APCC, Pet Poison Helpline) as `Contact` rows
- The species toxicity list (name-matched warning strings per species) — static,
  versioned with the app, never fetched
- The demo pet used for App Store review builds (compile-flag gated)

## 15. Schema versioning

`SchemaV1` enumerates every `@Model` above inside a `VersionedSchema`;
`FloofSyncMigrationPlan` starts with the single stage. Defined before the first
TestFlight build ships, per `01-ARCHITECTURE.md` §3.
