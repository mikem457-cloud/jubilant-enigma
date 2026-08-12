# Settings & the Power Layer

Everything behind the More tab's Settings row, plus the tinkerer features that
must never intimidate the primary user. Rule of the house: **every Advanced
item is additive, optional, and off by default** (`00-OVERVIEW.md` §3).

## 1. Settings tree

```
Settings
├─ Reminders
│   ├─ Default grace window        (60 min)
│   ├─ Default snooze              (10 min)
│   ├─ Coverage                    ("Scheduled through Fri Jun 12" — live, 03-NOTIFICATIONS §8)
│   └─ Notification permission     (status + link to system Settings when denied)
├─ Units & Format
│   ├─ Weight                      (auto / kg / lb)
│   ├─ Temperature                 (auto / °C / °F)
│   └─ Time                        (auto / 12h / 24h)
├─ Appearance                      (system / light / dark)
├─ Household
│   ├─ Caregivers                  (add/edit local labels, pick default)
│   └─ Pets                        (reorder, archive)
├─ Privacy & Security
│   ├─ App lock                    (Face ID / passcode, off by default)
│   └─ Privacy explainer           ("Your data never leaves this device…")
├─ Backup & Export
│   ├─ Export everything           (.floofsync bundle, 06-RECORDS §4)
│   ├─ Import backup
│   ├─ Weekly auto-backup          (off; saves to Files when on)
│   └─ CSV export                  (dose log / weights per pet)
├─ FloofSync Pro                   (paywall / "Purchased ✓" + Restore)
├─ Advanced                        (single disclosure hiding everything below)
│   ├─ Custom fields               (per entity kind; 02-DATA-MODEL §12)
│   ├─ Per-medication defaults     (escalation, time-zone policy)
│   ├─ Schedule simulator          (§4)
│   ├─ Reminder Inspector          (03-NOTIFICATIONS §8)
│   ├─ Shortcuts & URL scheme      (§3 — reference list)
│   ├─ Toxicity warnings           (on by default; can disable)
│   └─ Diagnostics                 (§5)
└─ About
    ├─ Version, licenses
    ├─ Disclaimer                  (persistent, 00-OVERVIEW §5)
    └─ Support                     (floofsync.com/support)
```

Defaults live in one place — `AppSettings` (`02-DATA-MODEL.md` §13) — and every
default above is also the reset value of "Reset to defaults" in Diagnostics.

## 2. Paywall placement

Free tier: one pet, unlimited medications, all reminders. Pro
(one-time, ~$14.99): additional pets, document vault + OCR, generated reports,
widgets, Shortcuts, custom fields, CSV export.

Gates render as a small "Pro" tag on the locked row/button; tapping shows one
paywall sheet (StoreKit 2). Never interrupt a flow the free tier owns; never
gate data the user already created (a lapsed… n/a — non-consumable, no lapsing).
All gate checks go through `EntitlementsService.isPro` — a single choke point,
per `00-OVERVIEW.md` §8.

## 3. App Intents & URL scheme

**App Intents** (Pro; powers Siri, Shortcuts, Spotlight, widgets):

| Intent | Parameters | Result |
|---|---|---|
| Log Dose | pet, medication, outcome (default given) | logs at now |
| Next Dose | pet? | speaks/returns next occurrence |
| Add Weight | pet, value | appends weight entry |
| Pet Status | pet | summary: due today, overdue count |

**URL scheme** `floofsync://` (Advanced reference list, tappable to test):
`today`, `pet/<uuid>`, `emergency`, `log/<medication-uuid>` (opens log sheet),
`scan`. Used by widgets internally; documented for tinkerers.

## 4. Schedule simulator

The tinkerer's window into `ScheduleEngine`, and the developer's manual QA
tool shipped in the product: pick any medication (or build a throwaway
schedule), a date range, and a time zone, and see the generated occurrence
table — exactly `ScheduleEngine.occurrences(...)` output, including taper
stage labels and finite-course termination. A "what if I travel?" zone picker
demonstrates the `TimeZonePolicy` difference side by side.

Zero risk: the simulator only reads; it can't mutate schedules.

## 5. Diagnostics

- Reminder Inspector (pending requests + budget arithmetic, 03-NOTIFICATIONS §8)
- Data statistics: entity counts, attachment storage size, orphan-file count
  with "clean up now" (`DocumentStore.deleteOrphans`)
- Last background-refresh time and result
- Export diagnostics text (counts + settings, **no pet data**) for support email
- Reset to defaults (settings only — never touches data)

## 6. Defaults reference

| Setting | Default | Range |
|---|---|---|
| Grace window | 60 min | 15–240 min |
| Snooze | 10 min | 5–60 min |
| Escalation | off | off / one follow-up at +30 min |
| Refill lead | 7 days | 1–30 days |
| Compliance lead | 30 & 7 days | any set of 1–90 |
| Weekly auto-backup | off | on/off |
| App lock | off | on/off |
| Toxicity warnings | on | on/off (Advanced) |
| Widget refresh | system-managed | — |
