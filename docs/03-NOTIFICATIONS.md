# Notifications

How FloofSync delivers every reminder it promises while iOS silently drops any
pending local notification past **64 per app**. This is the hardest problem in
the product and the top review-bomb risk (`07-BUILD-ROADMAP.md`, risk register).
All of it lives in `ReminderKit`.

## 1. The budget problem, with numbers

iOS keeps at most 64 *pending* `UNNotificationRequest`s per app; adding the 65th
silently discards the oldest-scheduled. There is no error, no callback.

Worst honest case from the success criteria (`00-OVERVIEW.md` §9): 3 pets,
12 medications, average 2 doses/day → 24 discrete reminders/day. Naively
scheduling one request per occurrence exhausts 64 slots in **2.6 days**. Add
refill, compliance, and grooming reminders and it's under 2 days. A user who
doesn't open the app for a long weekend starts missing reminders with no
indication anything is wrong. That failure mode is disqualifying for a
medication app, so the entire design below exists to make it impossible.

## 2. Strategy overview

Three techniques, applied in order, each multiplying the horizon:

1. **Repeating triggers where the pattern allows** (§3). A fixed daily 8:00 dose
   is *one* `UNCalendarNotificationTrigger(repeats: true)` — one slot covers an
   unbounded horizon.
2. **Grouping within a delivery window** (§4). Doses for multiple pets/meds
   scheduled within the same 10-minute window share one request.
3. **A rolling horizon with priority-ordered culling** (§5) for everything that
   can't repeat (tapers, cycles, finite courses, intervals). The scheduler fills
   remaining slots furthest-need-first and *visibly reports* the coverage date.

Plus one honesty mechanism: the **coverage indicator** (§8) — the app always
knows and shows the date through which reminders are guaranteed.

## 3. Repeating triggers

`ScheduleEngine` classifies each `ScheduleSpec` as *steady-state* or *finite*:

- **Steady-state** (repeating trigger eligible): `fixedTimes` with `.daily` or
  weekday sets and `EndPolicy.openEnded`; `monthly` with `.openEnded` on days
  1–28. Each `(time × day-pattern)` becomes one repeating
  `UNCalendarNotificationTrigger` with `DateComponents(hour:minute:)` (+
  `weekday` for weekday sets, + `day` for monthly). Cost: one slot, forever.
- **Finite / shifting** (discrete triggers required): tapers, cyclic blocks,
  `everyNDays` (stride breaks `DateComponents` repetition), intervals (anchor
  drifts with each dose), finite courses (must stop), and monthly on day 29–31
  (clamping differs per month).

Repeating triggers are exempt from horizon math — they never expire. The
budget below concerns only discrete triggers.

**DST note:** calendar triggers fire on *wall-clock* components, which is
exactly the `localWallClock` policy. For `fixedZone` medications the trigger's
`DateComponents.timeZone` is set to the fixed zone. Nonexistent wall times
(spring-forward 02:30) fire at the first existing instant; this matches
`ScheduleEngine`'s occurrence semantics (`02-DATA-MODEL.md` §3.2), so what the
app displays and what fires never disagree.

## 4. Grouping

Occurrences from different medications scheduled within the same **10-minute
window** collapse into one request:

> **8:00 AM — Bella and Otis**
> Bella: gabapentin 100 mg · Otis: insulin 2 IU + breakfast

- Window: occurrence times truncated to 10-minute buckets; a bucket with >1
  occurrence renders a combined title/body listing each pet and dose.
- Tapping opens Today filtered to that window's doses; each dose is logged
  individually there. Notification actions (§7) are suppressed on combined
  requests — "Mark all given" from a lock screen invites logging errors on
  exactly the doses that matter.
- Grouping applies to discrete triggers only; repeating triggers for the same
  wall time are merged at creation time (one repeating request per bucket).

Identifier scheme (stable, diffable): `dose/<bucketISO8601>/<zonePolicyHash>`
for groups, `dose/<medID>/<occurrenceISO8601>` for singles.

## 5. The rolling horizon and priority culling

After repeating triggers and system reserve, the discrete budget is:

```
64 slots
 − repeating triggers in use
 − 6 reserved (snoozes in flight, refill/compliance nearest-due, keep-alive)
 = discrete budget (typically 40–55)
```

The scheduler (`HorizonPlanner`, a pure function in `ReminderKit`, unit-tested
against a stub notification center) plans as follows:

1. Compute all discrete occurrences for the next **14 days** across all pets.
2. Sort by `(scheduledAt, priority)` — chronological first, because a reminder
   for tomorrow is worth more than one for next Thursday.
3. Fill slots in order until the budget is spent. Record the timestamp of the
   first *unscheduled* occurrence — that is the **coverage limit**.
4. If the budget ran out inside 48 hours (pathological med counts), degrade by
   *priority*: `flexible` occurrences (feeding, grooming) are dropped from the
   plan before `standard` (compliance, refills) before `critical` (medications).
   A `critical` occurrence inside 48 h is **never** unscheduled — if the plan
   cannot fit them all, widen grouping windows to 30 min for the overflow region
   and re-plan. (24 critical doses/day grouped into 30-minute buckets cannot
   exceed 48 requests/day; in practice grouping collapses far more.)

