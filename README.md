# FloofSync — Pet Health & Medication Manager

Technical specification and build for a native iOS app.

**Stack:** Swift 6 / SwiftUI / SwiftData · iOS 17+ · local-only, no backend, no
network code, zero third-party dependencies.

**Status:** Phase 1 nearly complete. All eight spec documents are written.
Phase-0 decisions are resolved (see the table in `docs/07-BUILD-ROADMAP.md`):
the app is **FloofSync** (floofsync.com registered, bundle ID
`com.floofsync.app`), free with a one-time "FloofSync Pro" IAP, toxicity
warnings ship with advisory wording, and the location feature is cut from v1.

In `Packages/`: `ScheduleEngine` (pure dose-occurrence engine, 26-case test
suite green), `DesignSystem` (brand tokens + formatters, tested), and
`PetModel` (SwiftData models per the data-model spec — first compile happens
in Xcode). Brand guide in `design/BRAND.md`; the Today mockup in
`design/floofsync-today.html`. Remaining for Phase 1: the Xcode project
shell and `AppEnvironment`/`DataActor` wiring.

---

## Documents

| # | Document | What's in it |
|---|---|---|
| 00 | [Overview](docs/00-OVERVIEW.md) | Product definition, the "not a Notes app" test, users, safety and liability boundaries, feature inventory, monetization, success criteria |
| 01 | [Architecture](docs/01-ARCHITECTURE.md) | Stack choices and reasoning, module/package structure, SwiftData pitfalls, the schedule engine's purity constraint, background execution reality, privacy posture, accessibility requirements |
| 02 | [Data Model](docs/02-DATA-MODEL.md) | Every entity in Swift, the `DoseSchedule` algebra, immutable schedule revisions, the outcome ledger, inventory, time-zone policy, custom fields, settings |
| 03 | [Notifications](docs/03-NOTIFICATIONS.md) | The 64-notification cap and how the app survives it: repeating triggers, grouping, rolling horizon with priority culling, delivery-time verification, DST correctness, the inspector |
| 04 | [Screens](docs/04-SCREENS.md) | Navigation shell, Today, pet hub, the medication and taper flows, records, care, emergency, lost-pet kit, widgets and Shortcuts, onboarding |
| 05 | [Settings](docs/05-SETTINGS.md) | The full settings tree, custom fields, App Intents and URL scheme, schedule simulator, diagnostics, and a defaults reference |
| 06 | [Records, Reports, Export](docs/06-RECORDS-REPORTS-EXPORT.md) | On-device scan/OCR/extraction pipeline, six generated PDF reports, the `.floofsync` backup format and its round-trip guarantee |
| 07 | [Build Roadmap](docs/07-BUILD-ROADMAP.md) | Phase 0 setup steps, six build phases, App Store review pitfalls, testing strategy, risk register |

Suggested reading order: 00 → 07 (to see the shape and what I need from you) → 03
(the hardest problem) → 02 → 04.

---

## The three decisions that shaped everything

**1. Occurrences are computed, not stored.** Doses are a pure function of
(schedule, anchor, window). Only *outcomes* are persisted. Editing a schedule
therefore can't corrupt history, and the database doesn't accumulate thousands of
future rows. Schedule edits append an immutable revision rather than mutating in
place — see `docs/02-DATA-MODEL.md` §3.1.

**2. The 64-notification cap drives the reminder architecture.** iOS silently drops
pending local notifications past 64, app-wide. A two-pet household on twice-daily
meds exhausts that in five days. The answer is repeating triggers where the pattern
allows, grouping within a time window, and a rolling horizon with priority-ordered
culling that never drops a critical medication — plus a visible coverage indicator so
the limit fails loudly instead of silently. See `docs/03-NOTIFICATIONS.md`.

**3. Progressive disclosure is an architectural constraint.** You asked for something
usable by anyone *and* deep enough for a tinkerer. Every advanced capability is
additive, off by default, and below a disclosure. No feature requires an Advanced
setting to work correctly. That rule is what keeps the two audiences from ruining
each other's app.

---

## Decisions (resolved 2026-08-09)

Recorded in full in `docs/07-BUILD-ROADMAP.md`:

- **App name: FloofSync** — trademark + App Store availability check still due
  before the listing is filed
- **Bundle identifier: `com.floofsync.app`** (provisional — must be a reverse-DNS
  the owner controls before first submission)
- **Species toxicity warnings: ship**, advisory wording, legal review of strings
- **Monetization: free + one-time "FloofSync Pro" IAP** (~$14.99)
- **Location feature: cut from v1**

## Next steps

On the owner's side: install Xcode and start Apple Developer Program enrolment
(24–48h lead time), then reserve the FloofSync name in App Store Connect.
On the code side: Phase 1 is underway — `ScheduleEngine` and its test suite live
in `Packages/`, and the remaining spec documents (04–06) are being written.
