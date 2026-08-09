# Architecture

## 1. Stack

| Concern | Choice | Reasoning |
|---|---|---|
| Language | Swift 6, strict concurrency | Actor isolation catches the class of bug that plagues notification/background code. |
| Minimum OS | **iOS 17.0** | SwiftData requires 17. Gets ~95%+ of active devices by the time you ship. iOS 18 would buy little and cost reach. |
| UI | SwiftUI, no UIKit except where required | UIKit needed for: `VNDocumentCameraViewController` (scanning), `UIActivityViewController` (share sheet), `PHPickerViewController` (wrapped by SwiftUI's `PhotosPicker`, so actually fine). Wrap each in a `UIViewControllerRepresentable` in `PlatformKit`. |
| Persistence | **SwiftData** | Correct call for a greenfield iOS 17+ local app. Codegen-free models, `@Query` integrates cleanly, and it's a Core Data façade underneath so the CloudKit upgrade path exists. Caveats in §3. |
| Files/attachments | Filesystem in App Support, referenced by relative path | Never put scanned PDFs and photos in the database as `Data` blobs — it wrecks query performance and makes migration painful. |
| Notifications | `UNUserNotificationCenter` local only | No push, no server. |
| Background | `BGAppRefreshTask` | Notification horizon top-ups. Best-effort only — see §5. |
| OCR | Vision (`VNRecognizeTextRequest`) + PDFKit + VisionKit | All on-device. Zero network. |
| PDF generation | `ImageRenderer` → SwiftUI views → PDF context | Lets reports be authored as SwiftUI, not string-concatenated HTML. |
| Charts | Swift Charts | Weight trends, adherence bars. First-party, free. |
| Purchases | StoreKit 2 | `Transaction.currentEntitlements`, async/await. |
| Automation | App Intents | Powers Shortcuts, Siri, widgets, and Spotlight from one declaration. |
| Testing | Swift Testing (`@Test`) + XCTest for UI | Swift Testing for the engine; XCUITest for the few critical flows. |
| Dependencies | **Zero third-party** | Everything above is first-party. No SPM packages in v1. This is a deliberate constraint: no supply-chain risk, no App Store privacy-manifest headaches from vendored SDKs, no breakage on OS upgrades. |

## 2. Module structure

Swift Package Manager local packages inside the Xcode project, not one giant target.
The payoff is compile-time enforcement of layering and fast unit tests on the engine
without building the whole app.

```
PawChart/
├─ PawChart.xcodeproj
├─ App/                          # thin — app entry, root nav, DI wiring
│   ├─ PawChartApp.swift
│   ├─ RootView.swift
│   ├─ AppEnvironment.swift      # dependency container
│   └─ Resources/                # Assets.xcassets, Localizable.xcstrings, seed JSON
├─ Widgets/                      # widget extension target
├─ Packages/
│   ├─ PetModel/                 # SwiftData @Model types, enums, migration plan
│   ├─ ScheduleEngine/           # ← pure, no Foundation-date-guessing, no SwiftData
│   ├─ ReminderKit/              # UNUserNotificationCenter orchestration
│   ├─ RecordsKit/               # OCR, PDF import, document store, full-text index
│   ├─ ReportKit/                # PDF generation: vet report, sitter brief, poster, ID card
│   ├─ ExportKit/                # JSON+attachment bundle export/import, CSV
│   ├─ DesignSystem/             # tokens, components, formatters, accessibility helpers
│   └─ PlatformKit/              # UIKit bridges, Keychain, biometrics, share sheet
└─ Tests/
    ├─ ScheduleEngineTests/      # the big one
    ├─ ReminderKitTests/
    ├─ ExportKitTests/           # round-trip property tests
    └─ PawChartUITests/
```

**Dependency rule, enforced by package manifests:**

```
App  →  everything
ReportKit, ExportKit, ReminderKit, RecordsKit  →  PetModel, ScheduleEngine, DesignSystem
ScheduleEngine  →  (nothing — not even PetModel)
PetModel  →  (nothing)
DesignSystem  →  (nothing)
```

`ScheduleEngine` importing nothing is the single most important line in this document.
It means the dose logic is testable in milliseconds, has no database, no clock it
doesn't control, and no UI. See §4.

## 3. SwiftData: what to watch

SwiftData is the right choice but it has sharp edges. Design around them from day one
rather than discovering them at 5,000 records.

- **Pass `PersistentIdentifier`, never `@Model` instances, across concurrency
  boundaries.** Models are not `Sendable`. Background work takes IDs and re-fetches
  inside a `ModelActor`.
- **One `ModelActor` for all background writes** (`DataActor`). Notification
  rescheduling, import, and OCR indexing all run there. The main context is for UI
  only.
- **`@Query` is for lists you display.** Never for computation. Anything that needs
  to aggregate goes through a repository method on `DataActor` with an explicit
  `FetchDescriptor` and `fetchLimit`.
- **Relationship delete rules must be explicit.** Deleting a Pet cascades to its
  medications, logs, records, and attachment *files* — that last part SwiftData won't
  do for you. `DocumentStore.deleteOrphans()` runs on launch to reap files whose
  owning record is gone.
- **Migration plan from v1.** Define `SchemaV1` and a `MigrationPlan` enum before
  shipping, even with one version. Retrofitting versioned schemas after users have
  data is miserable.
- **Don't store `Date` for a wall-clock time-of-day.** Store `hour`/`minute` as
  `Int`. A `Date` for "8:00 AM" is a specific instant and will silently shift.

## 4. The schedule engine

The core abstraction. `ScheduleEngine` is a pure library over plain value types.

```swift
public protocol ScheduleEngineClock: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
    var timeZone: TimeZone { get }
}
```

Every function takes an explicit clock. There is **no** `Date()` call anywhere in the
package. Tests inject a fixed clock, a DST-transition clock, and a
crossing-the-date-line clock. This is what makes "does it survive DST?" a test rather
than a hope.

Primary entry point:

```swift
public func occurrences(
    of schedule: DoseSchedule,
    from start: Date,
    to end: Date,
    anchoredAt regimenStart: Date,
    lastCompleted: Date?,        // for interval/PRN modes
    using clock: some ScheduleEngineClock
) -> [DoseOccurrence]
```

`DoseOccurrence` is a value type: `(medicationID, scheduledAt, sequenceIndex,
plannedAmount, unit, stageLabel?)`.

### Materialize or compute?

**Compute occurrences lazily; persist only deviations.** Occurrences are a pure
function of (schedule, anchor, window), so there is no reason to write thousands of
future rows that a single schedule edit would invalidate.

The database stores `DoseLog` rows only when something *happened* — a dose was given,
skipped, refused, snoozed, or rescheduled. A log binds to its occurrence by a stable
composite key `(medicationID, scheduledAt)`, so the log survives even if the schedule
is later edited.

Consequences to handle explicitly:
- **"Missed" is derived, not stored.** An occurrence in the past with no log and past
  its grace window renders as missed. A nightly maintenance pass materializes missed
  doses older than 48h into `DoseLog(.missed)` so that adherence history stays
  correct after a schedule edit rewrites the past.
- **Editing a schedule must not rewrite history.** A `Medication` holds an ordered
  array of `ScheduleRevision` records, each with an `effectiveFrom` date. Occurrence
  generation picks the revision in force at that moment. This is how a prednisone
  taper that got adjusted mid-course still reports honestly.

## 5. Background execution reality

Do not build anything that *depends* on background execution. iOS grants
`BGAppRefreshTask` at its discretion; a user who force-quit the app may get none.

The notification horizon is therefore topped up at **four** points, in priority order:

1. Immediately after any schedule mutation (synchronously, before the sheet dismisses)
2. On `scenePhase == .active`
3. On `BGAppRefreshTask` (opportunistic bonus, never load-bearing)
4. On notification delivery, via a `UNNotificationServiceExtension`? — **No.** That
   only works for remote push. Instead: the *last* notification in the horizon is a
   special "keep-alive" reminder that tells the user to open the app if they haven't
   in a while. Ugly but honest; it only fires in the pathological case where a user
   hasn't opened the app in ~2 weeks and background refresh never ran.

Full design in `03-NOTIFICATIONS.md`.

## 6. Dependency injection

A plain struct environment, injected via SwiftUI's `@Environment`. No DI framework.

```swift
struct AppEnvironment {
    var data: DataActor
    var reminders: ReminderScheduler
    var documents: DocumentStore
    var entitlements: EntitlementsService
    var settings: SettingsStore
    var clock: any ScheduleEngineClock
}
```

Previews and tests construct an in-memory variant (`ModelContainer(isStoredInMemoryOnly: true)`,
a stub notification center, a fixed clock). Every SwiftUI preview in the codebase
must build against `AppEnvironment.preview` — enforced by convention, and it keeps
views from reaching for singletons.

## 7. Keeping the CloudKit door open

Sync is out of scope for v1, but a handful of cheap decisions now prevent a painful
rewrite later. CloudKit-backed SwiftData imposes constraints that are trivial to
satisfy up front and expensive to retrofit:

- Every property has a default value or is optional (CloudKit can't express non-optional-without-default)
- No `@Attribute(.unique)` constraints — enforce uniqueness in application code
- All relationships are optional and have inverses declared
- Attachments live as files referenced by path, ready to become `CKAsset`

Follow these in `PetModel` from day one. They cost nothing.

## 8. Privacy and security posture

- **No network code in the app at all.** Not "we don't send data" — there is no URL
  session. The only outbound actions are user-initiated: `tel:`, `maps:`, opening a
  vet portal in Safari, and the system share sheet. This makes the privacy nutrition
  label "Data Not Collected" trivially true and auditable.
- **App lock**: optional Face ID / passcode gate on launch and on return from
  background, via `LocalAuthentication`. Off by default.
- **File protection**: attachments written with `.completeUnlessOpen`. The SwiftData
  store inherits the default `.completeUntilFirstUserAuthentication`.
- **No analytics, no crash SDK.** Use Xcode Organizer's built-in crash reports, which
  are opt-in at the OS level and require no SDK. A third-party crash SDK would force
  a privacy manifest and change the nutrition label — not worth it.
- **Export bundles are unencrypted by default** but offer a passphrase option
  (CryptoKit `AES.GCM`, key derived via HKDF from the passphrase). Warn clearly that
  a forgotten passphrase means an unrecoverable backup.
- **Required `Info.plist` usage strings** — each must state the benefit, or review
  will reject:
  - `NSCameraUsageDescription` — scanning vet records and taking pet photos
  - `NSPhotoLibraryUsageDescription` — choosing existing pet photos and record images
  - `NSPhotoLibraryAddUsageDescription` — saving a generated lost-pet poster
  - `NSFaceIDUsageDescription` — unlocking the app
  - `NSContactsUsageDescription` — *optional feature*, importing a vet's contact card
  - `NSLocationWhenInUseUsageDescription` — *optional feature*, tagging last-seen
    location for a lost pet. **Recommend cutting location from v1**: it adds a
    permission prompt, a privacy-label entry, and a review question, to save the user
    typing an address once. Revisit in Phase 5.

## 9. Accessibility and localization

Treated as build requirements, not polish.

- Every interactive element has an accessibility label; icon-only buttons are the
  common failure and get a lint pass.
- Dynamic Type to `.accessibility5` on all primary screens. No fixed-height rows
  containing text. Test the Today view at the largest size — it's the densest screen
  and will break first.
- Colour is never the sole carrier of state. "Missed" is red **and** carries an icon
  **and** a text label.
- Minimum 44×44pt hit targets, including the dose quick-log buttons.
- All strings in a `Localizable.xcstrings` catalogue from the first commit, even
  though v1 ships English-only. Retrofitting string extraction is a week of tedium;
  doing it from the start is free.
- Dates, numbers, weights, and durations always through `DesignSystem.Formatters`,
  never string interpolation. Unit preference (kg/lb, °C/°F, 12/24h) is a user
  setting and must not leak raw values into the UI.
