# Change Requests — Design

Date: 2026-08-27
Status: approved, ready for an implementation plan

## Problem

Only admins can write to `/characters`. A player who earns XP, gold or a new
trait has no way to record it in the app — they have to ask an admin out of
band, and the admin edits the character by hand. This feature gives players a
way to post a structured request for a change, and gives admins a queue where
they review, optionally adjust, and apply it.

## Scope

In scope: posting a request for deltas to `current_xp`, `gold`, `gold_usd` and
upserts to `traits`, with an optional free-text reason; an admin queue that
accepts (applying the change), edits before accepting, or rejects; request
history with outcomes visible to the requester.

Out of scope: requests against `level`, `next_level_xp` or `favour`; requests
against someone else's character; push notifications; Cloud Functions.

## Data Model

New top-level collection `change_requests/{requestId}`:

```
characterId:    string   — the target character document id
characterName:  string   — denormalised for the admin list
requesterUid:   string   — must equal the creator's auth uid
requesterEmail: string   — denormalised for display
status:         'pending' | 'accepted' | 'rejected'
reason:         string?  — optional free text
createdAt:      Timestamp (server timestamp)
changes:        map      — what was asked for (see below)
appliedChanges: map?     — what was actually applied; written on accept
decidedBy:      string?  — admin uid; written on accept/reject
decidedAt:      Timestamp? — written on accept/reject
```

`changes` (and `appliedChanges`, same shape):

```
current_xp: num?   — delta, may be negative, omitted if unchanged
gold:       num?   — delta (PLN)
gold_usd:   num?   — delta
traits:     [ { name: string, value: string } ]?  — upsert by name
```

Numeric entries are **deltas**, not target values, so a request stays correct
if the character changes between posting and acceptance. Trait entries are
**upserts only**: an entry whose `name` already exists on the character
overwrites that trait's `value`; an entry whose `name` is new appends a new
trait. There is no remove operation, and no delta on a trait value — a trait's
value is a free-form string, so a delta on it is meaningless.

A request must carry at least one change; `reason` alone is not a request.

Field names stay snake_case on the Firestore side, per the project convention;
Dart-side names are camelCase and mapped in the model.

### Why a top-level collection

Considered and rejected:

- **Subcollection `characters/{id}/change_requests/{id}`.** Ownership would be
  implied by the parent, simplifying the create rule, but the admin's pending
  queue would then need a `collectionGroup` query with its own index and its
  own collection-group rule, and a requester's "my requests" view would be
  awkward. More moving parts for a smaller rule.
- **A `pending` map field on `characters`.** No new collection, but it requires
  opening the admin-only write rule on `/characters` to every user. Rejected on
  security grounds.

A top-level collection gives the admin queue a single indexed query
(`status == 'pending'` ordered by `createdAt`) and the requester a single
`requesterUid == myUid` query, both of which the rules can satisfy directly.

## Architecture

Follows the existing repository → provider → feature layering.

- `lib/models/change_request.dart` — `ChangeRequest`, `ChangeSet` (the deltas
  plus trait upserts) and `TraitChange`, with tolerant `fromMap` parsing in the
  style of `Character.fromMap` and a `toMap` that omits absent fields.
- `lib/data/change_request_repository.dart` — `ChangeRequestRepository`,
  constructed with a `FirebaseFirestore` exactly like `CharacterRepository`.
  - `Stream<List<ChangeRequest>> watchPending()` — admin queue.
  - `Stream<List<ChangeRequest>> watchForRequester(String uid)` — own history.
  - `Future<void> create(ChangeRequest request)`.
  - `Future<void> accept(ChangeRequest request, {ChangeSet? overrides, required String adminUid})`.
  - `Future<void> reject(ChangeRequest request, {required String adminUid})`.
- `lib/providers/change_request_providers.dart` — `changeRequestRepositoryProvider`,
  `pendingChangeRequestsProvider`, `myChangeRequestsProvider`. Both stream
  providers resolve the user via `await ref.watch(appUserProvider.future)`
  rather than peeking at `.value`, matching `charactersProvider`.
- `lib/features/requests/new_change_request_screen.dart`
- `lib/features/requests/change_requests_screen.dart` (admin queue)
- `lib/features/requests/change_request_form.dart` — the form body, shared by
  the requester screen and the admin's edit-before-accept flow.

Nothing outside `lib/data/firebase_providers.dart` touches
`FirebaseFirestore.instance`.

## Applying a Change

`accept` runs a single `runTransaction`:

1. Re-read the request document. If its `status` is no longer `pending`, abort
   — this makes a double-tap or a stale list a no-op rather than a double
   application.
2. Re-read the character document.
3. For each numeric delta, add it to the character's current value, treating an
   absent field as 0 (so a request for `+10 gold` against a character with no
   `gold` field materialises `gold: 10`).
