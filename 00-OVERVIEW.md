# PawChart — Product Overview

> **Working name.** `PawChart` is a placeholder. Before you file for an App Store
> listing, run a USPTO TESS search and an App Store name search. Alternates that
> read well and are unlikely to collide: **Petfolio**, **Wellpaw**, **Chartpaw**.
> Name is a Phase-0 blocking decision (see `07-BUILD-ROADMAP.md`).

---

## 1. What this is

A local-first iOS app that acts as the **medical and administrative system of record
for a household's pets**. Medication scheduling is the anchor feature; around it sits
everything a pet owner has to remember, prove, or hand to someone else.

Platform: iOS 17+, native Swift 6 / SwiftUI, SwiftData persistence, no backend.

## 2. The "not a Notes app" test

Every feature in this spec has to pass one question: *could you do this with Notes,
Reminders, or Calendar?* If yes, it doesn't earn its place. The features that pass:

| Capability | Why Calendar/Notes can't do it |
|---|---|
| **Dose schedule engine** | Tapers, cyclic on/off courses, "every 12h" drifting intervals, PRN with enforced minimum gaps, and finite courses ("14 tablets then stop") are not expressible as calendar recurrence rules. |
| **Adherence ledger** | Records *scheduled vs. actual* time, partial doses, refusals ("spat it out"), and who administered. Produces a vet-ready adherence report. Calendar records intent, not outcome. |
| **Inventory projection** | Decrements stock on each logged dose, projects the run-out date from the live schedule, and fires a refill reminder with lead time. Requires coupling schedule + log + stock. |
| **Weight-linked dosing** | Flags a medication for recalculation when the pet's weight moves past a threshold since the dose was set. Requires the med and the weight history to know about each other. |
| **Rolling notification scheduler** | iOS caps an app at 64 pending local notifications. Three pets on multiple meds blows through that in days. Needs a horizon-maintaining scheduler (see `03-NOTIFICATIONS.md`). |
| **OCR'd record vault** | Scan a paper vet invoice, OCR it on-device, auto-suggest date/clinic/med names, file it against the right pet, and surface it later by full-text search. |
| **Expiry-driven compliance** | Rabies certificate, county license, microchip registry, insurance, boarding vaccine requirements — each with its own renewal cadence, document, and lead-time reminders. |
| **Lost-pet kit** | Generates a printable/shareable poster and an ID card from data already in the app, at the moment you're least able to assemble it. |
| **Sitter handoff** | One-tap export of a complete care brief — meds, timing, feeding, quirks, emergency numbers — as a PDF a sitter can follow without the app. |

Anything that fails the test (generic to-dos, free-form notes) exists only as a
*field on a real object*, never as a standalone feature.

## 3. Users

**Primary — "the responsible owner."** One to three pets. Wants the app to be
correct and quiet. Opens it to log a dose and to find the vet's number. Success =
never misses a dose, never gets surprised by an expired rabies cert. This user must
be able to add a pet and a twice-daily medication in under 90 seconds, with zero
configuration.

**Secondary — "the complex case."** Senior or chronically ill animal. Multiple meds,
a prednisone taper, monthly labs, a specialist and a primary vet, insurance claims.
Needs the adherence report and the record vault. This user is why the schedule engine
has to be genuinely expressive.

**Tertiary — "the tinkerer."** Wants custom fields, Shortcuts automation, widgets,
full JSON export, a schedule simulator, and per-medication notification behavior.
Everything for this user lives behind an **Advanced** disclosure and ships **off by
default**. The tinkerer's features must never be visible enough to intimidate the
primary user.

The design rule that follows: **progressive disclosure is a hard architectural
constraint, not a styling preference.** Every advanced field is additive and
optional; the app must be fully usable if the user never opens a single Advanced
section.

## 4. Product principles

1. **Local-first, no account.** Data never leaves the device unless the user
   explicitly exports it. This is a feature, a marketing line, and a
   "Data Not Collected" privacy nutrition label.
2. **The app is not a veterinarian.** It records and reminds. It does not dose,
   diagnose, or advise. See §5.
3. **Correctness over cleverness in scheduling.** The dose engine is a pure,
   deterministic, heavily unit-tested function. If it's wrong, an animal misses
   medication. It gets the most test coverage in the codebase.
4. **Every screen answers "what do I do now?"** The Today view is the app. Deep
   data lives behind it, not in front of it.
5. **Degrade gracefully to paper.** Anything critical (sitter brief, lost poster,
   vet report, ID card) must render to a PDF that works with a dead phone battery.

## 5. Safety, liability, and scope boundaries

This is a health-adjacent app for animals. It is **not** a regulated medical device
(FDA device regulation applies to human medical devices; veterinary software is far
less regulated), but the liability posture still matters and shapes the design.

**Hard rules baked into the product:**

- The app **never computes a dose**. The user enters what the vet prescribed. There
  is no mg/kg calculator that outputs a recommendation.
- The weight-change feature says *"Bella's weight has changed 18% since this dose was
  set — you may want to confirm it with your vet."* It does not suggest a new dose.
- First-run disclaimer, plus a persistent line in Settings → About: *"PawChart is a
  record-keeping and reminder tool. It is not veterinary advice. Always follow your
  veterinarian's instructions."*