The plan is **diffed** against currently pending requests (fetched via
`pendingNotificationRequests()`): only removed/changed/added identifiers are
touched. No "cancel all + re-add" — that loses in-flight snoozes and burns CPU.

### Re-planning triggers (in priority order, per `01-ARCHITECTURE.md` §5)

1. Synchronously after any schedule/log/inventory mutation, before the sheet
   dismisses
2. On `scenePhase == .active`
3. On `BGAppRefreshTask` (opportunistic, never load-bearing)
4. Never from a service extension (remote-push only — not available)

### Keep-alive

The last slot in every plan is a keep-alive request scheduled at
`coverageLimit − 24h`: *"Open FloofSync to keep reminders running — reminders
are scheduled through Friday."* It is cancelled and re-planned on every app
open; the only user who ever sees it hasn't opened the app in ~2 weeks and
never got background refresh. Ugly, honest, and strictly better than silence.

## 6. Delivery-time verification

A calendar trigger scheduled Tuesday fires with Tuesday's content even if the
world changed Wednesday (med discontinued, dose logged early, schedule revised).
Mitigations:

- Every mutation re-plans synchronously (§5), so stale pending requests only
  survive if the app was killed mid-mutation — the next foreground re-plan fixes
  them.
- Notification content never contains *instructions* that can go stale
  dangerously (no amounts in the body for revised-schedule meds; the Today
  screen is the source of truth the tap lands on).
- `UNUserNotificationCenterDelegate.willPresent` re-checks the occurrence
  against the live store when the app is foreground; already-logged doses
  suppress their banner.

## 7. Categories, actions, snooze, escalation

```
Category "DOSE_SINGLE":  [Log given]  [Snooze 10 min]   (foreground: opens log sheet)
Category "DOSE_GROUP":   (no actions — tap opens Today at that window)
Category "REFILL":       [Mark refilled]  [Remind tomorrow]
Category "RENEWAL":      [Open item]      [Remind in a week]
Category "KEEPALIVE":    (no actions)
```

- **Snooze** schedules a discrete request from the reserved pool at
  `now + defaultSnoozeMinutes` (per-med override in Advanced). Snoozing never
  reschedules the underlying occurrence — adherence reporting still measures
  against the original `scheduledAt`.
- **Escalation** (per-med, Advanced, off by default): if a `critical` dose is
  unlogged 30 min past its time, one follow-up notification fires from the
  reserved pool. One, not a ladder — this is a reminder app, not an alarm clock.
- **Interruption level**: `critical` meds use `.timeSensitive` (breaks through
  Focus, allowed by default entitlement). The Critical Alerts entitlement
  (break through mute) is designed for but **not requested** in v1
  (`07-BUILD-ROADMAP.md`, review pitfall 7).
- All actions route through `DataActor`; logging from a notification action
  works with the app killed (background delegate launch).

## 8. The coverage indicator and the Inspector

**Coverage indicator** (always visible in Settings → Reminders; surfaces on
Today only when coverage < 7 days): *"Reminders scheduled through Fri Jun 12."*
This converts the invisible 64-slot failure into a visible, comprehensible
state. It is computed from the last plan, not re-derived in the view.

**Reminder Inspector** (Settings → Advanced → Diagnostics; also a debug-menu
item in development builds): lists every pending request — identifier, fire
date, trigger type, category, med linkage — plus the current budget arithmetic
(repeating count, discrete count, reserve, coverage limit) and a "re-plan now"
button. Built in Phase 2 *before* the rest of the pipeline is trusted, because
it is the only way a human can see what iOS actually has queued.

## 9. Permission flow

- Ask for provisional-free **full authorization** at the moment the user creates
  their first reminder-bearing item (first medication save), never at app
  launch. The pre-permission sheet states the stakes plainly: "FloofSync works
  by reminding you. Without notifications, you'll only see doses when you open
  the app."
- Denied → the app still functions fully; Today shows a persistent, dismissable
  banner linking to Settings. Every schedule save while denied re-shows a
  one-line inline note, not a modal.
- `.timeSensitive` usage is declared in the permission rationale.
- Authorization status is re-checked on every foreground; revocation flips the
  coverage indicator to "Notifications off".

## 10. Testing

Per the strategy table in `07-BUILD-ROADMAP.md`:

- `HorizonPlanner` is pure: `(occurrences, pending, budget, now) → plan diff`.
  Swift Testing covers: budget exhaustion order, priority-degradation order,
  the critical-within-48h invariant, group-window widening, diff minimality
  (unchanged requests untouched), keep-alive placement, reserve accounting.
- A `NotificationCenterStub` records add/remove calls for pipeline tests.
- Manual device matrix: DST boundary with a 02:30 dose, force-quit + scheduled
  fire, 3-pet saturation, Focus modes, and a device restart (pending requests
  survive restart; verify the delegate re-attaches).
