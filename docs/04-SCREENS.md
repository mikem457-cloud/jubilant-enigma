# Screens

Every screen, its job, and the rules that keep the primary user's app simple
while the tinkerer's depth stays one disclosure away. The design mockup for
Today is `design/floofsync-today.html`; visual tokens are defined in
`design/BRAND.md` and implemented in the `DesignSystem` package.

## 1. Navigation shell

Four tabs plus one always-reachable panic path:

```
┌─────────────────────────────────────────────┐
│                 (content)                   │
├──────────┬──────────┬──────────┬────────────┤
│  Today   │   Pets   │ Records  │    More    │
└──────────┴──────────┴──────────┴────────────┘
```

- **Today** — the app (§2). Launch always lands here.
- **Pets** — pet list → per-pet hub (§4).
- **Records** — the document vault and search, household-wide (§6).
- **More** — contacts, emergency, care screens, settings (§7–8).
- **Emergency** is reachable in ≤2 taps from anywhere: More → Emergency, plus a
  red cross button pinned in the Pets and pet-hub toolbars. No gesture-only
  access — it must be findable by a stressed stranger holding your phone.

Deep data always lives *behind* Today, never in front of it
(`00-OVERVIEW.md` §4).

## 2. Today

The whole product in one screen. Sections, in fixed order, each collapsing to
nothing when empty:

1. **Overdue** — doses past their grace window, red accent, oldest first.
2. **Due now** — inside the grace window, marigold accent.
3. **Available (PRN)** — as-needed meds whose gap has elapsed: "available now",
   or "available at 14:30" when still blocked.
4. **Later today** — upcoming, dimmed.
5. **Done** — collapsed by default; logged doses with time + caregiver chip.
6. **Care today** — non-med items due today (feeding when enabled, grooming
   due, compliance renewals inside their lead window).

Row anatomy: pet color dot · pet name · med name + amount (+ taper stage label
when present) · scheduled time · one-tap **✓ log** button (44×44pt minimum).

Interactions:
- **Tap ✓** logs `given` at `now` with the default caregiver. An **Undo**
  snackbar shows for 6 s. No sheet, no confirmation — this is the 90-second
  test's critical path.
- **Long-press / swipe** opens the full log sheet: outcome (given / partial /
  refused / skipped), actual time, amount, caregiver, note.
- **Tap row** → medication detail.
- Multi-pet households get a horizontal pet filter chip row at top; single-pet
  households never see it (progressive disclosure).
- Header shows date + a compact coverage warning **only** when reminder
  coverage < 7 days (`03-NOTIFICATIONS.md` §8).

Empty state: "Nothing due. [Pet]'s next dose is tomorrow 8:00 AM." — always
names the *next* thing, never a blank screen.

## 3. Onboarding

Three screens, no account, no permission prompts:

1. Welcome — one line of what the app does; the vet-advice disclaimer
   (`00-OVERVIEW.md` §5) with a single **Continue**.
2. Add your pet — name, species, photo (optional). One screen.
3. Land on Today, empty state prompting "Add a medication".

Notification permission is requested at first medication save, not here
(`03-NOTIFICATIONS.md` §9). Total time to first scheduled med for a new user
must be under 90 seconds (`00-OVERVIEW.md` §9).

## 4. Pet hub

Per-pet home: header (photo, name, age, weight sparkline) then card links:
Medications · Health (weight, vaccinations, conditions, allergies, visits,
labs) · Documents · Feeding · Grooming · Identity & lost pet · Compliance.
Cards show a one-line live summary ("2 active meds · next 8:00 PM") and hide
entirely when the module is empty and never used — a new user sees three cards,
not eleven.

Archived pets (deceased/rehomed) move to a collapsed "Past pets" section in the
Pets list; their history stays intact and exportable.

## 5. Medication flows

### 5.1 Add/edit medication

One scrolling form, basics first:

- Name (with species toxicity check on commit — non-blocking advisory banner
  worded per `00-OVERVIEW.md` §5), strength, form, purpose.
- **Schedule pattern picker** — seven cards with plain-language names:
  "Fixed times" / "Every N hours" / "Every N days" / "Days on, days off" /
  "Taper" / "Monthly" / "As needed". Each expands to its minimal fields.