- **Species toxicity warnings** — a bundled static list of well-established
  contraindications (acetaminophen and any pet, ibuprofen and any pet, permethrin
  and cats, xylitol, etc.). When a user types a matching medication name for that
  species, show a non-blocking warning with a "confirm with your vet" action.
  This is factual, widely published, and defensible.
  **→ Decision needed:** ship this or cut it. It is genuinely useful and genuinely
  a liability surface. My recommendation: ship it, worded as *"This is commonly
  reported as unsafe for cats. Confirm with your vet before giving it,"* never as
  *"do not give."* Have a lawyer read the exact strings before submission.
- **No drug-interaction engine.** Licensing a veterinary interaction database is
  expensive and hand-rolling one is irresponsible. Out of scope permanently.
  Users can attach their own free-text warnings to a medication.

**App Store framing:** primary category **Lifestyle**, not Medical. Medical draws
heavier review scrutiny and invites the reviewer to evaluate clinical claims. The
listing copy describes tracking and reminding, never treatment.

## 6. What is explicitly out of scope for v1

Listed so scope creep has to argue its way back in:

- Cloud sync, accounts, family sharing (deferred — see `01-ARCHITECTURE.md` §7 for
  how the data layer stays CloudKit-ready so this is additive later)
- Android / cross-platform
- Direct vet-portal or PIMS integration (no open standard exists; every clinic
  differs)
- Drug interaction checking
- Telemedicine, e-commerce, pharmacy ordering
- Social features, community, pet profiles as a network
- Apple Watch app (Phase 5 candidate, not v1)
- Activity/step tracking via third-party collars

## 7. Feature inventory

Grouped by module. Each maps to a section in `04-SCREENS.md` and entities in
`02-DATA-MODEL.md`.

**Medications** — meds list per pet; expressive schedules (fixed times, interval,
every-N-days, weekday sets, cyclic on/off, tapers, monthly preventatives, PRN with
minimum gap, finite courses); dose logging (given / skipped / refused / partial,
with actual time and caregiver); snooze and escalation; inventory and refill
projection; time-zone policy per medication; adherence history and vet report.

**Health record** — weight and body-condition history with charts; vaccinations with
expiry-driven reminders; conditions and diagnoses; allergies and adverse reactions;
vet visit log; lab results with attached documents; a full document vault with
on-device OCR, full-text search, and tagging.

**Contacts and emergency** — typed contacts (primary vet, ER, specialist, pharmacy,
poison control, insurance, microchip registry, boarder, sitter, trainer, groomer)
with tap-to-call, tap-to-map, portal links, hours; per-pet linkage; a dedicated
Emergency screen reachable in two taps from anywhere.

**Grooming** — groomer contact and preferences (style notes with reference photos,
blade lengths, shampoo and allergy constraints, nail/ear/gland cadence, behavior
notes); appointment history; interval-based "next due" projected from last completed,
not from a fixed calendar; shareable groomer brief.

**Compliance and documents** — county license, rabies certificate, microchip
registration, insurance policy, boarding vaccine requirements; each with issue date,
expiry, document scan, registry URL, and configurable lead-time reminders.

**Identity and lost-pet** — multi-angle ID photos; microchip number and registry;
distinguishing marks; generated lost-pet poster (PDF + image, shareable to social or
print); digital ID card; last-seen location; an action checklist for the first hour.

**Feeding and diet** — food products, portions, feeding times, diet restrictions and
food allergies, treat rules, prescription-diet tracking. Included because diet is
medically relevant and because it is the single most-asked sitter question.

**Household** — caregiver profiles (local labels, no accounts); who-did-what activity
log; sitter handoff PDF.

**Power layer** — custom fields on any entity; full JSON+attachments export and
import; CSV log export; Shortcuts / App Intents; Home Screen and Lock Screen widgets;
Live Activity for an open dose window; URL scheme; schedule simulator; notification
queue inspector; app lock (Face ID); themes and unit systems.

## 8. Monetization

**→ Decision needed before Phase 1 ends** (it affects data model and paywall
placement, so it can't be deferred indefinitely).

My recommendation: **free with one non-consumable IAP, "PawChart Pro," around
$14.99.** Free tier covers one pet with unlimited medications and reminders — a
genuinely complete app for the primary user. Pro unlocks multiple pets, the document
vault and OCR, generated reports (vet, sitter, lost poster), widgets, Shortcuts, and
custom fields.

Why this over a subscription: there's no server cost, no recurring value delivery,
and pet owners react badly to subscriptions for what they perceive as a utility. A
subscription would need to justify itself with sync — which is exactly the Phase 6
feature, and the honest time to introduce one.

Why not paid-up-front: discovery is nearly impossible for a new paid app; the free
tier is the acquisition channel.

Implementation note: gate on capability flags read from a single `Entitlements`
service, never on scattered `if isPro` checks. Store purchase state in StoreKit 2's
current entitlements — never in local persistence that a user could edit via the
import path.

## 9. Success criteria for v1

- A new user adds a pet and a twice-daily medication in under 90 seconds without
  reading anything.
- Notifications fire correctly across a DST transition, a time-zone change, and a
  device restart. (This is the top App Store review-bomb risk for reminder apps.)
- A user with 3 pets and 12 total medications never silently loses a reminder to the
  64-notification cap.
- Adherence report, sitter brief, and lost poster each render to a correct PDF.
- Full export → wipe → import restores every byte, including attachments.
- Passes VoiceOver and Dynamic Type at accessibility sizes on every primary screen.
