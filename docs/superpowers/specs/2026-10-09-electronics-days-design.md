# Electronics days ("Dni elektroniki")

## Problem

Players want to bank screen time: every full calendar day spent without
electronics earns one "electronics day", and a banked day can later be spent
("odebrany") on a day the player does use electronics. The character card has
no place for this today, and the project has no backend (no Cloud Functions,
no scheduler) that could tick a counter at midnight.

## Goal

A new **Dni elektroniki** section on every character card that shows:

- how many electronics days the character has available (a number in a ring
  medallion),
- how far "today" has charged (a gold ring around the medallion that fills
  over the local day),
- the state of today: charging, a claim waiting for approval, or claimed,
- an **Odbierz** action to spend a day.

Spending a day is a request the admin approves, except when the admin does it
themselves, which applies immediately. Admins can also set the counter to
any value by hand (including a one-tap "+1 bonus day").

Out of scope: a per-day history view, midnight notifications, a real
cron/scheduler, a per-character start date, requesting bonus days.

## Rules of the counter

- Collecting is always on; there is no toggle.
- Every **full local calendar day** that passes adds 1.
- Claiming day D costs 1 **and** D itself never adds 1. Claiming today
  therefore means today will not be counted at midnight; claiming a day that
  has already passed (late approval) takes back the 1 it already added.
- The claimed day is **the day the player tapped Odbierz**, not the day the
  admin approved it.
- At most one claim per day. Claiming is not offered when the counter is 0.
- Every character starts at **0** on the release day of this feature.
- Day boundaries use the device's local time (all players are in one time
  zone).

## Data model

New optional map on `characters/{id}`:

```
electronics: {
  days:    int,             // the banked count, as of the start of as_of
  as_of:   'YYYY-MM-DD',    // the local day from which accrual continues
  claimed: ['YYYY-MM-DD']   // recently claimed days (idempotency guard)
}
```

- A character with no `electronics` map behaves as
  `{days: 0, as_of: kElectronicsDaysEpoch, claimed: []}`, where
  `kElectronicsDaysEpoch` is a code constant for the first full day after
  the release, 2026-10-10. No migration is needed and every character gets
  the section.
- In Dart, days are plain `int`s counting days since 1970-01-01. They are
  built with `DateTime.utc(y, m, d)` from the local date, which keeps them
  DST-proof and `const`-friendly. They are converted to and from
  `'YYYY-MM-DD'` only at the Firestore boundary.
- Parsing is tolerant in the style of `Character.fromMap`: a non-numeric
  `days` reads as 0, an unparseable `as_of` as the epoch, non-string
  `claimed` entries are dropped.
- `claimed` keeps only the 31 most recent dates.

### Lazy accrual (no cron)

The stored `days` is not touched at midnight. Every reader computes:

```
accrued(today) = max(0, wholeDaysBetween(as_of, today))   // full days in [as_of, today)
available(today) = days + accrued(today)
```

`as_of` can be in the future (after today is claimed it is set to tomorrow),
in which case `accrued` is 0.

Every **write** first **settles** the counter, then applies its change:

```
settle(today):  days += accrued(today);  as_of = max(as_of, today)
```

Writes are:

| Write | Who | Effect after settle |
|---|---|---|
| Set value | admin, edit screen | `days = value` (clamped to ≥ 0) |
| Apply claim of day D | admin accepting a request, or admin direct claim | if D ∈ `claimed`: no-op. Else `days -= 1`; if D < today also `days -= 1` (it was already accrued); if D ≥ today `as_of = D + 1`. Clamp `days` to ≥ 0; add D to `claimed` |

All of this lives in pure functions on an `ElectronicsDays` value class
(`lib/models/electronics_days.dart`) that take `today` as a parameter, so
the arithmetic is unit-tested without Firestore or a clock. Day arithmetic
uses `DateTime.utc(y, m, d)` differences so DST never produces a 23- or
25-hour "day".

## Claim flow

### Player, own character → request

1. Tapping **Odbierz** opens a confirmation ("DZIEŃ Z ELEKTRONIKĄ?",
   `3 → 2`, "Prośba trafi do admina…", ANULUJ / WYŚLIJ PROŚBĘ).
2. Confirming posts an ordinary `change_requests` document with
   `changes: { electronics_claim: '<local date of the tap>' }` through the
   existing `ChangeRequestRepository` create path. It reaches the existing
   admin inbox and fires the existing new-request notification.
3. **Accept** runs inside the existing `accept` transaction: it re-reads the
   character, applies "apply claim of day D" above, and writes the
   `electronics` map alongside the status flip. Accepting a date that is
   already in `claimed` changes nothing on the character, so a double accept
   or a direct admin claim in the meantime is harmless.
4. **Reject**, **cancel** and **restore to pending** keep their current
   behaviour and never touch the character.
5. The player's existing accepted/rejected notifications fire as for any
   other request.

`ChangeSet` gains an `electronicsClaim` field (a date string). A request
carrying it carries nothing else. The inbox and the requester's history show
it as `Dzień z elektroniką: 2026-10-09` via `changeSetLines`. The
edit-then-accept affordance is hidden for such requests, since there is
nothing to edit. The general "Prośba o zmianę" form does not offer it; a
claim can only be started from the card.

### Admin, any character → immediate