4. For each trait entry, overwrite the value of the trait with a matching
   `name`, or append a new trait if none matches.
5. Write the character.
6. Set `status: 'accepted'`, `decidedBy`, `decidedAt`, and `appliedChanges` on
   the request.

Steps 5 and 6 are in the same transaction, so either both land or neither does.
`appliedChanges` records what the admin actually applied; `changes` keeps the
original ask, so an edited-then-accepted request shows both.

`reject` is a plain update setting `status`, `decidedBy` and `decidedAt`.

Both writes are admin-only, which is already true of `/characters`, so the
whole apply path runs as an admin.

## UI

Polish throughout, matching the existing parchment-on-dark theme and the
uppercase-at-point-of-use label convention.

### Requester

A round `FloatingActionButton` (`+`, gold on dark) in the bottom-right of
`HomeScreen`, shown to any signed-in user with at least one of their own
characters visible. It pushes `NewChangeRequestScreen`:

- A character picker, rendered **only** when the user's own roster holds two or
  more characters. With exactly one, it is hidden and that character is used.
- Three optional number fields — XP, Złoto, Złoto USD — presented as signed
  deltas. Validation mirrors `EditCharacterScreen`: XP is an integer, the two
  gold fields accept decimals.
- A trait section reusing the existing `Autocomplete` over `traitNamesProvider`
  so known names are suggested while a brand-new name can be typed freely, plus
  a value field and an add button.
- An optional `Powód` free-text field.
- A submit button, disabled until at least one change has been entered.

Below the form, the user's own past requests with their status.

### Admin

A second AppBar action next to the existing user-management button (inbox icon,
with a count badge when anything is pending) opens `ChangeRequestsScreen`:

- Pending requests, newest first, each a card showing requester, character, the
  requested deltas, the reason and the time.
- **Zaakceptuj**, **Odrzuć**, and **Edytuj** — the last opening the shared form
  pre-filled so the admin can adjust the numbers before accepting.
- A filter chip row switching between oczekujące / zaakceptowane / odrzucone.

## Security Rules

New block in `firestore.rules` for `/change_requests/{requestId}`:

- `read`: `isAdmin() || resource.data.requesterUid == request.auth.uid`. The
  requester's client must therefore keep issuing
  `where('requesterUid', isEqualTo: myUid)`, the same constraint the roster
  query already lives under.
- `create`: authenticated, and
  - `request.resource.data.requesterUid == request.auth.uid`
  - `request.resource.data.status == 'pending'`
  - `decidedBy`, `decidedAt` and `appliedChanges` are absent
  - the target character belongs to the caller:
    `get(/databases/$(database)/documents/characters/$(request.resource.data.characterId)).data.email.lower() == request.auth.token.email.lower()`
- `update`, `delete`: `isAdmin()`.

The same case-sensitivity caveat as the roster applies: the rule compares
lowercased emails, so a differently-cased character document is reachable at the
rule level, but the client's own-email query will not surface it, so the picker
will not offer it. This is consistent with existing behaviour, not a new
problem.

A composite index on `change_requests` for `status` + `createdAt` is required
for the admin queue.

## Error Handling

- An aborted transaction — request no longer pending, or permission denied —
  surfaces as a Polish `SnackBar` and the list refreshes; it never fails
  silently.
- Malformed request documents are skipped with a `debugPrint`, mirroring
  `watchCharacters`.
- Parsing is tolerant in the style of `Character.fromMap`. These documents are
  written only by this app, but the roster's history argues against trusting
  the schema.

## Testing

- **Models** (`test/models/change_request_test.dart`): `fromMap`/`toMap` round
  trips, absent optional fields, tolerant parsing of numbers written as
  strings, trait upsert entries.
- **Repository** (`test/data/change_request_repository_test.dart`, over
  `fake_cloud_firestore`): create; accept applying deltas; accept against a
  character with an absent `gold` field materialising it; trait upsert of both
  an existing name and a brand-new name; accept with overrides recording
  `appliedChanges` while preserving `changes`; reject; a second accept on an
  already-accepted request aborting without re-applying.
- **Providers**: `pendingChangeRequestsProvider` and `myChangeRequestsProvider`
  resolve through `appUserProvider`. Remember the Riverpod 3 caveat — attach a
  listener before awaiting `.future` or the test hangs.
- **Widgets**: FAB visible only with an own character; picker hidden at exactly
  one character and shown at two; submit disabled with no changes entered;
  admin list rendering and its accept / reject / edit actions.
- **Rules** (`tools/rules-test/rules.test.mjs`): each clause above, including a
  user creating a request against someone else's character (denied), a
  non-admin flipping a status (denied), a requester reading their own request
  (allowed) and someone else's (denied), and an admin reading all (allowed).
