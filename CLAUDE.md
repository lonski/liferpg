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

`<web client id>` is the OAuth **web** client id from the Firebase console (Authentication → Sign-in method → Google → Web SDK configuration), not the Android client id. Every `flutter run`/`flutter build` invocation needs it or Google sign-in fails to initialize.

## Project Structure

`lib/` holds `main.dart` (Firebase init + auth gate), `theme/` (palette,
ornaments), `models/`, `data/` (repositories plus the `firebaseAuthProvider` /
`firestoreProvider` test seams), `providers/` (Riverpod), and `features/`
(login, home, character, users). Tests mirror that tree under `test/`.
Firestore rules have their own emulator-based test suite in `tools/rules-test/`.

## Firestore Data Model

**`users/{uid}`**
```
uid, name, email, authProvider, admin (bool), readOnlyOthers (bool)
```

**`characters/{id}`**
```
name, clazz, email, level, current_xp, next_level_xp, gold, gold_usd, favour
traits: [{ name: string, value: string }]  (optional)
```

- Characters are linked to users via `email`.
- Admin users see **all** characters and can edit any; `readOnlyOthers` users see all characters but cannot edit any; regular users see only their own.
- **This split is enforced server-side in `firestore.rules`, not just by the client query.** `/characters` reads require `isAdmin() || isReadOnlyOthers() || resource.data.email == request.auth.token.email`; writes require `isAdmin()`. A regular user's unconstrained collection query is therefore *rejected* by Firestore — the client must keep issuing `where('email', isEqualTo: <own email>)` (see `lib/data/character_repository.dart`), otherwise the home screen breaks with PERMISSION_DENIED.
- **Case-sensitivity caveat (measured, not theoretical):** Firestore string comparison is case-sensitive. A character document whose `email` differs in case from the owner's Google auth email (e.g. `Ala@Example.com` vs `ala@example.com`) is **denied** to that owner — a direct `get` fails and their own-email query returns zero documents, so the character is invisible to them. Admins and `readOnlyOthers` users still see it. The rule deliberately does **not** lowercase-normalise; the data must be cleaned instead.

## Key Behaviors

- **Auth**: auth state is driven by `firebaseAuthProvider`; unauthenticated users are routed to the login screen.
- **Admin**: `user.admin === true` unlocks the edit button on each character card and shows all characters.
- **ReadOnlyOthers**: `user.readOnlyOthers === true` allows viewing all characters but cannot edit any. Both roles are resolved in the rules by a `get()` on the caller's own `users/{uid}` document, so every signed-in user needs that document to exist.
- **Favour**: integer; rendered as mood emoji (< -1 = very unhappy, -1 = unhappy, 0 = neutral, > 0 = happy).
- **Currency**: `gold` = PLN (złoty), `gold_usd` = USD. Both displayed as chips if present.
- **XP badge**: tapping the XP progress bar toggles a chip showing XP remaining to next level.

## UI Language

The UI is in **Polish**. Labels (Poziom, Złoto, XP, Przychylność, etc.) are verbatim from the retired React app and must never be translated. Four label styles render uppercase via `.toUpperCase()` at the point of use while the Dart string literals themselves stay in normal casing — don't "fix" the casing in the literals.

## Conventions

- Never touch `FirebaseAuth.instance` or `FirebaseFirestore.instance` outside
  `lib/data/firebase_providers.dart` — tests override those two providers. The one
  exception is `main()`, which sets Firestore persistence before any `ProviderScope`
  exists and therefore cannot route through a provider.
- Colours are `const Color(0xAARRGGBB)` literals with alpha baked in.
- Firestore field names stay snake_case (`current_xp`, `next_level_xp`,
  `gold_usd`); Dart-side names are camelCase and mapped in the models.
- `google-services.json`, `firebase_options.dart` and `android/key.properties`
  are gitignored; CI restores them from secrets.

## CI/CD

- `.github/workflows/android-pr.yml` — analyze, test, debug APK as an artifact.
- `.github/workflows/android-release.yml` — signed release APK to Firebase
  App Distribution on push to `master`.

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
