# Build Roadmap & Shipping Path

---

## Phase 0 — Setup (your side, before I write code)

You have a Mac but no Xcode. Three things to do, roughly in this order:

**1. Install Xcode.** Mac App Store → Xcode. It is ~10 GB download, ~40 GB
installed, so check disk space first. Open it once after install to accept the
licence and let it install the iOS platform components.

Requirements check: Xcode 16 needs **macOS Sequoia 15.0 or later**. If your Mac is
on an older macOS or is an Intel model that can't run Sequoia, tell me — the plan
still works but the minimum-iOS and Swift-version choices shift.

Verify from Terminal:

```bash
xcodebuild -version && swift --version
```

**2. Apple Developer Program — $99/year.** Enrol at developer.apple.com/programs.
Enrolment can take 24–48 hours (sometimes longer if Apple asks for ID verification),
so start it early even though you won't need it until Phase 4. You can build and run
on your own device with a free Apple ID in the meantime; you cannot distribute, use
push-adjacent entitlements, or submit without the paid program.

Decide now whether you enrol as an **individual** (your legal name appears as the
seller on the App Store) or as an **organisation** (requires a D-U-N-S number, takes
longer, shows a company name). Individual is fine and much faster; changing later is
possible but annoying.

**3. Reserve the name.** Once enrolled, create the app record in App Store Connect
early — this reserves the name for 180 days. Do the trademark check first
(`00-OVERVIEW.md` header).

**Blocking decisions I need from you before Phase 1 code:**

| Decision | Options | My recommendation |
|---|---|---|
| App name | PawChart / Petfolio / Wellpaw / yours | Check availability, then tell me |
| Bundle ID | `com.<yourdomain>.pawchart` | Needs your domain or a reverse-DNS you control — permanent, cannot be changed after first submission |
| Toxicity warnings | ship / cut | Ship, with lawyer-reviewed wording (`00-OVERVIEW.md` §5) |
| Monetization | free / one-time Pro IAP / subscription | One-time Pro IAP (`00-OVERVIEW.md` §8) |
| Location feature | ship / cut from v1 | Cut — costs a permission prompt to save one address field |

---

## Phase 1 — Foundation

**Goal: it compiles, it stores data, and the schedule engine is provably correct.**

- Xcode project + local SPM packages per `01-ARCHITECTURE.md` §2
- `PetModel`: all `@Model` types, `SchemaV1`, `MigrationPlan` scaffold
- `ScheduleEngine`: all seven `DoseSchedule` patterns, `occurrences(...)`, clock
  protocol
- **`ScheduleEngineTests` — the real deliverable of this phase.** Fixed clocks across
  America/Chicago, Australia/Lord_Howe, Asia/Kolkata, Pacific/Kiritimati, UTC. Cases:
  DST spring-forward gap, DST fall-back repeat, Feb-29 and day-31 monthly clamping,
  taper stage boundaries, cyclic wrap, finite-course termination, interval anchoring
  after a late dose, `asNeeded` gap enforcement, and revision-boundary switching.
- `DesignSystem`: tokens, formatters, unit conversion, core components
- `AppEnvironment`, `DataActor`, in-memory container for previews and tests

Exit criterion: the schedule test suite is green and I can hand you a table of
generated occurrences for a prednisone taper that you can eyeball against a real
prescription.

## Phase 2 — Core loop

**Goal: a genuinely useful app for one pet, running on your device.**

- Onboarding, pet CRUD, pet detail hub
- Medication add/edit with the seven patterns and the **live next-doses preview**
- Today screen with one-tap logging, snooze, undo, sections
- `ReminderKit`: full pipeline, repeating + discrete triggers, grouping, priority
  culling, diffing, keep-alive, notification actions, permission flow
- Reminder Inspector (needed *during* development, not after)
- Weight tracking + chart
- Contacts + Emergency screen
- Settings: units, appearance, reminder defaults

Exit criterion: you run it on your own phone for a week with a real pet and real
medications, across at least one week boundary, and reminders fire correctly.

## Phase 3 — Depth

- Vaccinations, conditions, allergies, vet visits, lab results with trend charts
- `RecordsKit`: scan, import, OCR, extraction heuristics, review sheet, search
- Compliance & renewals
- Grooming profiles, tasks, appointments
- Feeding plans
- Identity & lost-pet kit
- Inventory & refill projection
- Caregivers & activity log

## Phase 4 — Output & polish

- `ReportKit`: all six PDF reports
- `ExportKit`: bundle export/import with the round-trip property test, CSV, weekly
  auto-backup
- Widgets + App Intents + Shortcuts
- StoreKit 2 paywall and entitlements
- Share extension
- **Accessibility pass**: VoiceOver on every screen, Dynamic Type to
  `.accessibility5`, contrast audit, hit-target audit
- Localisation catalogue complete (English only, but extraction done)
- App icon + 6 alternates, launch screen
- Empty states, error states, loading states