The admin sees **Odbierz** on every card, their own included. Its
confirmation reads "Odbierasz dzień dla postaci <name>. Licznik spadnie od
razu…" with ANULUJ / ODBIERZ, and confirming runs "apply claim of today" in a
`runTransaction` on the character. While a player's claim for today is
pending, the admin's card shows state 2 without a button, and the admin
decides it from the inbox.

### Who sees the button

| Viewer | Own character | Someone else's |
|---|---|---|
| regular user | request flow | n/a (cannot see others) |
| `readOnlyOthers` | request flow | section only, no button |
| admin | immediate | immediate |

**Odbierz** is hidden whenever `available == 0` or today is already claimed.
The card states below are checked in order 3 → 2 → 4 → 1.

## Card section UI

The section sits between the gold row and **Cechy**, framed by a divider
heading **DNI ELEKTRONIKI** in the same style as the Cechy heading. On the
left is the ring medallion: the count, with "dostępne" under it, inside the
level-badge-style circle and wrapped in an 84 px progress ring. On the right
are three lines: the label **DZISIEJSZY DZIEŃ** (stat-label style), a bold
italic headline, and a small italic status. Under them is a full-width
button. Polish copy is verbatim:

| State | Condition | Ring | Medallion badge | Headline | Status | Button |
|---|---|---|---|---|---|---|
| 1 Charging | default | gold arc = elapsed fraction of today | — | Ładowanie… | dzień bez elektroniki | **ODBIERZ** (filled crimson) |
| 2 Pending | a pending claim request for today exists for this character (visible to the requester and admins) | same arc, faded crimson | gold, hourglass | Dzień z elektroniką? | czeka na akceptację | **✕ ANULUJ PROŚBĘ** (outlined) → "ANULOWAĆ PROŚBĘ?" dialog (NIE / TAK, ANULUJ) |
| 3 Claimed | today ∈ `claimed` | dashed crimson circle | crimson ✕ | Dzień z elektroniką | odebrano dzisiaj | none |
| 4 Empty | `available == 0`, not claimed | gold arc | — | Ładowanie… | dzień bez elektroniki | none |

State 2 is derived from the pending claim requests the viewer can read: the
requester's own (`myChangeRequestsProvider`) and, for an admin, the whole
queue (`pendingChangeRequestsProvider`). So both the requester and admins
see "czeka na akceptację". Only the requester gets the **ANULUJ PROŚBĘ**
button. An admin sees state 2 with no button, because the request is already
in their inbox to accept or reject.

The ring needs a clock. A `clockProvider` (a `DateTime Function()`,
overridable in tests) feeds a one-minute ticker that rebuilds the section, so
the arc advances and the count rolls over at midnight while the app is open.

Mockups: https://claude.ai/artifact/P5sNjq6FyQ3BiKnviLV4Rb

## Admin edit screen

`EditCharacterScreen` gets a **Dni elektroniki** row showing the current
`available` value, with −/+ steppers and a numeric field. Saving with a
changed value writes `electronics` as "set value" (settle, then
`days = value`, `as_of = today`, `claimed` kept). An unchanged value leaves
the map untouched. `Character.fromMap()` parses the map. `Character.toMap()` deliberately
leaves it out, so the edit screen's ordinary `update(toMap())` never touches
it, and never overwrites a claim accepted while the screen was open. The
counter is written only by the dedicated transactional repository methods.

## Firestore rules

- `/characters` is unchanged: all `electronics` writes are admin writes
  (accept transaction, direct claim, edit screen).
- `/change_requests` create gains one conjunct: if
  `'electronics_claim' in changes`, then `changes.keys().hasOnly(['electronics_claim'])`
  and the value is a string matching `^[0-9]{4}-[0-9]{2}-[0-9]{2}$`. The
  existing own-character, `pending` and no-decision-fields checks already
  cover the rest.
- `/quests` create gains `!('electronics_claim' in request.resource.data.reward)`,
  so a claim can never be smuggled in as a quest reward (and from there into
  `markComplete`'s change request).

## Testing

- **`ElectronicsDays` unit tests:**
  - epoch default;
  - accrual across days, months and a DST change;
  - `as_of` in the future;
  - settle;
  - set value (clamp);
  - claim today, claim a past day (−2), claim an already-claimed date (no-op);
  - claim at 0 clamps;
  - `claimed` trimming;
  - tolerant parsing;
  - state derivation (1–4).
- **Repository tests (`fake_cloud_firestore`):**
  - accepting an `electronics_claim` request updates the character in the same transaction;
  - double accept is a no-op;
  - admin direct claim;
  - edit-screen save writes and preserves the map.
- **Widget tests:**
  - the four states;
  - button visibility for owner, admin and `readOnlyOthers`-on-other;
  - the request and direct-claim dialogs;
  - cancel from state 2;
  - a ticking clock rolls the count over at midnight;
  - the inbox line and the hidden edit affordance.
- **Rules tests (`tools/rules-test`):**
  - a claim request on your own character is allowed;
  - a claim request on someone else's character is denied;
  - a claim combined with `current_xp` is denied;
  - a malformed date is denied;
  - `electronics_claim` in a quest reward is denied.

## Documentation

Update `CLAUDE.md`:
- under the Firestore data model, describe the `electronics` map and the lazy accrual and settle model;
- under Key Behaviors, add an entry for electronics days.
