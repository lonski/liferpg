# Quest Management — Design

Date: 2026-08-28
Status: approved in chat, ready for an implementation plan

## Problem

The only way to earn XP/gold/trait changes today is a free-form change
request: a player asks for a specific delta and an admin approves it. There
is no way to *task* someone — post something that needs doing, let any
player (or one specific player) take it on, and have completing it carry a
pre-agreed reward through the existing approval flow. This feature adds
quests: a shared board of open tasks, direct assignment to a specific
character, a personal view of what's assigned to or posted by you, a global
log of outcomes, and admin-defined recurring daily quests per character.

## Scope

In scope: posting a quest to an open board or directly to a character (own
or another's); taking a board quest; abandoning a taken quest back to the
board; withdrawing an unclaimed posted quest; marking a quest complete
(which raises a `ChangeRequest` for admin review, reusing the existing
accept/reject machinery); a global quest log; a curated, admin-managed
roster of characters eligible for direct assignment (`quest_roster`), since
opening up the full `characters` collection to every signed-in user was
rejected; admin-defined daily quest templates that lazily spawn one
non-terminal instance per character at a time; notifications for direct
assignment, a posted board quest being taken, and new board postings; a
redesigned FAB (speed-dial: quests, change request).

Out of scope: gold as a quest reward (XP and traits only); due
dates/expiry; quests targeting anyone but a character in `quest_roster`;
server-side/Cloud-Function scheduling of daily resets — there are none in
this project, so "daily" is computed client-side; deleting quests from the
log.

## Data Model

### `quests/{questId}`

```
title:                  string
description:            string?
posterUid:              string   — creator's auth uid
posterEmail:            string   — denormalised
posterName:             string   — denormalised, for board/log display
assignedToCharacterId:   string?  — null only while status == 'open'
assignedToCharacterName: string?  — denormalised
assignedToEmail:        string?  — denormalised; owner's login email, for rule checks
status:                 'open' | 'assigned' | 'pending_review' | 'completed' | 'failed' | 'cancelled'
reward:                 map      — { currentXp: num?, traits: [{name, value}]? }, same shape as ChangeSet minus gold
changeRequestId:        string?  — set once a completion is submitted
dailyTemplateId:        string?  — set only for an instance spawned from a daily template
questDate:              string?  — 'yyyy-MM-dd', set only alongside dailyTemplateId
createdAt, updatedAt:   Timestamp (server timestamp)
```

A quest is created either as `open` (no assignment — posted to the board)
or `assigned` (posted directly to a character, including the poster's own).
Numeric/trait entries in `reward` follow the exact same delta/upsert
semantics as `ChangeSet.currentXp`/`ChangeSet.traits` today — no new
semantics to learn.

### `ChangeRequest` gets one new optional field

```
questId: string?   — set when this request was raised by completing a quest
```

Nothing else about `ChangeRequest`, `ChangeRequestRepository`, or the admin
inbox screen changes shape — a quest's completion *is* a normal change
request, just auto-filled and cross-linked.

### `quest_roster/{characterId}`

```
characterId:   string   (== the document id)
characterName: string
email:         string   — the owning character's email, lowercased at write time
```

This is a deliberately thin, admin-curated public index — name and id only,
no stats. It exists solely so the direct-assignment picker and daily-quest
admin screen can offer a roster of characters without widening read access
to the `characters` collection itself (see "Character visibility" below).

### `daily_quest_templates/{templateId}`

```
title, description:                     string / string?
reward:                                  map, same shape as quests.reward
assignedToCharacterId/Name/Email:       string  — always required, never a board template
active:                                  bool
createdBy:                               string  — admin uid
createdAt:                               Timestamp
```

Editing a template only affects instances spawned *after* the edit —
already-spawned `quests` docs are independent snapshots, matching the
existing change-request philosophy of never retroactively rewriting a
past ask.

## Character Visibility (why `quest_roster` exists)

Direct assignment needs the poster to pick from *someone else's* character,
but today only admins/`readOnlyOthers` can read a character outside their
own. Two options were weighed:

- Open `characters` reads to every signed-in user. Rejected — it would leak
  full stats (level, XP, gold, traits) of every character to every player,
  a much bigger privacy change than this feature calls for, and unrelated
  to quests specifically.
- A new, admin-curated `quest_roster` collection carrying only
  `characterId`/`characterName`/`email`. Chosen. Admins opt characters in
  via a toggle in a new panel (folded into the existing user-management
  screen, next to "Ukryte postacie"); the `characters` collection's rules
  are untouched.

The board and quest log never read `characters` or `quest_roster` at
render time — they render off the names already denormalised onto the
`quests` doc at creation time. `quest_roster` is read only by the
direct-assignment picker and the daily-quest admin screen.

## State Machine

```
        (post, no target)              (post directly / take from board)
              │                                      │
              ▼                                      ▼
            open ───────── take (any user) ───────► assigned
              │                                      │  ▲
              │ withdraw (poster)                    │  │ abandon (holder)
              ▼                                      │  └──────────────┘
          cancelled                                  │
          [terminal]                     mark complete (holder)
                                                      │  → creates a ChangeRequest
                                                      ▼
                                              pending_review
                                                 │        │
                                admin accepts ◄──┘        └──► admin rejects
                                      │                            │
                                      ▼                            ▼
                                  completed                     failed
                                  [terminal,                   [terminal,
                                   reward applied]               no retry]
```

Every transition is a single, independently rule-checked document update
(see Security Rules) except "mark complete," which is a transaction writing
both the new `change_request` and the quest's `pending_review` flip
together, and admin accept/reject, which extends the *existing*
`ChangeRequestRepository.accept()`/`reject()` transactions to also flip the
linked quest when `changeRequest.questId != null`.

## Daily Quests

Because there are no Cloud Functions in this project, "daily" is not a
server-enforced reset — it's a lazily-computed instance, created by the
assigned character owner's own client:

1. On each app session (same place the notification baseline check runs,
   watched once from `AuthGate`), for every `active` template whose
   `assignedToCharacterId` is one of the signed-in user's own characters:
2. Skip if a `quests` doc already exists for
   `(dailyTemplateId == template.id, questDate == today)` — at most one
   spawn attempt per template per day.
3. Skip if an earlier instance from this template is still non-terminal
   (`assigned` or `pending_review`) — an unfinished daily quest just
   persists; it is never expired or duplicated. This is what "stays open
   until completed" means in practice.
4. Otherwise create today's instance: a normal `quests` doc, `status:
   'assigned'`, `assignedTo*` copied from the template, `reward` copied
   from the template, `dailyTemplateId`/`questDate` set. The doc id is
   deterministic — `${templateId}_${questDate}` — and the create uses a
   plain (non-transactional) create-if-absent write, so a race between two
   near-simultaneous sessions is harmless: the second create simply fails
   against an already-existing doc id and is ignored.

From here a daily instance is indistinguishable from any other assigned
quest — same completion flow, same notifications, same log entry. The UI's
only tell is a small "🔁 Codzienne" badge on the card, driven by
`dailyTemplateId != null`.

## Security Rules

New blocks in `firestore.rules`, following the existing
`isAdmin()`/`isReadOnlyOthers()`/own-email helper pattern:

**`quests/{questId}`**
- `read`: any authenticated user (board and log are visible to everyone).
- `create`: authenticated;
  `posterUid == request.auth.uid`; `status` is `'open'` (with no
  `assignedTo*` fields) or `'assigned'` (with all three `assignedTo*`
  fields set, and `get()` on `quest_roster/$(assignedToCharacterId)`
  confirming the target is actually on the roster); `reward` is non-empty
  and shaped like a `ChangeSet` minus gold; no `changeRequestId`.
- `update`, one clause per transition, each requiring
  `diff(resource.data).affectedKeys().hasOnly([...])` on exactly the
  fields that transition touches (mirrors the existing requester-cancel
  clause on `change_requests`):
  - **take**: `resource.data.status == 'open'`, new `status == 'assigned'`,
    touches only `status`/`assignedTo*`, the caller's own email
    (lowercased) matches `request.resource.data.assignedToEmail`, and
    `get()` on `characters/$(request.resource.data.assignedToCharacterId)`
    confirms that character actually belongs to the caller — the same
    ownership cross-check `change_requests` already does at create time.
  - **abandon**: caller's email matches the *current*
    `resource.data.assignedToEmail`; `status` goes `assigned → open`;
    touches only `status`/`assignedTo*` (cleared).
  - **withdraw**: `resource.data.posterUid == request.auth.uid`; `status`
    goes `open → cancelled`; touches only `status`.
  - **mark complete**: caller's email matches
    `resource.data.assignedToEmail`; `status` goes
    `assigned → pending_review`; touches only `status`/`changeRequestId`.
  - **admin resolve**: `isAdmin()`; `status` goes
    `pending_review → completed` or `pending_review → failed`; touches only
    `status`.
- `delete`: never (no deletion in scope).

**`quest_roster/{characterId}`**
- `read`: any authenticated user.
- `write` (create/update/delete): `isAdmin()`.

**`daily_quest_templates/{templateId}`**
- `read`: `isAdmin() || resource.data.assignedToEmail.lower() ==
  request.auth.token.email.lower()`.
- `write`: `isAdmin()`.

**`change_requests`**: no rule changes. A quest-originated request is
created by the same client-side transaction and under the same `create`
rule as any other — `questId` is just an extra field on an otherwise
ordinary document. The existing admin-only `update` rule already covers
the accept/reject transaction touching the linked quest, since that quest
write is validated independently under the "admin resolve" clause above.

Composite indexes needed: `quests` on `status` (board query), on
`(assignedToCharacterId, status)` ("Moje" tab / daily-template dedupe
check), and on `(posterUid, status)` (posted-by-me section).

## Architecture

Follows the existing repository → provider → feature layering.

- `lib/models/quest.dart` — `Quest`, `QuestStatus`, `QuestReward` (reusing
  `TraitChange` from `change_request.dart`), tolerant `fromMap`/`toMap` in
  the style of `Character.fromMap`.
- `lib/models/change_request.dart` — add optional `questId` to
  `ChangeRequest`.
- `lib/models/daily_quest_template.dart` — `DailyQuestTemplate`.
- `lib/models/quest_roster_entry.dart` — thin model for `quest_roster`.
- `lib/data/quest_repository.dart` — `QuestRepository`:
  `watchOpen()`, `watchAssignedTo(characterId)`,
  `watchPostedBy(uid)`, `watchLog()` (terminal statuses, newest first,
  client-side sort exactly like `ChangeRequestRepository`), `create()`,
  `take()`, `abandon()`, `withdraw()`, `markComplete()` (the
  quest+change-request transaction).
- `lib/data/change_request_repository.dart` — extend `accept()`/`reject()`
  to also flip the linked quest inside the same transaction when
  `questId != null`.
- `lib/data/quest_roster_repository.dart`,
  `lib/data/daily_quest_template_repository.dart` — admin CRUD plus, for
  templates, the per-session `ensureTodaysInstances(characterId)` spawn
  check described above.
- `lib/providers/quest_providers.dart`,
  `lib/providers/daily_quest_providers.dart` — mirroring
  `change_request_providers.dart`'s pattern of resolving through
  `appUserProvider` rather than peeking at `.value`.
- `lib/providers/quest_notification_providers.dart` — extends
  `change_request_notification_providers.dart`'s per-uid baseline-seeding
  pattern (SharedPreferences, `null` meaning "no baseline yet") to the
  three new quest events. Accept/reject-on-completion notifications need
  no new code — a quest completion is a real `change_request`, so it
  already flows through the existing "my request was decided" check.
- `lib/features/quests/` — `quests_screen.dart` (tab host: Tablica / Moje /
  Dziennik), `quest_card.dart`, `new_quest_screen.dart`,
  `quest_roster_admin_screen.dart`, `daily_quest_admin_screen.dart`.
- `lib/features/home/home_screen.dart` — FAB becomes a speed-dial.

Nothing outside `lib/data/firebase_providers.dart` touches
`FirebaseFirestore.instance`.

## UI

Polish throughout, matching the existing parchment-on-dark theme, the
ornamental card treatment (`TopBand`/`CornerOrnament`/`BottomBand`,
`cardGradient`), and the uppercase-at-point-of-use label convention.

### FAB

The existing round FAB rotates into a ✕ and reveals two labeled mini-FABs
above it: **Zadania** (opens `QuestsScreen`) and the existing **Prośba o
zmianę** (opens `NewChangeRequestScreen`, unchanged). Same visibility gate
as today (shown only to a user who owns a character).

### `QuestsScreen`

Three tabs:

- **Tablica** — open quests, newest first, each card showing title,
  poster, reward, and a **PODEJMIJ** action. Taking a quest reuses the
  existing own-character-dropdown pattern from `NewChangeRequestScreen`
  when the taker owns more than one character.
- **Moje** — two sections. "Przypisane do mnie": quests assigned to the
  user's own character(s) that are `assigned` (Ukończ / Porzuć actions) or
  `pending_review` (status badge only, no actions). "Wystawione przeze
  mnie": quests the user posted that are still `open` (Wycofaj action).
  Daily-quest instances show the 🔁 badge here.
- **Dziennik** — global feed of terminal quests (`completed`/`failed`/
  `cancelled`), newest first: title, poster, who did it, reward, and a
  muted-green ("ZAAKCEPTOWANE") or muted-red ("ODRZUCONE") outcome badge —
  the only place this app's palette departs from pure
  crimson/gold/parchment, kept deliberately desaturated to stay in theme.

### `NewQuestScreen`

Title, optional description, reward (XP delta plus the existing
`Autocomplete`-over-`traitNamesProvider` trait upsert row from
`ChangeRequestForm`), and an optional "Wybierz postać…" picker sourced from
`quest_roster` (including the poster's own characters — self-assignment is
allowed). Leaving it empty posts to the board; picking a character assigns
directly. Submit label follows the choice ("WYSTAW NA TABLICĘ" /
"WYSTAW ZADANIE").

### Admin screens

Folded into the existing user-management screen, alongside "Ukryte
postacie":

- **Uczestnicy zadań** — every character (admin already reads the full
  `characters` collection) with a toggle for roster membership; toggling
  writes/deletes the corresponding `quest_roster/{characterId}` doc.
- **Codzienne zadania** — list of templates per character; create/edit
  (title, description, reward) and an active/paused toggle. No delete in
  the first version — pause covers "stop this" without orphaning past
  instances' `dailyTemplateId` references.

## Notifications

Extends `ChangeRequestNotificationRepository`'s per-uid, baseline-seeded
SharedPreferences pattern (a fresh install/first-session snapshot is saved
silently, never floods notifications for pre-existing quests) to three new
events, watched the same way as today — while the app process is alive,
never a true push:

1. A quest is assigned directly to your character.
2. A quest you posted to the board is taken by someone.
3. Any new quest is posted to the open board (visible to all users, like a
   town crier).

Accept/reject-on-completion needs no new notification code — it already
fires via the existing "my change request was decided" check, since a
quest completion is an ordinary `change_request` document.

## Error Handling

- Every transaction (`take`, `abandon`, `withdraw`, `markComplete`, the
  extended `accept`/`reject`) re-reads its target inside the transaction
  and aborts on a stale/already-transitioned status, surfacing a Polish
  `SnackBar`, exactly like the existing `ChangeRequestNoLongerPending`
  pattern — a double-tap or a stale list is a no-op, never a double
  application or a corrupted state.
- The daily-template spawn check is a plain create-if-absent write (not a
  transaction) — a race between two sessions creating the same
  deterministic doc id is expected and harmless; the loser's write simply
  fails against an existing document and is silently ignored.
- Malformed quest/template/roster documents are skipped with a
  `debugPrint`, mirroring `watchCharacters`.

## Testing

- **Models**: `fromMap`/`toMap` round trips for `Quest`,
  `DailyQuestTemplate`, `QuestRosterEntry`; the new `questId` field on
  `ChangeRequest`.
- **Repository** (`fake_cloud_firestore`): full state machine — post to
  board, post direct (including self-assignment), take, abandon back to
  open, withdraw, mark complete (creates the linked `change_request` and
  flips to `pending_review`), admin accept flips the quest to `completed`
  and applies the reward, admin reject flips it to `failed`; a second
  transition attempt on an already-transitioned quest aborting without
  effect. Daily spawn: no instance exists yet → creates one; a non-terminal
  instance exists → skipped; a terminal instance exists for today's date →
  skipped even though non-terminal check would otherwise pass; template
  inactive → skipped.
- **Providers**: mirror the `appUserProvider`-resolution and
  listen-before-`.future` patterns already used for change requests.
- **Widgets**: FAB speed-dial open/close and both destinations; board card
  actions; Moje tab's two sections and per-status action visibility;
  Dziennik badge colors; new-quest form's board-vs-direct submit label;
  admin roster toggle; admin template CRUD.
- **Rules** (`tools/rules-test/rules.test.mjs`): each `quests` transition
  clause (including a non-holder attempting abandon/mark-complete, denied;
  a non-poster attempting withdraw, denied; a direct-assign create
  targeting a character absent from `quest_roster`, denied); `quest_roster`
  write denied to non-admins; `daily_quest_templates` read allowed to the
  assigned character's owner and denied to an unrelated user; the extended
  `change_requests` accept/reject still admin-only.