## Phase 5 — Submission

- App Store Connect record, screenshots (6.9" and 6.5" required), app preview video
  (optional, worth it)
- Privacy nutrition label: **Data Not Collected** across the board
- Privacy policy page (a static GitHub Pages site is fine and free)
- Support URL
- Description, keywords, subtitle, promotional text
- TestFlight beta — aim for 10+ external testers for at least two weeks, specifically
  covering multiple pets, a DST boundary if possible, and a device restart
- Review notes for Apple: explain that the app is a record-keeping and reminder tool,
  that all data is local, and provide a demo pet already populated so the reviewer
  doesn't have to set one up

## Phase 6 — Post-launch candidates

iCloud sync (the honest justification for a subscription), Apple Watch app,
family sharing via CloudKit shared zones, expense tracking and budgets, symptom
tracking with photo timelines, additional languages.

---

## App Store review: the things that actually get apps rejected

Ordered by how likely each is to bite this specific app.

1. **Guideline 5.1.1 — permission purpose strings.** Every usage string must state a
   concrete user benefit. "Camera access needed" is rejected; "PawChart uses the
   camera to scan vet records and take photos of your pets" is not.
2. **Guideline 2.1 — incomplete information.** Provide a demo account or, here, a
   pre-populated demo pet, and clear review notes. Reviewers who can't figure out
   the app reject it.
3. **Guideline 1.4.1 / medical claims.** Do not use "diagnose", "treat", "dose
   calculator", or "medical device" anywhere in the listing or UI. Ship the
   disclaimer in-app *and* mention it in review notes. Category **Lifestyle**, not
   Medical.
4. **Guideline 4.2 — minimum functionality.** Not a risk at this scope, but avoid
   submitting a stripped v1 in a rush.
5. **Guideline 5.1.2 — data use.** With no network code this is trivially satisfied,
   but the nutrition label must actually say "Data Not Collected". Getting the label
   wrong (over-declaring) is a surprisingly common self-inflicted rejection.
6. **Guideline 3.1.1 — IAP.** All digital unlocks go through StoreKit. No external
   payment links.
7. **Critical alert entitlement** — if requested and denied, ensure nothing in the
   build or listing depends on it. Ship with `.timeSensitive` and treat the
   entitlement as upside.

Realistic timeline: review is typically 24–48 hours now, but budget a week for a
first submission plus one rejection round.

---

## Testing strategy

| Layer | Tool | Coverage target |
|---|---|---|
| `ScheduleEngine` | Swift Testing, fixed clocks | Exhaustive — every pattern × every edge case |
| `ReminderKit` | Swift Testing + stub `UNUserNotificationCenter` | Budget allocation, culling order, diffing, grouping |
| `ExportKit` | Property test, randomised DB | Round-trip equality including attachment bytes |
| `RecordsKit` | Fixture scans in the test bundle | Extraction heuristics against ~20 real (redacted) vet documents |
| Repositories | In-memory `ModelContainer` | Cascade deletes, orphan reaping |
| UI | XCUITest | 5 flows only: onboarding, add med, log dose, scan record, generate report |
| Manual | Device matrix | DST boundary (change device date), time-zone travel, force-quit + notification, 64-slot saturation with 3 pets |

The manual matrix matters as much as the automated suite. Set your device clock to
30 October, put a med on a 02:30 schedule, and watch what happens — that is a test
no simulator run will do for you.

---

## Risk register

| Risk | Severity | Mitigation |
|---|---|---|
| Notification cap silently drops reminders | **Critical** | The entire design of `03-NOTIFICATIONS.md`; Inspector makes it visible |
| DST/time-zone bug misses doses | **Critical** | Pure engine, injected clocks, exhaustive tests, no `+86400` anywhere |
| SwiftData concurrency crashes | High | `ModelActor` discipline; never pass models across boundaries |
| Background refresh never granted | High | Never load-bearing; four other rebuild triggers plus keep-alive |
| OCR quality disappoints | Medium | Framed as suggestions, never auto-committed; document is useful without OCR |
| Critical-alert entitlement denied | Medium | Built but shipped disabled; `.timeSensitive` is the shipping path |
| Scope creep | Medium | Phase gates and the explicit out-of-scope list in `00-OVERVIEW.md` §6 |
| Name/trademark collision | Medium | Resolve in Phase 0, before anything is branded |
| Liability from toxicity warnings | Medium | Advisory wording only; legal review of exact strings before submission |

---

## What I need from you to start Phase 1

1. The five Phase-0 decisions in the table above
2. Confirmation Xcode is installed and `xcodebuild -version` returns something
3. Your macOS version, if it's older than Sequoia

Once those land, I'll write `PetModel` and `ScheduleEngine` with the full test suite
first — the engine is the part that has to be right, and it's also the part you can
verify without a running app.