- **Live preview**: the next 5 occurrences render beneath the pattern fields on
  every edit, straight from `ScheduleEngine` — the user sees exactly what the
  engine will do before saving. This is the single best defense against
  schedule-entry mistakes.
- End: ongoing / stop after N doses / stop on date.
- Advanced (disclosure, all optional): priority, per-med snooze/escalation,
  time-zone policy, inventory tracking, prescriber/pharmacy links, user
  warnings, weight-at-dose-set.

### 5.2 Taper builder

Stage list editor: each stage = duration (days or "ongoing" for the last),
times per day, amount, auto-generated label ("20 mg twice daily", editable).
Add/reorder/delete stages; the live preview shows the stage boundaries. A
mid-course edit appends a `ScheduleRevision` effective today — the UI says so:
"Changes apply from today; history is kept."

### 5.3 Medication detail

Header (name, pet, stage label if tapering) · next doses · adherence strip
(last 14 days as colored ticks) · inventory card (when enabled) with projected
run-out · schedule history (revision list, read-only) · log history · actions:
edit schedule, log PRN dose, pause (skip until date), discontinue (keeps
history), delete (destructive, double-confirm, explains cascade).

## 6. Records (vault)

- Grid/list of documents across pets, filterable by pet, kind, tag; search box
  hits title, tags, and OCR text.
- **Scan flow**: + → camera (VisionKit document scanner) or photo/file import →
  on-device OCR → **review sheet** with suggested title, date, kind, pet, and
  clinic — every suggestion editable, nothing auto-committed
  (`06-RECORDS-REPORTS-EXPORT.md` §2). Save files it to the pet.
- Document detail: full-screen viewer, metadata, OCR text (copyable), share.

## 7. Care screens (More tab)

- **Contacts** — typed list (`02-DATA-MODEL.md` §7); tap-to-call, tap-to-map,
  portal link. Import from the system contacts app is an optional per-contact
  action (triggers the contacts permission prompt only then).
- **Emergency** — red-accented screen: emergency-card contacts with giant call
  buttons, per-pet critical meds + allergies + microchip numbers, poison
  control. Works fully offline; renders in <1 s.
- **Feeding** — per-pet plan editor; reminder toggle off by default.
- **Grooming** — profile (style notes, reference photos, blade lengths,
  cadences), appointment log, "next due" projections, shareable groomer brief.
- **Compliance** — per-pet renewal list sorted by urgency, each with expiry
  countdown, document link, registry URL.
- **Identity & lost pet** — ID photos, marks, microchip; **Lost Pet Kit**
  button → generates poster + ID card (`06-RECORDS-REPORTS-EXPORT.md` §3) and
  shows the first-hour checklist.

## 8. Settings

Full tree in `05-SETTINGS.md`. The More tab shows: Settings, plus (Pro) badge
row for the paywall when not yet purchased.

## 9. Widgets, Live Activity, Shortcuts

- **Home/Lock Screen widgets**: Next Dose (small), Today Summary (medium),
  per-pet variant. Deep-link into Today.
- **Live Activity**: an open dose window (due → grace end) for `critical` meds;
  one tap logs from the Lock Screen. Ships only if it proves reliable in
  Phase 4 testing — it's an enhancement, not load-bearing.
- **App Intents**: "Log [med] for [pet]", "When is [pet]'s next dose?", "Add a
  weight for [pet]" — exposed to Shortcuts, Siri, and Spotlight
  (`05-SETTINGS.md` §3).

## 10. States nobody plans for

Every screen ships with explicit empty, error, and loading states
(`07-BUILD-ROADMAP.md` Phase 4). Rules:

- Empty states name the next action, in the interface's voice, no mascots.
- Errors say what happened and what to do; never "Something went wrong."
- Nothing blocks on OCR, PDF render, or export — all run with progress and are
  cancellable.
- Dynamic Type to `.accessibility5` on Today, log sheet, med form, Emergency —
  the four screens that matter most — verified in previews as part of review,
  not as a Phase-4 afterthought.
