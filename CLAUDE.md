# LifeRPG

A native Flutter Android app that gamifies real life — users are RPG characters with levels, XP, gold, and a "favour" (mood/disposition) score tracked over time. Originally a React web app; rewritten to Flutter for Android.

## Tech Stack

- **Flutter** (stable) / **Dart** — Android application
- **Firebase** — Firestore (database) + Google Auth, project `liferpg-f3bab`
- **Riverpod** (`flutter_riverpod`) — state management over a repository layer
- **flutter_test** + `fake_cloud_firestore` + `firebase_auth_mocks` — testing

## Commands

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>   # debug on device
flutter test                                                        # run tests
flutter analyze                                                     # lint
flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID=<id>
```

Add `--dart-define=SHOW_FAVOUR=true` to enable the favour UI.

`<web client id>` is the OAuth **web** client id from the Firebase console (Authentication → Sign-in method → Google → Web SDK configuration), not the Android client id. Every `flutter run`/`flutter build` invocation needs it or Google sign-in fails to initialize. It can also be read off a local `android/app/google-services.json` (the `client_type: 3` OAuth entry) without touching the Firebase console — see `.claude/skills/installing-app/SKILL.md` for a one-shot build+`adb install` recipe.

## Project Structure

`lib/` holds `main.dart` (Firebase + SharedPreferences init, auth gate),
`theme/` (palette, ornaments), `models/`, `data/` (repositories plus the
`firebaseAuthProvider` / `firestoreProvider` / `sharedPreferencesProvider`
test seams), `providers/` (Riverpod), and `features/` (login, home,
character, users). Tests mirror that tree under `test/`.
Firestore rules have their own emulator-based test suite in `tools/rules-test/`.

## Firestore Data Model

**`users/{uid}`**
```
uid, name, email, authProvider, admin (bool), readOnlyOthers (bool)
```

**`characters/{id}`**
```
name, clazz, email, level, current_xp, next_level_xp, gold, favour
traits: [{ name: string, value: string }]  (optional)
```

- Characters are linked to users via `email`.
- Admin users see **all** characters and can edit any; `readOnlyOthers` users see all characters but cannot edit any; regular users see only their own.
- **This split is enforced server-side in `firestore.rules`, not just by the client query.** `/characters` reads require `isAdmin() || isReadOnlyOthers() || resource.data.email.lower() == request.auth.token.email.lower()`; writes require `isAdmin()`. A regular user's unconstrained collection query is therefore *rejected* by Firestore — the client must keep issuing `where('email', isEqualTo: <own email>)` (see `lib/data/character_repository.dart`), otherwise the home screen breaks with PERMISSION_DENIED.
- **Case-sensitivity caveat (measured, not theoretical — half-fixed):** the rule now compares `.lower()` of both sides, so a character document whose `email` differs only in case from the owner's Google auth email (e.g. `Ala@Example.com` vs `ala@example.com`) **is allowed** to that owner at the rule level — a direct `get` succeeds. However this does **not** make the character appear in the app: the client's own-email query (`where('email', isEqualTo: <own email>)`) is matched by Firestore's server-side index using an exact, case-sensitive comparison, which the rule change cannot affect. That query still returns zero documents for a differently-cased character, so the owner's roster still shows it as missing. The rule fix only closes the direct-access hole; the underlying data (`email` on the character document) must still be corrected to match the owner's login email for the character to actually show up. A character document with no `email` field at all errors during `.lower()` evaluation, which Firestore treats as a denial for a regular user; admins and `readOnlyOthers` users still see it because their clauses in the `||` chain short-circuit before the `.lower()` comparison is evaluated (measured in `tools/rules-test/rules.test.mjs`).

**`change_requests/{id}`**
```
characterId, characterName, requesterUid, requesterEmail
status: 'pending' | 'accepted' | 'rejected' | 'cancelled'
reason (optional), createdAt (server timestamp)
changes:        { current_xp?, gold?, traits?: [{name, value}] }
appliedChanges: same shape, written on accept
decidedBy, decidedAt: written on accept/reject
```

- Numeric entries in `changes` are **deltas**, not target values, so a request
  stays correct if the character changes before an admin accepts it. Trait
  entries are deltas too, matched **by name**: a matching trait's value has
  the request's value *added* to it, while a new name is appended with the
  request's value as its starting value. There is no remove operation.
- Any signed-in user may post a request **for their own character only**;
  the rule checks the target character's email against the caller's, and that
  the request names the caller as `requesterUid` and is `pending` (with no
  `decidedBy`/`decidedAt`/`appliedChanges` fields — those are the admin's to
  write).
- Only admins may read the whole collection or update a request to
  accept/reject it; a requester may additionally flip their own still-pending
  request to `cancelled` (and touch no other field) — see `firestore.rules`.
  A regular user's query must therefore carry
  `where('requesterUid', isEqualTo: <own uid>)`, exactly like the roster's
  own-email query.
- Accepting runs a `runTransaction` on the **admin's client** (there are no
  Cloud Functions in this project): it re-reads the request, aborts with
  `ChangeRequestNoLongerPending` if it is no longer pending, applies the
  deltas to the character, and flips the status — all atomically, so a
  double-tap cannot apply a request twice.
- `ChangeRequestRepository` sorts newest-first **client-side** rather than with
  `orderBy`. This is deliberate: a request whose server timestamp has not
  landed yet has a null `createdAt` and an `orderBy` query would drop it.
- Applying a delta `.toInt()`s the resulting `current_xp` (XP is always
  whole), while `gold` stays `num` so a fractional delta is preserved. A
  non-numeric legacy value on the character (e.g. a stringly
  `gold` field from the React era) is coerced to `0` before the delta is
  added, per the same tolerant-parsing philosophy as `Character.fromMap` —
  so a badly-typed legacy field silently absorbs the delta into a fresh
  value rather than the transaction erroring. A trait's existing value gets
  the same tolerant coercion before the request's delta is added to it (so a
  free-text legacy trait value, e.g. `"Wojownik"`, is treated as `0`).

**`quests/{id}`**
```
title, description (optional), posterUid, posterEmail, posterName
status: 'open' | 'assigned' | 'pending_review' | 'completed' | 'failed' | 'cancelled'
assignedToCharacterId, assignedToCharacterName, assignedToEmail (all optional)
reward: { current_xp?, traits?: [{name, value}] }  (never gold)
changeRequestId (optional), createdAt (server timestamp)
```

**`quest_roster/{characterId}`**
```
characterName, email
```

- The roster is a thin, admin-curated index of characters eligible for direct
  quest assignment (name/email only, never stats) — see the user management
  screen's roster panel. The document id is always the character's own id.
- State machine: `open` (on the board, unassigned) → `assigned` (a character
  holds it, via take-from-board or direct assignment) → `pending_review` (the
  holder marked it complete, awaiting an admin) → `completed` or `failed`
  (an admin accepted/rejected the linked change request). An `open` quest can
  also go straight to `cancelled` (poster withdraws it), and an `assigned`
  quest can be abandoned back to `open`.
- A quest can be created already `assigned` (a direct assignment against the
  roster) instead of `open` — this is a poster-chosen target at creation
  time, not a transition, and self-assignment (posting a quest already
  assigned to your own character) is explicitly allowed by design.
- Completion never touches the character directly: `QuestRepository.markComplete`
  raises a `change_requests` document carrying `questId`/`questTitle` (the
  same shape as an ordinary XP/trait request) and flips the quest to
  `pending_review`, both in one transaction. Accepting or rejecting that
  request flips the quest to `completed`/`failed` in the same transaction as
  the decision (see `ChangeRequestRepository.accept`/`reject`); restoring a
  rejected request back to `pending` (an existing admin affordance) likewise
  flips the quest back to `pending_review`, so it never gets stranded in
  `failed` while its request is live again.
- `reward` reuses `ChangeSet`'s shape but a `gold` delta is rejected by the
  create rule — quests only ever pay out XP and/or traits.
- `QuestRepository` sorts newest-first client-side, same reasoning as
  `ChangeRequestRepository`.

## Key Behaviors

- **Auth**: auth state is driven by `firebaseAuthProvider`; unauthenticated users are routed to the login screen.
- **Admin**: `user.admin === true` unlocks the edit button on each character card and shows all characters.
- **ReadOnlyOthers**: `user.readOnlyOthers === true` allows viewing all characters but cannot edit any. Both roles are resolved in the rules by a `get()` on the caller's own `users/{uid}` document, so every signed-in user needs that document to exist.
- **Favour**: integer; rendered as mood emoji (< -1 = very unhappy, -1 = unhappy, 0 = neutral, > 0 = happy).
- **Currency**: `gold` = PLN (złoty), displayed as a chip if present.
- **XP badge**: tapping the XP progress bar toggles a chip showing XP remaining to next level.
- **Change requests**: a round `+` FAB on the home screen (shown to any user
  who owns a character) opens a form for requesting XP / gold / trait changes.
  Admins get an inbox action in the AppBar opening the queue, where each
  request can be accepted, edited-then-accepted, or rejected; a rejected
  request can be restored to pending by an admin, and a requester can cancel
  their own still-pending request.
- **Hiding characters**: an admin can hide a character from their own roster
  view via an "Ukryj" action in that character's edit screen (reachable only
  through the card's edit icon, so implicitly admin-only — there is no hide
  action on the card itself). This is per-admin and on-device only
  (`SharedPreferences`, keyed by uid) — it is never written to Firestore, so
  it never affects what the owning player, other admins, or this same admin
  on a different device see. Hidden characters can be brought back from a
  "Ukryte postacie" section in the user management
  screen. `readOnlyOthers` users do not get this affordance.
- **Quests**: the home screen's FAB is a speed-dial (`_QuestFab`) — it
  replaces the old single-button FAB, rotating into a close icon and
  revealing two labeled mini-FABs: "Zadania" (the tabbed `QuestsScreen`
  below) and the existing "Prośba o zmianę" form. `QuestsScreen` has three
  tabs: TABLICA (the open board, with a Podejmij action per quest), MOJE
  (quests assigned to or posted by your own characters, with
  Ukończ/Porzuć/Wycofaj actions), and DZIENNIK (the global outcome log —
  every `completed`/`failed`/`cancelled` quest, visible to everyone). Posting
  a new quest (round `+` AppBar action) optionally targets a `quest_roster`
  character directly instead of the board.
- **Change-request notifications**: a real Android system-tray notification
  (via `flutter_local_notifications`) fires when a new pending request is
  created (to admins) or when the signed-in user's own request is accepted or
  rejected. There are no Cloud Functions in this project (see below), so this
  rides the app's existing Firestore streams (`pendingChangeRequestsProvider`,
  `myChangeRequestsProvider`) from `lib/providers/change_request_notification_providers.dart`
  rather than true push — it only fires while the app process is alive
  (foreground or backgrounded-but-not-killed), never when fully closed.
  `ChangeRequestNotificationRepository` (SharedPreferences, per-uid, `null`
  meaning "no baseline yet") records which pending ids and which own-request
  statuses have already been surfaced, so the first snapshot after install
  seeds silently instead of flooding notifications for requests that already
  existed, and a request leaving the pending list is dropped from the
  notified set so a later restore-to-pending notifies again.
- **Quest notifications**: the same real-notification, same-baseline-seeding
  approach covers three quest events, from
  `lib/providers/quest_notification_providers.dart`: a new open-board quest
  (to everyone but its poster), a quest newly assigned to one of your own
  characters, and a posted quest of yours being taken off the board. A quest
  created already `assigned` (a direct assignment) is excluded from the
  "someone took it" notification — that phrasing only fits a genuine
  `open` → `assigned` transition — and self-assignment doubly so, since the
  poster and the assignee are the same person.

## UI Language

The UI is in **Polish**. Labels (Poziom, Złoto, XP, Przychylność, etc.) are verbatim from the retired React app and must never be translated. Four label styles render uppercase via `.toUpperCase()` at the point of use while the Dart string literals themselves stay in normal casing — don't "fix" the casing in the literals.

## Conventions

- Never touch `FirebaseAuth.instance` or `FirebaseFirestore.instance` outside
  `lib/data/firebase_providers.dart` — tests override those two providers. The one
  exception is `main()`, which sets Firestore persistence before any `ProviderScope`
  exists and therefore cannot route through a provider. `SharedPreferences.getInstance()`
  carries the identical rule and the identical one exception, via
  `lib/data/shared_preferences_provider.dart`'s `sharedPreferencesProvider`.
- Colours are `const Color(0xAARRGGBB)` literals with alpha baked in.
- Firestore field names stay snake_case (`current_xp`, `next_level_xp`);
  Dart-side names are camelCase and mapped in the models.
- `google-services.json`, `firebase_options.dart` and `android/key.properties`
  are gitignored; CI restores them from secrets.

## CI/CD

- `.github/workflows/android-pr.yml` — analyze, test, debug APK as an artifact.
- `.github/workflows/android-release.yml` — triggered by pushing a tag
  matching `v*` (e.g. `git tag v1.0.2 && git push origin v1.0.2`), not by
  pushing to `master`. The tag is the semver part of `pubspec.yaml`'s
  `version:` only — drop the `+build` suffix (that suffix is Android's
  `versionCode`/iOS's `CFBundleVersion`, internal bookkeeping that must
  strictly increase per build; it has no reason to appear in the tag name).
  Builds a signed release APK and publishes it as a GitHub Release under the
  pushed tag. Firebase App Distribution is temporarily removed (service
  account was returning 403 on upload); re-add it once that's fixed. See
  `.claude/skills/releasing-app/SKILL.md` for the full release checklist.

## Build gotchas (hard-won — read before debugging a build failure)

- **checker-qual on the compile classpath**: `android/build.gradle.kts` adds
  `compileOnly("org.checkerframework:checker-qual:3.43.0")` to every Android
  subproject. Firebase Auth's published AAR carries
  `org.checkerframework.checker.initialization.qual.UnknownInitialization` type
  annotations in its bytecode without declaring `checker-qual` as a dependency in
  its POM. Kotlin 2.4 turns an unresolvable annotation on an *inferred* type into a
  hard compile error, breaking `:firebase_auth:compileDebugKotlin`. Do not remove
  this dependency.
- **minSdk is pinned to `flutter.minSdkVersion` (24), not lower**: Flutter's
  MinSdkVersionMigration rewrites any below-floor `minSdk` value back up on every
  build, so trying to pin it lower is pointless and will silently be reverted.
- **JDK for bare `./gradlew`**: `flutter build`/`flutter run` select the right JDK
  automatically, but a targeted `./gradlew` invocation outside of Flutter's
  tooling picks up whatever `java` resolves to on `PATH` — on this machine that's
  JDK 25, which fails. Export `JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`
  before running `./gradlew` directly.
- **Core library desugaring is required for `flutter_local_notifications`**:
  `android/app/build.gradle.kts` sets `isCoreLibraryDesugaringEnabled = true`
  and adds `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`.
  Without both, `:app:checkDebugAarMetadata` fails with "requires core library
  desugaring to be enabled". Do not remove either when touching that file.
- **Riverpod 3 API differences from Riverpod 2 examples found online**:
  `AsyncValue.valueOrNull` does not exist in this version — use `.value` instead.
  A `StreamProvider` also stays paused (its stream is never subscribed) until it
  has a listener; a test that does `await container.read(someStreamProvider.future)`
  without first attaching a listener will hang forever. Call
  `container.listen(someStreamProvider, (_, _) {})` before awaiting `.future`.
- **Release signing**: `android/app/build.gradle.kts` reads `android/key.properties`
  (gitignored, never committed) if present and signs release builds with it;
  otherwise it falls back to debug signing so `flutter build apk --release` still
  works on a machine without the keystore. Copy `android/key.properties.example`
  to `android/key.properties` and fill in real values to build a signed release
  locally. CI writes `android/key.properties` from secrets at build time (see
  `android-release.yml`).
