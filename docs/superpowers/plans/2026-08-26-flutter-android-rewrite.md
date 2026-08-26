# LifeRPG Flutter/Android Rewrite Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the React web app with a Flutter application that builds to a native Android package, backed by the same Firebase project.

**Architecture:** Riverpod providers sit on top of a thin repository layer that wraps `FirebaseAuth` and `FirebaseFirestore`. Character and user lists are live Firestore snapshot streams with on-device offline persistence, so no manual cache invalidation exists. The UI keeps the existing parchment/heraldic identity but replaces both modal dialogs with pushed full-screen routes.

**Tech Stack:** Flutter (stable), Dart, `firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`, `flutter_riverpod`; tests with `flutter_test`, `fake_cloud_firestore`, `firebase_auth_mocks`; Firestore rules tested with `@firebase/rules-unit-testing` against the Firebase emulator.

**Spec:** `docs/superpowers/specs/2026-08-26-flutter-android-rewrite-design.md`

## Global Constraints

- Firebase project is `liferpg-f3bab`. Do not create a new project; do not change the Firestore data model.
- Android application id and namespace: `com.liferpg.app`. `minSdk 23`.
- Dart package name: `liferpg`.
- Flutter stable channel, Dart SDK constraint `>=3.4.0 <4.0.0`.
- All user-facing copy is Polish and is copied verbatim from the React source. Never translate: `Poziom`, `Złoto`, `Dolary`, `Doświadczenie`, `Przychylność`, `Cechy`, `Karta Postaci`, `Edycja Postaci`, `Kronika Bohaterów`, `Zaloguj przez Google`, `Wejdź do Kroniki`, `Wyloguj`, `Zarządzaj użytkownikami`, `Do następnego poziomu`, `Zapisz`.
- Colours are declared as `const Color(0xAARRGGBB)` literals. Never use `Color.withOpacity` (deprecated) or `withValues` (too new); bake alpha into the literal.
- Firestore field names stay snake_case exactly as stored: `current_xp`, `next_level_xp`, `gold_usd`, `readOnlyOthers`, `clazz`, `authProvider`.
- `android/app/google-services.json` is gitignored and never committed.
- Every task ends with a commit. Run `flutter analyze` before each commit; it must be clean.

---

### Task 1: Scaffold the Flutter project and wire up Firebase

**Files:**
- Create: `pubspec.yaml`, `lib/main.dart`, `lib/firebase_options.dart`, `android/` tree, `analysis_options.yaml`
- Modify: `.gitignore`
- Test: `test/smoke_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `DefaultFirebaseOptions.currentPlatform` (from `lib/firebase_options.dart`); `LifeRpgApp` — a `StatelessWidget` in `lib/main.dart`, later replaced in Task 8.

- [ ] **Step 1: Scaffold the project into the repo root**

The repo already contains `src/`, `docs/`, `firebase.json` and friends. `flutter create` adds to the directory without deleting them, but it **overwrites `.gitignore`** — save a copy first.

```bash
cp .gitignore /tmp/gitignore.react
flutter create . --org com.liferpg --project-name liferpg --platforms android
```

- [ ] **Step 2: Restore the merged .gitignore**

Flutter's generated `.gitignore` replaced the React one. Re-add the entries the React build still needs (it lives until Task 12) plus the Firebase secrets:

```bash
cat /tmp/gitignore.react >> .gitignore
cat >> .gitignore <<'EOF'

# Firebase (never commit)
android/app/google-services.json
lib/firebase_options.dart
EOF
sort -u .gitignore -o .gitignore
```

`lib/firebase_options.dart` is gitignored because it is generated per-machine by `flutterfire configure`; CI regenerates it from a secret. Task 12's workflows depend on this.

- [ ] **Step 3: Rename the Android package to com.liferpg.app**

`flutter create` produced `com.liferpg.liferpg`. Fix the namespace, the application id, and the Kotlin source path:

```bash
sed -i 's/com\.liferpg\.liferpg/com.liferpg.app/g' android/app/build.gradle.kts
mkdir -p android/app/src/main/kotlin/com/liferpg/app
mv android/app/src/main/kotlin/com/liferpg/liferpg/MainActivity.kt \
   android/app/src/main/kotlin/com/liferpg/app/MainActivity.kt
rmdir android/app/src/main/kotlin/com/liferpg/liferpg
sed -i 's/^package .*/package com.liferpg.app/' android/app/src/main/kotlin/com/liferpg/app/MainActivity.kt
```

Then set the SDK floor in `android/app/build.gradle.kts` — inside `defaultConfig`, replace the generated `minSdk = flutter.minSdkVersion` line with:

```kotlin
        minSdk = 23
```

- [ ] **Step 4: Verify the rename took**

```bash
grep -rn "com.liferpg" android/app/build.gradle.kts android/app/src/main/kotlin/com/liferpg/app/MainActivity.kt
```
Expected: every hit reads `com.liferpg.app`, with no occurrence of `com.liferpg.liferpg`.

- [ ] **Step 5: Add dependencies**

```bash
flutter pub add firebase_core firebase_auth cloud_firestore google_sign_in flutter_riverpod
flutter pub add --dev fake_cloud_firestore firebase_auth_mocks
```

- [ ] **Step 6: Register the Android app in Firebase and generate options**

This step is manual and cannot be scripted; it needs a human with console access.

1. Firebase console → project `liferpg-f3bab` → Add app → Android → package name `com.liferpg.app`.
2. Add the **debug** SHA-1 and SHA-256 fingerprints:
   ```bash
   keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | grep -E 'SHA1|SHA256'
   ```
   Release fingerprints are added in Task 12, once the release keystore exists.
3. Download `google-services.json` to `android/app/google-services.json`.
4. Copy the **Web client ID** from Authentication → Sign-in method → Google → Web SDK configuration. Google Sign-In needs it to mint an ID token Firebase will accept. Save it; every `flutter run` and `flutter build` from here on passes it as `--dart-define=GOOGLE_SERVER_CLIENT_ID=<that value>`.
5. Generate the options file:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=liferpg-f3bab --platforms=android --yes
   ```

- [ ] **Step 7: Write the failing smoke test**

Create `test/smoke_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/main.dart';

void main() {
  testWidgets('LifeRpgApp builds a MaterialApp', (tester) async {
    await tester.pumpWidget(const LifeRpgApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
```

- [ ] **Step 8: Run it and watch it fail**

```bash
rm -f test/widget_test.dart
flutter test test/smoke_test.dart
```
Expected: FAIL — `LifeRpgApp` is not defined in `main.dart`, which still holds the generated counter app. (`test/widget_test.dart` is deleted because it tests that counter app.)

- [ ] **Step 9: Write main.dart**

Replace the entire contents of `lib/main.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const ProviderScope(child: LifeRpgApp()));
}

class LifeRpgApp extends StatelessWidget {
  const LifeRpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'LifeRPG',
      home: Scaffold(body: SizedBox.shrink()),
    );
  }
}
```

`persistenceEnabled: true` is the offline cache the spec calls for. It is the Android default, but stating it makes the dependency explicit and survives a future change of default.

- [ ] **Step 10: Run the test and watch it pass**

```bash
flutter test test/smoke_test.dart
flutter analyze
```
Expected: 1 test passes; analyze reports no issues.

- [ ] **Step 11: Verify it runs on a device**

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
```
Expected: a blank dark screen and no Firebase initialisation crash in the logs. A crash here means `google-services.json` is missing or carries the wrong package name.

- [ ] **Step 12: Commit**

```bash
git add -A
git commit -m "feat: scaffold Flutter Android project with Firebase wiring"
```

---

### Task 2: Allow first-login user-document creation in Firestore rules

The React app writes `users/{uid}` on first sign-in, but the current rules allow writes to that collection only for admins — so the write is rejected for every new user. This task fixes the rule before any client depends on it.

**Files:**
- Modify: `firestore.rules`
- Create: `tools/rules-test/package.json`, `tools/rules-test/rules.test.mjs`

**Interfaces:**
- Consumes: nothing.
- Produces: the rule contract Task 5's `AuthRepository.ensureUserDocument` relies on — a user may create `users/{uid}` for their own uid only, and only with `admin == false` and `readOnlyOthers == false`.

- [ ] **Step 1: Write the failing rules test**

Create `tools/rules-test/package.json`:

```json
{
  "name": "liferpg-rules-test",
  "private": true,
  "type": "module",
  "scripts": {
    "test": "node --test rules.test.mjs"
  },
  "devDependencies": {
    "@firebase/rules-unit-testing": "^3.0.4",
    "firebase": "^12.11.0"
  }
}
```

Create `tools/rules-test/rules.test.mjs`:

```javascript
import { test, before, after } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'liferpg-rules-test',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

test('a user may create their own doc with both flags false', async () => {
  const db = env.authenticatedContext('alice').firestore();
  await assertSucceeds(
    setDoc(doc(db, 'users/alice'), {
      uid: 'alice',
      name: 'Alice',
      email: 'alice@example.com',
      authProvider: 'google',
      admin: false,
      readOnlyOthers: false,
    })
  );
});

test('a user may not create their own doc as admin', async () => {
  const db = env.authenticatedContext('mallory').firestore();
  await assertFails(
    setDoc(doc(db, 'users/mallory'), {
      uid: 'mallory',
      email: 'm@example.com',
      admin: true,
      readOnlyOthers: false,
    })
  );
});

test('a user may not create a doc belonging to somebody else', async () => {
  const db = env.authenticatedContext('mallory').firestore();
  await assertFails(
    setDoc(doc(db, 'users/victim'), {
      uid: 'victim',
      email: 'v@example.com',
      admin: false,
      readOnlyOthers: false,
    })
  );
});

test('a user may not raise their own privileges after creation', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/alice'), {
      uid: 'alice',
      email: 'alice@example.com',
      admin: false,
      readOnlyOthers: false,
    });
  });
  const db = env.authenticatedContext('alice').firestore();
  await assertFails(setDoc(doc(db, 'users/alice'), { admin: true }, { merge: true }));
});

test('a user may still read their own doc', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users/bob'), { uid: 'bob', admin: false });
  });
  const db = env.authenticatedContext('bob').firestore();
  await assertSucceeds(getDoc(doc(db, 'users/bob')));
});
```

- [ ] **Step 2: Run the tests and watch one fail**

```bash
(cd tools/rules-test && npm install)
firebase emulators:exec --only firestore --project liferpg-rules-test "npm --prefix tools/rules-test test"
```
Expected: the "may create their own doc" test FAILS with a permission-denied assertion — the current rules allow no such write. The escalation and read tests already pass.

- [ ] **Step 3: Add the create rule**

In `firestore.rules`, replace the `match /users/{uid}` block with:

```
    match /users/{uid} {
      allow read: if isOwnUser(uid) || isAdmin();
      allow create: if isOwnUser(uid)
                    && request.resource.data.admin == false
                    && request.resource.data.readOnlyOthers == false;
      allow update, delete: if isAdmin();
    }
```

Leave `isAuthenticated`, `isAdmin`, `isOwnUser` and the `characters` block untouched.

- [ ] **Step 4: Run the tests and watch them all pass**

```bash
firebase emulators:exec --only firestore --project liferpg-rules-test "npm --prefix tools/rules-test test"
```
Expected: 5 tests pass.

- [ ] **Step 5: Deploy the rules**

```bash
firebase deploy --only firestore:rules --project liferpg-f3bab
```

- [ ] **Step 6: Commit**

```bash
echo "tools/rules-test/node_modules/" >> .gitignore
git add firestore.rules tools/rules-test .gitignore
git commit -m "fix: allow users to create their own user document on first login"
```

---

### Task 3: Theme and shared ornaments

**Files:**
- Create: `lib/theme/app_theme.dart`, `lib/theme/ornaments.dart`, `assets/fonts/` (5 font files)
- Modify: `pubspec.yaml`
- Test: `test/theme/ornaments_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `lib/theme/app_theme.dart`: `const Color crimsonDeep, crimson, crimsonBright, gold, parchment, parchmentLight, parchmentDim, inkDark, bgDark, crimsonFaint, crimsonBorder, ornamentInk, goldBorder, goldBorderFaint, parchmentMuted, parchmentFaint`; `const LinearGradient bandGradient, appBarGradient, xpGradient, buttonGradient`; `const RadialGradient cardGradient`; `const String fontDisplay, fontBody`; `ThemeData buildAppTheme()`.
  - `lib/theme/ornaments.dart`: `class OrnamentDivider extends StatelessWidget` (`const OrnamentDivider({Color color = crimson, double width = 120})`); `class CornerOrnament extends StatelessWidget` (`const CornerOrnament({bool mirrored = false})`); `class TopBand extends StatelessWidget` (`const TopBand({required String label, Widget? trailing})`); `class BottomBand extends StatelessWidget` (`const BottomBand()`).

- [ ] **Step 1: Add the fonts**

```bash
mkdir -p assets/fonts
base=https://raw.githubusercontent.com/google/fonts/main
curl -fsSL -o assets/fonts/Cinzel-Regular.ttf            $base/ofl/cinzel/static/Cinzel-Regular.ttf
curl -fsSL -o assets/fonts/Cinzel-Bold.ttf               $base/ofl/cinzel/static/Cinzel-Bold.ttf
curl -fsSL -o assets/fonts/LibreBaskerville-Regular.ttf  $base/ofl/librebaskerville/LibreBaskerville-Regular.ttf
curl -fsSL -o assets/fonts/LibreBaskerville-Bold.ttf     $base/ofl/librebaskerville/LibreBaskerville-Bold.ttf
curl -fsSL -o assets/fonts/LibreBaskerville-Italic.ttf   $base/ofl/librebaskerville/LibreBaskerville-Italic.ttf
ls -l assets/fonts
```
Expected: five files, each larger than 20 kB. If a URL 404s, download the family from fonts.google.com by hand and place the static TTFs at these exact paths — the names are referenced from `pubspec.yaml`.

- [ ] **Step 2: Declare the fonts in pubspec.yaml**

Under `flutter:` in `pubspec.yaml`, add:

```yaml
  fonts:
    - family: Cinzel
      fonts:
        - asset: assets/fonts/Cinzel-Regular.ttf
        - asset: assets/fonts/Cinzel-Bold.ttf
          weight: 700
    - family: LibreBaskerville
      fonts:
        - asset: assets/fonts/LibreBaskerville-Regular.ttf
        - asset: assets/fonts/LibreBaskerville-Bold.ttf
          weight: 700
        - asset: assets/fonts/LibreBaskerville-Italic.ttf
          style: italic
```

- [ ] **Step 3: Write the failing ornaments test**

Create `test/theme/ornaments_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/theme/ornaments.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('OrnamentDivider renders the diamond glyph', (tester) async {
    await tester.pumpWidget(wrap(const OrnamentDivider()));
    expect(find.text('✦'), findsOneWidget);
  });

  testWidgets('CornerOrnament mirrors horizontally when asked', (tester) async {
    await tester.pumpWidget(wrap(const CornerOrnament(mirrored: true)));
    expect(find.text('❧'), findsOneWidget);
    expect(find.byType(Transform), findsOneWidget);
  });

  testWidgets('TopBand shows its label and trailing widget', (tester) async {
    await tester.pumpWidget(wrap(const TopBand(
      label: '✦ Karta Postaci ✦',
      trailing: Icon(Icons.edit),
    )));
    expect(find.text('✦ Karta Postaci ✦'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });

  testWidgets('BottomBand renders its rule', (tester) async {
    await tester.pumpWidget(wrap(const BottomBand()));
    expect(find.text('— ✦ —'), findsOneWidget);
  });
}
```

- [ ] **Step 4: Run it and watch it fail**

```bash
flutter test test/theme/ornaments_test.dart
```
Expected: FAIL — `package:liferpg/theme/ornaments.dart` does not exist.

- [ ] **Step 5: Write the theme**

Create `lib/theme/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

// Palette, ported verbatim from the React theme.js and the CSS modules.
const Color crimsonDeep = Color(0xFF3A0A0A);
const Color crimson = Color(0xFF6B1A1A);
const Color crimsonBright = Color(0xFF7A1414);
const Color gold = Color(0xFFC8860A);
const Color parchment = Color(0xFFE0CCAA);
const Color parchmentLight = Color(0xFFF5E8D0);
const Color parchmentDim = Color(0xFFC8B080);
const Color inkDark = Color(0xFF1A0A0A);
const Color bgDark = Color(0xFF1A1008);

// Alpha baked into the literal; see Global Constraints.
const Color crimsonFaint = Color(0x1F6B1A1A);    // 12%
const Color crimsonBorder = Color(0x596B1A1A);   // 35%
const Color ornamentInk = Color(0x8C6B1A1A);     // 55%
const Color goldBorder = Color(0x66C8860A);      // 40%
const Color goldBorderFaint = Color(0x4DC8860A); // 30%
const Color parchmentMuted = Color(0x99F5E8D0);  // 60%
const Color parchmentFaint = Color(0x73F5E8D0);  // 45%

const LinearGradient bandGradient = LinearGradient(
  colors: [crimsonDeep, crimsonBright, crimsonDeep],
);

const LinearGradient appBarGradient = LinearGradient(
  colors: [Color(0xFF280606), Color(0xFF4A0E0E), Color(0xFF280606)],
);

const LinearGradient xpGradient = LinearGradient(colors: [crimson, gold]);

const LinearGradient buttonGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [crimsonDeep, crimson],
);

const RadialGradient cardGradient = RadialGradient(
  center: Alignment(0, -1),
  radius: 1.2,
  colors: [parchmentLight, parchment, parchmentDim],
  stops: [0.0, 0.6, 1.0],
);

const String fontDisplay = 'Cinzel';
const String fontBody = 'LibreBaskerville';

ThemeData buildAppTheme() {
  final base = ThemeData(brightness: Brightness.light, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: bgDark,
    colorScheme: base.colorScheme.copyWith(
      primary: crimsonBright,
      onPrimary: parchmentLight,
      surface: parchment,
      onSurface: inkDark,
    ),
    textTheme: base.textTheme
        .apply(fontFamily: fontBody, bodyColor: inkDark, displayColor: inkDark)
        .copyWith(
          displayLarge: const TextStyle(fontFamily: fontDisplay),
          displayMedium: const TextStyle(fontFamily: fontDisplay),
          headlineLarge: const TextStyle(fontFamily: fontDisplay),
          headlineMedium: const TextStyle(fontFamily: fontDisplay),
          headlineSmall: const TextStyle(fontFamily: fontDisplay),
          titleLarge: const TextStyle(fontFamily: fontDisplay),
        ),
    inputDecorationTheme: const InputDecorationTheme(
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: crimsonBorder),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: crimsonBright),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: crimsonDeep,
      contentTextStyle: TextStyle(fontFamily: fontBody, color: parchmentLight),
    ),
  );
}
```

- [ ] **Step 6: Write the ornaments**

Create `lib/theme/ornaments.dart`:

```dart
import 'package:flutter/material.dart';

import 'app_theme.dart';

/// A horizontal rule broken by a ✦, fading out towards the ends.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key, this.color = crimson, this.width = 120});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget line(bool leftToRight) => Container(
          width: width / 2,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: leftToRight
                  ? [const Color(0x00000000), color]
                  : [color, const Color(0x00000000)],
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('✦', style: TextStyle(fontSize: 10, color: color)),
        ),
        line(false),
      ],
    );
  }
}

/// The ❧ leaf that sits in the corners of a framed card.
class CornerOrnament extends StatelessWidget {
  const CornerOrnament({super.key, this.mirrored = false});

  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    const glyph = Text(
      '❧',
      style: TextStyle(fontSize: 12, color: ornamentInk, height: 1),
    );
    // Always wrapped, so the widget tree has the same shape either way.
    return Transform.scale(scaleX: mirrored ? -1 : 1, child: glyph);
  }
}

/// The crimson band across the top of a card, with an optional trailing action.
class TopBand extends StatelessWidget {
  const TopBand({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: bandGradient),
      padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontSize: 8,
                letterSpacing: 4,
                color: Color(0xD9F5E8D0),
              ),
            ),
          ),
          SizedBox(width: 32, child: trailing),
        ],
      ),
    );
  }
}

/// The closing rule at the foot of a card.
class BottomBand extends StatelessWidget {
  const BottomBand({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: bandGradient),
      padding: const EdgeInsets.symmetric(vertical: 5),
      alignment: Alignment.center,
      child: const Text(
        '— ✦ —',
        style: TextStyle(fontSize: 9, color: parchmentMuted, height: 1),
      ),
    );
  }
}
```

- [ ] **Step 7: Run the tests and watch them pass**

```bash
flutter test test/theme/ornaments_test.dart
flutter analyze
```
Expected: 4 tests pass; analyze clean.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml assets/fonts lib/theme test/theme
git commit -m "feat: add parchment theme and shared ornament widgets"
```

---

### Task 4: Models and the favour feature flag

**Files:**
- Create: `lib/models/app_user.dart`, `lib/models/character.dart`, `lib/feature_flags.dart`
- Test: `test/models/app_user_test.dart`, `test/models/character_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `AppUser({required String uid, required String name, required String email, required bool admin, required bool readOnlyOthers})`; `factory AppUser.fromMap(String uid, Map<String, dynamic> data)`; getters `bool get canSeeAllCharacters`, `bool get canEdit`.
  - `Trait({required String name, required String value})`; `factory Trait.fromMap(Map<String, dynamic>)`; `Map<String, dynamic> toMap()`.
  - `Character({required String id, required String name, String? clazz, required String email, int? level, required int currentXp, required int nextLevelXp, num? gold, num? goldUsd, required int favour, required List<Trait> traits})`; `factory Character.fromMap(String id, Map<String, dynamic>)`; `Map<String, dynamic> toMap()`; `Character copyWith({...})`; getters `double get xpFraction` (0.0–1.0), `int get xpRemaining`.
  - `const bool kShowFavour` from `lib/feature_flags.dart`.

- [ ] **Step 1: Write the failing AppUser test**

Create `test/models/app_user_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/app_user.dart';

void main() {
  test('fromMap reads flags and defaults them to false', () {
    final user = AppUser.fromMap('u1', {
      'name': 'Ala',
      'email': 'ala@example.com',
      'admin': true,
    });
    expect(user.uid, 'u1');
    expect(user.name, 'Ala');
    expect(user.email, 'ala@example.com');
    expect(user.admin, isTrue);
    expect(user.readOnlyOthers, isFalse);
  });

  test('admins and readOnlyOthers users both see all characters', () {
    AppUser make({bool admin = false, bool ro = false}) => AppUser(
          uid: 'u',
          name: 'n',
          email: 'e',
          admin: admin,
          readOnlyOthers: ro,
        );
    expect(make().canSeeAllCharacters, isFalse);
    expect(make(admin: true).canSeeAllCharacters, isTrue);
    expect(make(ro: true).canSeeAllCharacters, isTrue);
  });

  test('only admins may edit', () {
    const readOnly = AppUser(
        uid: 'u', name: 'n', email: 'e', admin: false, readOnlyOthers: true);
    const admin = AppUser(
        uid: 'u', name: 'n', email: 'e', admin: true, readOnlyOthers: false);
    expect(readOnly.canEdit, isFalse);
    expect(admin.canEdit, isTrue);
  });
}
```

- [ ] **Step 2: Write the failing Character test**

Create `test/models/character_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/character.dart';

Map<String, dynamic> raw() => {
      'name': 'Grommash',
      'clazz': 'Wojownik',
      'email': 'g@example.com',
      'level': 3,
      'current_xp': 40,
      'next_level_xp': 100,
      'gold': 250,
      'gold_usd': 12,
      'favour': -2,
      'traits': [
        {'name': 'Siła', 'value': '18'},
      ],
    };

void main() {
  test('fromMap reads the snake_case Firestore fields', () {
    final c = Character.fromMap('abc', raw());
    expect(c.id, 'abc');
    expect(c.clazz, 'Wojownik');
    expect(c.currentXp, 40);
    expect(c.nextLevelXp, 100);
    expect(c.goldUsd, 12);
    expect(c.favour, -2);
    expect(c.traits.single.name, 'Siła');
  });

  test('missing optional fields fall back safely', () {
    final c = Character.fromMap('abc', {'name': 'X', 'email': 'x@example.com'});
    expect(c.level, isNull);
    expect(c.gold, isNull);
    expect(c.favour, 0);
    expect(c.traits, isEmpty);
    expect(c.xpFraction, 0.0);
  });

  test('xpFraction is clamped to 1.0 and never divides by zero', () {
    expect(Character.fromMap('a', raw()).xpFraction, closeTo(0.4, 1e-9));
    final over = Character.fromMap('a', {...raw(), 'current_xp': 500});
    expect(over.xpFraction, 1.0);
    final zero = Character.fromMap('a', {...raw(), 'next_level_xp': 0});
    expect(zero.xpFraction, 0.0);
  });

  test('xpRemaining is the gap to the next level', () {
    expect(Character.fromMap('a', raw()).xpRemaining, 60);
  });

  test('toMap round-trips through fromMap', () {
    final c = Character.fromMap('abc', raw());
    final back = Character.fromMap('abc', c.toMap());
    expect(back.name, c.name);
    expect(back.currentXp, c.currentXp);
    expect(back.traits.single.value, '18');
  });

  test('copyWith replaces only what it is given', () {
    final c = Character.fromMap('abc', raw());
    final bumped = c.copyWith(level: 4, favour: 1);
    expect(bumped.level, 4);
    expect(bumped.favour, 1);
    expect(bumped.name, 'Grommash');
  });
}
```

- [ ] **Step 3: Run them and watch them fail**

```bash
flutter test test/models
```
Expected: FAIL — neither model file exists.

- [ ] **Step 4: Write AppUser**

Create `lib/models/app_user.dart`:

```dart
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.admin,
    required this.readOnlyOthers,
  });

  final String uid;
  final String name;
  final String email;
  final bool admin;
  final bool readOnlyOthers;

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) => AppUser(
        uid: uid,
        name: data['name'] as String? ?? '',
        email: data['email'] as String? ?? '',
        admin: data['admin'] as bool? ?? false,
        readOnlyOthers: data['readOnlyOthers'] as bool? ?? false,
      );

  /// Admins and readOnlyOthers users see the whole roster; everyone else sees
  /// only the characters carrying their own email.
  bool get canSeeAllCharacters => admin || readOnlyOthers;

  /// Editing is admin-only. readOnlyOthers deliberately does not grant it.
  bool get canEdit => admin;
}
```

- [ ] **Step 5: Write Character and Trait**

Create `lib/models/character.dart`:

```dart
class Trait {
  const Trait({required this.name, required this.value});

  final String name;
  final String value;

  factory Trait.fromMap(Map<String, dynamic> data) => Trait(
        name: data['name'] as String? ?? '',
        value: data['value'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'name': name, 'value': value};
}

class Character {
  const Character({
    required this.id,
    required this.name,
    this.clazz,
    required this.email,
    this.level,
    required this.currentXp,
    required this.nextLevelXp,
    this.gold,
    this.goldUsd,
    required this.favour,
    required this.traits,
  });

  final String id;
  final String name;
  final String? clazz;
  final String email;
  final int? level;
  final int currentXp;
  final int nextLevelXp;
  final num? gold;
  final num? goldUsd;
  final int favour;
  final List<Trait> traits;

  factory Character.fromMap(String id, Map<String, dynamic> data) => Character(
        id: id,
        name: data['name'] as String? ?? '',
        clazz: data['clazz'] as String?,
        email: data['email'] as String? ?? '',
        level: (data['level'] as num?)?.toInt(),
        currentXp: (data['current_xp'] as num?)?.toInt() ?? 0,
        nextLevelXp: (data['next_level_xp'] as num?)?.toInt() ?? 0,
        gold: data['gold'] as num?,
        goldUsd: data['gold_usd'] as num?,
        favour: (data['favour'] as num?)?.toInt() ?? 0,
        traits: ((data['traits'] as List<dynamic>?) ?? const [])
            .map((t) => Trait.fromMap(Map<String, dynamic>.from(t as Map)))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'clazz': clazz,
        'email': email,
        'level': level,
        'current_xp': currentXp,
        'next_level_xp': nextLevelXp,
        'gold': gold,
        'gold_usd': goldUsd,
        'favour': favour,
        'traits': traits.map((t) => t.toMap()).toList(),
      };

  Character copyWith({
    String? name,
    String? clazz,
    int? level,
    int? currentXp,
    int? nextLevelXp,
    num? gold,
    num? goldUsd,
    int? favour,
    List<Trait>? traits,
  }) =>
      Character(
        id: id,
        name: name ?? this.name,
        clazz: clazz ?? this.clazz,
        email: email,
        level: level ?? this.level,
        currentXp: currentXp ?? this.currentXp,
        nextLevelXp: nextLevelXp ?? this.nextLevelXp,
        gold: gold ?? this.gold,
        goldUsd: goldUsd ?? this.goldUsd,
        favour: favour ?? this.favour,
        traits: traits ?? this.traits,
      );

  /// Progress towards the next level, 0.0–1.0, for the XP bar.
  double get xpFraction {
    if (level == null || nextLevelXp <= 0) return 0.0;
    final f = currentXp / nextLevelXp;
    if (f > 1.0) return 1.0;
    if (f < 0.0) return 0.0;
    return f;
  }

  int get xpRemaining => nextLevelXp - currentXp;
}
```

- [ ] **Step 6: Write the feature flag**

Create `lib/feature_flags.dart`:

```dart
/// Mirrors the web app's VITE_SHOW_FAVOUR flag.
/// Enable with: flutter build apk --dart-define=SHOW_FAVOUR=true
const bool kShowFavour = bool.fromEnvironment('SHOW_FAVOUR');
```

- [ ] **Step 7: Run the tests and watch them pass**

```bash
flutter test test/models
flutter analyze
```
Expected: 9 tests pass; analyze clean.

- [ ] **Step 8: Commit**

```bash
git add lib/models lib/feature_flags.dart test/models
git commit -m "feat: add Character and AppUser models and the favour feature flag"
```

---

### Task 5: Firebase seams, auth repository, auth providers

**Files:**
- Create: `lib/data/firebase_providers.dart`, `lib/data/auth_repository.dart`, `lib/providers/auth_providers.dart`
- Test: `test/data/auth_repository_test.dart`, `test/providers/auth_providers_test.dart`

**Interfaces:**
- Consumes: `AppUser` (Task 4); the `users/{uid}` create rule (Task 2).
- Produces:
  - `firebaseAuthProvider` → `Provider<FirebaseAuth>`; `firestoreProvider` → `Provider<FirebaseFirestore>`. These two are the seam every test overrides.
  - `AuthRepository(FirebaseAuth auth, FirebaseFirestore db)` with `Stream<User?> authStateChanges()`, `Future<void> signInWithGoogle()`, `Future<void> signOut()`, `Future<void> ensureUserDocument(User user)`.
  - `authRepositoryProvider` → `Provider<AuthRepository>`; `authStateProvider` → `StreamProvider<User?>`; `appUserProvider` → `StreamProvider<AppUser?>`.

- [ ] **Step 1: Write the failing repository test**

Create `test/data/auth_repository_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/auth_repository.dart';

void main() {
  test('ensureUserDocument creates a doc with both flags false', () async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'ala@example.com', displayName: 'Ala'),
    );
    final repo = AuthRepository(auth, db);

    await repo.ensureUserDocument(auth.currentUser!);

    final snap = await db.collection('users').doc('u1').get();
    expect(snap.exists, isTrue);
    expect(snap.data()!['email'], 'ala@example.com');
    expect(snap.data()!['name'], 'Ala');
    expect(snap.data()!['authProvider'], 'google');
    expect(snap.data()!['admin'], isFalse);
    expect(snap.data()!['readOnlyOthers'], isFalse);
  });

  test('ensureUserDocument never overwrites an existing doc', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1',
      'email': 'ala@example.com',
      'admin': true,
      'readOnlyOthers': false,
    });
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
    );

    await AuthRepository(auth, db).ensureUserDocument(auth.currentUser!);

    final snap = await db.collection('users').doc('u1').get();
    expect(snap.data()!['admin'], isTrue, reason: 'admin must survive re-login');
  });

  test('signOut clears the current user', () async {
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
    await AuthRepository(auth, FakeFirebaseFirestore()).signOut();
    expect(auth.currentUser, isNull);
  });
}
```

The second test is the one that matters: the bootstrap runs on every sign-in and must never reset an admin's own privileges.

- [ ] **Step 2: Run it and watch it fail**

```bash
flutter test test/data/auth_repository_test.dart
```
Expected: FAIL — `package:liferpg/data/auth_repository.dart` does not exist.

- [ ] **Step 3: Write the Firebase seams**

Create `lib/data/firebase_providers.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The single seam through which tests swap in fakes. Nothing else in the app
/// may reach for FirebaseAuth.instance or FirebaseFirestore.instance directly.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);
```

- [ ] **Step 4: Write the auth repository**

Create `lib/data/auth_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The OAuth 2.0 *web* client id from the Firebase console
/// (Authentication → Sign-in method → Google → Web SDK configuration).
/// Google Sign-In needs it to mint an ID token that Firebase will accept.
const String kGoogleServerClientId =
    String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signInWithGoogle() async {
    await GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId);
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Google nie zwrócił tokenu tożsamości.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user != null) await ensureUserDocument(user);
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  /// Creates users/{uid} on first login. Both privilege flags are written as
  /// false; the Firestore rules reject any other value on create, and only an
  /// admin may change them afterwards.
  Future<void> ensureUserDocument(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'uid': user.uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'authProvider': 'google',
      'admin': false,
      'readOnlyOthers': false,
    });
  }
}
```

If `flutter pub add` resolved `google_sign_in` to 6.x rather than 7.x the API differs — 6.x uses `GoogleSignIn(serverClientId: ...).signIn()` returning a nullable account, with `authentication` as a `Future`. Pin `google_sign_in: ^7.0.0` in `pubspec.yaml` and re-run `flutter pub get` rather than rewriting against the older API.

- [ ] **Step 5: Run the repository test and watch it pass**

```bash
flutter test test/data/auth_repository_test.dart
```
Expected: 3 tests pass. `signInWithGoogle` is not unit-tested — it drives a platform channel — and is verified on a device in Task 8.

- [ ] **Step 6: Write the failing auth-providers test**

Create `test/providers/auth_providers_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/models/app_user.dart';
import 'package:liferpg/providers/auth_providers.dart';

void main() {
  test('appUserProvider is null when nobody is signed in', () async {
    final container = ProviderContainer(overrides: [
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    ]);
    addTearDown(container.dispose);

    final user = await container.read(appUserProvider.future);
    expect(user, isNull);
  });

  test('appUserProvider streams the signed-in user document', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1',
      'name': 'Ala',
      'email': 'ala@example.com',
      'admin': true,
      'readOnlyOthers': false,
    });
    final container = ProviderContainer(overrides: [
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
      firestoreProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);

    final user = await container.read(appUserProvider.future);
    expect(user, isA<AppUser>());
    expect(user!.admin, isTrue);
    expect(user.email, 'ala@example.com');
  });
}
```

- [ ] **Step 7: Run it and watch it fail**

```bash
flutter test test/providers/auth_providers_test.dart
```
Expected: FAIL — `package:liferpg/providers/auth_providers.dart` does not exist.

- [ ] **Step 8: Write the auth providers**

Create `lib/providers/auth_providers.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../data/firebase_providers.dart';
import '../models/app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      ref.watch(firebaseAuthProvider),
      ref.watch(firestoreProvider),
    ));

final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// The Firestore users/{uid} document for whoever is signed in, as a live
/// stream: an admin flipping somebody's flags takes effect without a relaunch.
final appUserProvider = StreamProvider<AppUser?>((ref) {
  final authUser = ref.watch(authStateProvider).valueOrNull;
  if (authUser == null) return Stream<AppUser?>.value(null);
  return ref
      .watch(firestoreProvider)
      .collection('users')
      .doc(authUser.uid)
      .snapshots()
      .map((doc) => doc.exists ? AppUser.fromMap(doc.id, doc.data()!) : null);
});
```

- [ ] **Step 9: Run the tests and watch them pass**

```bash
flutter test test/data test/providers
flutter analyze
```
Expected: 5 tests pass; analyze clean.

- [ ] **Step 10: Commit**

```bash
git add lib/data lib/providers test/data test/providers
git commit -m "feat: add Firebase seams, auth repository and auth providers"
```

---

### Task 6: Character repository and providers

**Files:**
- Create: `lib/data/character_repository.dart`, `lib/providers/character_providers.dart`
- Test: `test/providers/character_providers_test.dart`

**Interfaces:**
- Consumes: `firestoreProvider`, `appUserProvider` (Task 5), `Character`/`Trait`/`AppUser` (Task 4).
- Produces:
  - `CharacterFeed({required List<Character> characters, required bool isFromCache, required bool hasPendingWrites})` with `bool get isOffline`.
  - `CharacterRepository(FirebaseFirestore db)` with `Stream<CharacterFeed> watchCharacters(AppUser user)` and `Future<void> updateCharacter(Character character)`.
  - `characterRepositoryProvider` → `Provider<CharacterRepository>`; `charactersProvider` → `StreamProvider<CharacterFeed>`; `traitNamesProvider` → `Provider<List<String>>` (distinct trait names across the loaded roster, for the edit screen's autocomplete).

- [ ] **Step 1: Write the failing test**

Create `test/providers/character_providers_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/character_repository.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/providers/character_providers.dart';

Future<FakeFirebaseFirestore> seed() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': false,
    'readOnlyOthers': false,
  });
  await db.collection('characters').add({
    'name': 'Ala',
    'email': 'ala@example.com',
    'level': 2,
    'current_xp': 10,
    'next_level_xp': 100,
    'favour': 0,
    'traits': [
      {'name': 'Siła', 'value': '10'},
    ],
  });
  await db.collection('characters').add({
    'name': 'Bob',
    'email': 'bob@example.com',
    'level': 5,
    'current_xp': 0,
    'next_level_xp': 200,
    'favour': 1,
    'traits': [
      {'name': 'Spryt', 'value': '14'},
    ],
  });
  return db;
}

ProviderContainer containerFor(FakeFirebaseFirestore db) {
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
    )),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a plain user sees only their own characters', () async {
    final db = await seed();
    final feed = await containerFor(db).read(charactersProvider.future);
    expect(feed.characters.map((c) => c.name), ['Ala']);
  });

  test('an admin sees every character', () async {
    final db = await seed();
    await db.collection('users').doc('u1').update({'admin': true});
    final feed = await containerFor(db).read(charactersProvider.future);
    expect(feed.characters.map((c) => c.name).toSet(), {'Ala', 'Bob'});
  });

  test('a readOnlyOthers user sees every character', () async {
    final db = await seed();
    await db.collection('users').doc('u1').update({'readOnlyOthers': true});
    final feed = await containerFor(db).read(charactersProvider.future);
    expect(feed.characters.map((c) => c.name).toSet(), {'Ala', 'Bob'});
  });

  test('traitNamesProvider collects distinct names across the roster', () async {
    final db = await seed();
    await db.collection('users').doc('u1').update({'admin': true});
    final container = containerFor(db);
    await container.read(charactersProvider.future);
    expect(container.read(traitNamesProvider).toSet(), {'Siła', 'Spryt'});
  });

  test('updateCharacter writes the snake_case fields back', () async {
    final db = await seed();
    final ref = await db.collection('characters').add({
      'name': 'Cyla',
      'email': 'c@example.com',
      'level': 1,
      'current_xp': 0,
      'next_level_xp': 50,
      'favour': 0,
      'traits': <dynamic>[],
    });
    final snap = await ref.get();
    final updated = Character.fromMap(ref.id, snap.data()!)
        .copyWith(level: 2, currentXp: 25, favour: -1);

    await CharacterRepository(db).updateCharacter(updated);

    final after = await ref.get();
    expect(after.data()!['level'], 2);
    expect(after.data()!['current_xp'], 25);
    expect(after.data()!['favour'], -1);
  });

  test('CharacterFeed reports offline when cached or pending', () {
    CharacterFeed feed({bool cache = false, bool pending = false}) => CharacterFeed(
          characters: const [],
          isFromCache: cache,
          hasPendingWrites: pending,
        );
    expect(feed().isOffline, isFalse);
    expect(feed(cache: true).isOffline, isTrue);
    expect(feed(pending: true).isOffline, isTrue);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
flutter test test/providers/character_providers_test.dart
```
Expected: FAIL — `character_repository.dart` and `character_providers.dart` do not exist.

- [ ] **Step 3: Write the repository**

Create `lib/data/character_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/character.dart';

/// A snapshot of the roster plus the sync metadata the AppBar needs in order
/// to say whether what you are looking at came off the device or the server.
class CharacterFeed {
  const CharacterFeed({
    required this.characters,
    required this.isFromCache,
    required this.hasPendingWrites,
  });

  final List<Character> characters;
  final bool isFromCache;
  final bool hasPendingWrites;

  bool get isOffline => isFromCache || hasPendingWrites;
}

class CharacterRepository {
  CharacterRepository(this._db);

  final FirebaseFirestore _db;

  /// Admins and readOnlyOthers users watch the whole collection; everyone else
  /// watches only the characters carrying their own email.
  Stream<CharacterFeed> watchCharacters(AppUser user) {
    final collection = _db.collection('characters');
    final Query<Map<String, dynamic>> query = user.canSeeAllCharacters
        ? collection
        : collection.where('email', isEqualTo: user.email);

    return query.snapshots(includeMetadataChanges: true).map(
          (snap) => CharacterFeed(
            characters:
                snap.docs.map((d) => Character.fromMap(d.id, d.data())).toList(),
            isFromCache: snap.metadata.isFromCache,
            hasPendingWrites: snap.metadata.hasPendingWrites,
          ),
        );
  }

  Future<void> updateCharacter(Character character) =>
      _db.collection('characters').doc(character.id).update(character.toMap());
}
```

- [ ] **Step 4: Write the providers**

Create `lib/providers/character_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/character_repository.dart';
import '../data/firebase_providers.dart';
import 'auth_providers.dart';

final characterRepositoryProvider = Provider<CharacterRepository>(
  (ref) => CharacterRepository(ref.watch(firestoreProvider)),
);

final charactersProvider = StreamProvider<CharacterFeed>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) {
    return Stream.value(const CharacterFeed(
      characters: [],
      isFromCache: false,
      hasPendingWrites: false,
    ));
  }
  return ref.watch(characterRepositoryProvider).watchCharacters(user);
});

/// Distinct trait names already in use across the loaded roster. The edit
/// screen offers these as autocomplete suggestions, mirroring the web app's
/// existingTraitNames memo.
final traitNamesProvider = Provider<List<String>>((ref) {
  final feed = ref.watch(charactersProvider).valueOrNull;
  if (feed == null) return const [];
  final names = <String>{
    for (final c in feed.characters)
      for (final t in c.traits) t.name,
  };
  return names.toList()..sort();
});
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
flutter test test/providers/character_providers_test.dart
flutter analyze
```
Expected: 6 tests pass; analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/data/character_repository.dart lib/providers/character_providers.dart test/providers/character_providers_test.dart
git commit -m "feat: add character repository and live character providers"
```

---

### Task 7: User repository and providers

**Files:**
- Create: `lib/data/user_repository.dart`, `lib/providers/user_providers.dart`
- Test: `test/providers/user_providers_test.dart`

**Interfaces:**
- Consumes: `firestoreProvider`, `appUserProvider` (Task 5), `AppUser` (Task 4).
- Produces:
  - `UserRepository(FirebaseFirestore db)` with `Stream<List<AppUser>> watchUsers()` and `Future<void> updateUserFlags(String uid, Map<String, Object?> flags)`.
  - `userRepositoryProvider` → `Provider<UserRepository>`; `usersProvider` → `StreamProvider<List<AppUser>>` (empty for non-admins).

- [ ] **Step 1: Write the failing test**

Create `test/providers/user_providers_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/user_repository.dart';
import 'package:liferpg/providers/user_providers.dart';

Future<FakeFirebaseFirestore> seed({required bool admin}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': admin,
    'readOnlyOthers': false,
  });
  await db.collection('users').doc('u2').set({
    'uid': 'u2',
    'name': 'Bob',
    'email': 'bob@example.com',
    'admin': false,
    'readOnlyOthers': false,
  });
  return db;
}

ProviderContainer containerFor(FakeFirebaseFirestore db) {
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
    )),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('usersProvider lists everyone for an admin', () async {
    final users = await containerFor(await seed(admin: true)).read(usersProvider.future);
    expect(users.map((u) => u.uid).toSet(), {'u1', 'u2'});
  });

  test('usersProvider is empty for a non-admin', () async {
    final users = await containerFor(await seed(admin: false)).read(usersProvider.future);
    expect(users, isEmpty);
  });

  test('updateUserFlags writes only the given flags', () async {
    final db = await seed(admin: true);
    await UserRepository(db).updateUserFlags('u2', {'readOnlyOthers': true});
    final snap = await db.collection('users').doc('u2').get();
    expect(snap.data()!['readOnlyOthers'], isTrue);
    expect(snap.data()!['name'], 'Bob', reason: 'other fields must survive');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
flutter test test/providers/user_providers_test.dart
```
Expected: FAIL — `user_repository.dart` and `user_providers.dart` do not exist.

- [ ] **Step 3: Write the repository**

Create `lib/data/user_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class UserRepository {
  UserRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<AppUser>> watchUsers() => _db
      .collection('users')
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());

  Future<void> updateUserFlags(String uid, Map<String, Object?> flags) =>
      _db.collection('users').doc(uid).update(flags);
}
```

- [ ] **Step 4: Write the providers**

Create `lib/providers/user_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_providers.dart';
import '../data/user_repository.dart';
import '../models/app_user.dart';
import 'auth_providers.dart';

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(firestoreProvider)),
);

/// Non-admins get an empty list rather than a permission error: the Firestore
/// rules would reject the collection read anyway.
final usersProvider = StreamProvider<List<AppUser>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null || !user.admin) return Stream.value(const <AppUser>[]);
  return ref.watch(userRepositoryProvider).watchUsers();
});
```

- [ ] **Step 5: Run the tests and watch them pass**

```bash
flutter test test/providers/user_providers_test.dart
flutter analyze
```
Expected: 3 tests pass; analyze clean.

- [ ] **Step 6: Commit**

```bash
git add lib/data/user_repository.dart lib/providers/user_providers.dart test/providers/user_providers_test.dart
git commit -m "feat: add user repository and admin-only user providers"
```

---

### Task 8: Login screen and the auth gate

**Files:**
- Create: `lib/features/login/login_screen.dart`, `lib/features/home/home_screen.dart` (placeholder), `lib/features/users/user_management_screen.dart` (placeholder)
- Modify: `lib/main.dart`, `test/smoke_test.dart`
- Test: `test/features/login_screen_test.dart`

**Interfaces:**
- Consumes: `authStateProvider`, `authRepositoryProvider` (Task 5); theme and ornaments (Task 3).
- Produces: `class LoginScreen extends ConsumerStatefulWidget` (`const LoginScreen()`); `class AuthGate extends ConsumerWidget` in `lib/main.dart`; `LifeRpgApp` now applies `buildAppTheme()` and hosts `AuthGate`.

- [ ] **Step 1: Write the failing login test**

Create `test/features/login_screen_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/login/login_screen.dart';

void main() {
  testWidgets('shows the chronicle branding and the Polish sign-in copy',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ));

    expect(find.text('LifeRPG'), findsOneWidget);
    expect(find.text('Kronika Bohaterów'), findsOneWidget);
    expect(find.text('Zaloguj przez Google'), findsOneWidget);
    expect(find.text('Wejdź do Kroniki'), findsOneWidget);
    expect(find.text('„Twoja legenda czeka...”'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
flutter test test/features/login_screen_test.dart
```
Expected: FAIL — `login_screen.dart` does not exist.

- [ ] **Step 3: Write the login screen**

Create `lib/features/login/login_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logowanie nieudane: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚔', style: TextStyle(fontSize: 40, color: gold)),
              const SizedBox(height: 12),
              const Text(
                'LifeRPG',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                  color: parchmentLight,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kronika Bohaterów',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 2,
                  color: parchmentFaint,
                ),
              ),
              const SizedBox(height: 20),
              const OrnamentDivider(color: gold, width: 160),
              const SizedBox(height: 32),
              _SignInButton(busy: _busy, onPressed: _busy ? null : _signIn),
              const SizedBox(height: 28),
              const Text(
                '„Twoja legenda czeka...”',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: parchmentFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            gradient: buttonGradient,
            border: Border.all(color: goldBorder),
            borderRadius: BorderRadius.circular(3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: gold),
                )
              else
                const Text(
                  'G',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: gold,
                  ),
                ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zaloguj przez Google',
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 13,
                      letterSpacing: 1,
                      color: parchmentLight,
                    ),
                  ),
                  Text(
                    'Wejdź do Kroniki',
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: parchmentMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create the placeholder screens the auth gate needs**

`HomeScreen` is built in Task 9 and `UserManagementScreen` in Task 11; both are replaced wholesale then. Stub them so `main.dart` compiles:

```bash
mkdir -p lib/features/home lib/features/users
cat > lib/features/home/home_screen.dart <<'EOF'
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('LifeRPG')));
}
EOF
cat > lib/features/users/user_management_screen.dart <<'EOF'
import 'package:flutter/material.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar());
}
EOF
```

- [ ] **Step 5: Wire the auth gate into main.dart**

Add these imports to `lib/main.dart`:

```dart
import 'features/home/home_screen.dart';
import 'features/login/login_screen.dart';
import 'providers/auth_providers.dart';
import 'theme/app_theme.dart';
```

Then replace the `LifeRpgApp` class (leave `main()` untouched) with:

```dart
class LifeRpgApp extends StatelessWidget {
  const LifeRpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeRPG',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}

/// Chooses the root screen from auth state. This replaces the imperative
/// navigate("/login") the React useAuth hook performed.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(authStateProvider).when(
          data: (user) => user == null ? const LoginScreen() : const HomeScreen(),
          loading: () => const Scaffold(
            backgroundColor: bgDark,
            body: Center(child: CircularProgressIndicator(color: gold)),
          ),
          error: (error, _) => Scaffold(
            backgroundColor: bgDark,
            body: Center(
              child: Text(
                'Błąd logowania: $error',
                style: const TextStyle(color: parchmentLight),
              ),
            ),
          ),
        );
  }
}
```

- [ ] **Step 6: Update the smoke test for the ProviderScope requirement**

`LifeRpgApp` now reads providers, so it must be pumped inside a scope. Replace `test/smoke_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/login/login_screen.dart';
import 'package:liferpg/main.dart';

void main() {
  testWidgets('signed-out users land on the login screen', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
      child: const LifeRpgApp(),
    ));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
```

- [ ] **Step 7: Run the tests and watch them pass**

```bash
flutter test
flutter analyze
```
Expected: every suite passes; analyze clean.

- [ ] **Step 8: Verify real Google sign-in on a device**

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
```
Expected: tapping the button opens the native Google account picker; choosing an account lands on the placeholder home screen. Check the Firestore console — `users/{your-uid}` now exists with `admin: false`, `readOnlyOthers: false`. A `PlatformException` with code 10 means the SHA-1 fingerprint is not registered; a missing ID token means the server client id is wrong.

- [ ] **Step 9: Commit**

```bash
git add lib/main.dart lib/features test/features test/smoke_test.dart
git commit -m "feat: add login screen and auth-gated app shell"
```

---

### Task 9: Home screen and character card

**Files:**
- Create: `lib/features/character/character_card.dart`, `lib/features/character/edit_character_screen.dart` (placeholder)
- Modify: `lib/features/home/home_screen.dart` (replaces the Task 8 placeholder)
- Test: `test/features/character_card_test.dart`, `test/features/home_screen_test.dart`

**Interfaces:**
- Consumes: `charactersProvider`, `CharacterFeed` (Task 6), `appUserProvider`, `authRepositoryProvider` (Task 5), `Character`/`Trait` (Task 4), `kShowFavour` (Task 4), theme and ornaments (Task 3).
- Produces: `class CharacterCard extends StatefulWidget` (`const CharacterCard({required Character character, required bool canEdit})`); `class HomeScreen extends ConsumerWidget` (`const HomeScreen()`).

- [ ] **Step 1: Write the failing character-card test**

Create `test/features/character_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/character/character_card.dart';
import 'package:liferpg/models/character.dart';

Character sample({List<Trait> traits = const []}) => Character(
      id: 'c1',
      name: 'Grommash',
      clazz: 'Wojownik',
      email: 'g@example.com',
      level: 3,
      currentXp: 40,
      nextLevelXp: 100,
      gold: 250,
      goldUsd: 12,
      favour: 0,
      traits: traits,
    );

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('renders name, class, level, XP and gold in both currencies',
      (tester) async {
    await tester.pumpWidget(
      wrap(CharacterCard(character: sample(), canEdit: false)),
    );

    expect(find.text('Grommash'), findsOneWidget);
    expect(find.text('Wojownik'), findsOneWidget);
    expect(find.text('Poziom'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('250 zł'), findsOneWidget);
    expect(find.text('12 \$'), findsOneWidget);
    expect(find.text('40 / 100 XP'), findsOneWidget);
  });

  testWidgets('tapping the XP bar toggles the remaining-XP hint',
      (tester) async {
    await tester.pumpWidget(
      wrap(CharacterCard(character: sample(), canEdit: false)),
    );

    expect(find.textContaining('Do następnego poziomu'), findsNothing);

    await tester.tap(find.byKey(const Key('xp-bar')));
    await tester.pumpAndSettle();
    expect(find.text('Do następnego poziomu: 60 XP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('xp-bar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Do następnego poziomu'), findsNothing);
  });

  testWidgets('renders traits under a Cechy heading', (tester) async {
    await tester.pumpWidget(wrap(CharacterCard(
      character: sample(traits: const [Trait(name: 'Siła', value: '18')]),
      canEdit: false,
    )));

    expect(find.text('Cechy'), findsOneWidget);
    expect(find.text('Siła'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
  });

  testWidgets('the edit affordance appears only when canEdit', (tester) async {
    await tester.pumpWidget(
      wrap(CharacterCard(character: sample(), canEdit: false)),
    );
    expect(find.byKey(const Key('edit-character')), findsNothing);

    await tester.pumpWidget(
      wrap(CharacterCard(character: sample(), canEdit: true)),
    );
    expect(find.byKey(const Key('edit-character')), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
flutter test test/features/character_card_test.dart
```
Expected: FAIL — `character_card.dart` does not exist.

- [ ] **Step 3: Create the edit-screen placeholder**

Task 10 replaces this file entirely; the constructor signature there is identical, so `CharacterCard` will not need changing.

```bash
mkdir -p lib/features/character
cat > lib/features/character/edit_character_screen.dart <<'EOF'
import 'package:flutter/material.dart';

import '../../models/character.dart';

class EditCharacterScreen extends StatelessWidget {
  const EditCharacterScreen({super.key, required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(), body: Center(child: Text(character.name)));
}
EOF
```

- [ ] **Step 4: Write the character card**

Create `lib/features/character/character_card.dart`:

```dart
import 'package:flutter/material.dart';

import '../../feature_flags.dart';
import '../../models/character.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import 'edit_character_screen.dart';

const TextStyle kStatLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 9,
  letterSpacing: 2,
  color: crimson,
);

const Color _inkHeading = Color(0xFF2D0A0A);

class CharacterCard extends StatefulWidget {
  const CharacterCard({
    super.key,
    required this.character,
    required this.canEdit,
  });

  final Character character;
  final bool canEdit;

  @override
  State<CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<CharacterCard> {
  bool _hintVisible = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.character;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: crimson, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Color(0xB3000000), blurRadius: 32, offset: Offset(0, 8)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TopBand(
            label: '✦ Karta Postaci ✦',
            trailing: widget.canEdit
                ? IconButton(
                    key: const Key('edit-character'),
                    tooltip: 'Edytuj postać',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 16,
                    color: parchmentMuted,
                    icon: const Icon(Icons.edit),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EditCharacterScreen(character: c),
                      ),
                    ),
                  )
                : null,
          ),
          Container(
            decoration: const BoxDecoration(gradient: cardGradient),
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: crimsonBorder),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NameBlock(character: c),
                      const SizedBox(height: 10),
                      const OrnamentDivider(),
                      const SizedBox(height: 10),
                      if (c.level != null) ...[
                        _LevelRow(level: c.level!),
                        const SizedBox(height: 10),
                        _XpSection(
                          character: c,
                          hintVisible: _hintVisible,
                          onToggle: () =>
                              setState(() => _hintVisible = !_hintVisible),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (c.gold != null) _GoldRow(character: c),
                      if (kShowFavour) ...[
                        const SizedBox(height: 8),
                        Text(
                          favourEmoji(c.favour),
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                      if (c.traits.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        const _TraitsHeading(),
                        const SizedBox(height: 8),
                        _TraitPills(traits: c.traits),
                      ],
                    ],
                  ),
                ),
                const Positioned(top: 5, left: 5, child: CornerOrnament()),
                const Positioned(
                  top: 5,
                  right: 5,
                  child: CornerOrnament(mirrored: true),
                ),
              ],
            ),
          ),
          const BottomBand(),
        ],
      ),
    );
  }
}

/// Mood glyph, matching the React FavourEmoji thresholds exactly.
String favourEmoji(int favour) {
  if (favour < -1) return '😠';
  if (favour == -1) return '😕';
  if (favour > 0) return '😊';
  return '😐';
}

class _NameBlock extends StatelessWidget {
  const _NameBlock({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(
            character.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: fontDisplay,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: _inkHeading,
            ),
          ),
          if (character.clazz != null)
            Text(
              character.clazz!,
              style: const TextStyle(
                fontFamily: fontBody,
                fontSize: 10,
                fontStyle: FontStyle.italic,
                letterSpacing: 1,
                color: crimson,
              ),
            ),
        ],
      );
}

class _LevelRow extends StatelessWidget {
  const _LevelRow({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Poziom', style: kStatLabel),
          Container(
            decoration: BoxDecoration(
              gradient: bandGradient,
              border: Border.all(color: goldBorder),
              borderRadius: BorderRadius.circular(3),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Text(
              '$level',
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: parchmentLight,
              ),
            ),
          ),
        ],
      );
}

class _XpSection extends StatelessWidget {
  const _XpSection({
    required this.character,
    required this.hintVisible,
    required this.onToggle,
  });

  final Character character;
  final bool hintVisible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Doświadczenie', style: kStatLabel),
              Text(
                '${character.currentXp} / ${character.nextLevelXp} XP',
                style: const TextStyle(
                  fontFamily: fontBody,
                  fontSize: 10,
                  color: crimson,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          GestureDetector(
            key: const Key('xp-bar'),
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: crimsonFaint,
                border: Border.all(color: crimsonBorder),
                borderRadius: BorderRadius.circular(2),
              ),
              clipBehavior: Clip.antiAlias,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: character.xpFraction,
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: xpGradient),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 150),
            child: hintVisible
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Do następnego poziomu: ${character.xpRemaining} XP',
                      style: const TextStyle(
                        fontFamily: fontBody,
                        fontSize: 10,
                        color: crimson,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      );
}

class _GoldRow extends StatelessWidget {
  const _GoldRow({required this.character});

  static const TextStyle _goldValue = TextStyle(
    fontFamily: fontBody,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Color(0xFF8A5A06),
  );

  final Character character;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Złoto', style: kStatLabel),
          Row(
            children: [
              Text('${character.gold} zł', style: _goldValue),
              if (character.goldUsd != null) ...[
                const Text(' · ', style: TextStyle(color: crimson)),
                Text('${character.goldUsd} \$', style: _goldValue),
              ],
            ],
          ),
        ],
      );
}

class _TraitsHeading extends StatelessWidget {
  const _TraitsHeading();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(child: Divider(color: crimsonBorder, height: 1)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('Cechy', style: kStatLabel),
          ),
          Expanded(child: Divider(color: crimsonBorder, height: 1)),
        ],
      );
}

class _TraitPills extends StatelessWidget {
  const _TraitPills({required this.traits});

  final List<Trait> traits;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final t in traits)
            Container(
              decoration: BoxDecoration(
                color: crimsonFaint,
                border: Border.all(color: crimsonBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.name,
                    style: const TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 9,
                      letterSpacing: 1,
                      color: crimson,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    t.value,
                    style: const TextStyle(
                      fontFamily: fontBody,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _inkHeading,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
}
```

- [ ] **Step 5: Run the card test and watch it pass**

```bash
flutter test test/features/character_card_test.dart
```
Expected: 4 tests pass.

- [ ] **Step 6: Write the failing home-screen test**

Create `test/features/home_screen_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/character/character_card.dart';
import 'package:liferpg/features/home/home_screen.dart';

Future<FakeFirebaseFirestore> seed({bool admin = false}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': admin,
    'readOnlyOthers': false,
  });
  await db.collection('characters').add({
    'name': 'Grommash',
    'email': 'ala@example.com',
    'level': 3,
    'current_xp': 40,
    'next_level_xp': 100,
    'favour': 0,
    'traits': <dynamic>[],
  });
  return db;
}

Future<void> pumpHome(WidgetTester tester, FakeFirebaseFirestore db) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
    ],
    child: const MaterialApp(home: HomeScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the characters the user may see', (tester) async {
    await pumpHome(tester, await seed());
    expect(find.byType(CharacterCard), findsOneWidget);
    expect(find.text('Grommash'), findsOneWidget);
  });

  testWidgets('shows the admin action only for admins', (tester) async {
    await pumpHome(tester, await seed());
    expect(find.byKey(const Key('open-user-management')), findsNothing);

    await pumpHome(tester, await seed(admin: true));
    expect(find.byKey(const Key('open-user-management')), findsOneWidget);
  });

  testWidgets('always offers logout', (tester) async {
    await pumpHome(tester, await seed());
    expect(find.byKey(const Key('logout')), findsOneWidget);
  });
}
```

- [ ] **Step 7: Run it and watch it fail**

```bash
flutter test test/features/home_screen_test.dart
```
Expected: FAIL — the Task 8 placeholder `HomeScreen` renders no `CharacterCard`.

- [ ] **Step 8: Write the home screen**

Replace `lib/features/home/home_screen.dart` entirely:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';
import '../character/character_card.dart';
import '../users/user_management_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final feed = ref.watch(charactersProvider);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: appBarGradient,
            border: Border(bottom: BorderSide(color: goldBorderFaint)),
          ),
        ),
        title: const Text(
          '⚔  LifeRPG',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 3,
            color: parchmentLight,
          ),
        ),
        actions: [
          if (feed.valueOrNull?.isOffline ?? false)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Dane z pamięci urządzenia',
                child: Icon(Icons.cloud_off, size: 16, color: parchmentFaint),
              ),
            ),
          if (user?.admin ?? false)
            IconButton(
              key: const Key('open-user-management'),
              tooltip: 'Zarządzaj użytkownikami',
              iconSize: 18,
              color: parchmentMuted,
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UserManagementScreen(),
                ),
              ),
            ),
          IconButton(
            key: const Key('logout'),
            tooltip: 'Wyloguj',
            iconSize: 18,
            color: parchmentMuted,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator(color: gold)),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nie udało się wczytać postaci: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: parchmentLight),
            ),
          ),
        ),
        data: (data) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final c in data.characters)
                  CharacterCard(character: c, canEdit: user?.canEdit ?? false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 9: Run the whole suite and watch it pass**

```bash
flutter test
flutter analyze
```
Expected: all suites pass; analyze clean.

- [ ] **Step 10: Commit**

```bash
git add lib/features test/features
git commit -m "feat: add home screen and character card"
```

---

### Task 10: Edit character screen

**Files:**
- Modify: `lib/features/character/edit_character_screen.dart` (replaces the Task 9 placeholder)
- Test: `test/features/edit_character_screen_test.dart`

**Interfaces:**
- Consumes: `characterRepositoryProvider`, `traitNamesProvider` (Task 6), `Character`/`Trait` (Task 4), `kShowFavour` (Task 4), theme and ornaments (Task 3).
- Produces: `class EditCharacterScreen extends ConsumerStatefulWidget` (`const EditCharacterScreen({required Character character})`) — the same constructor as the placeholder, so `CharacterCard` needs no change.

- [ ] **Step 1: Write the failing test**

Create `test/features/edit_character_screen_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/character/edit_character_screen.dart';
import 'package:liferpg/models/character.dart';

Future<(FakeFirebaseFirestore, Character)> seed() async {
  final db = FakeFirebaseFirestore();
  final ref = await db.collection('characters').add({
    'name': 'Grommash',
    'email': 'g@example.com',
    'level': 3,
    'current_xp': 40,
    'next_level_xp': 100,
    'gold': 250,
    'gold_usd': 12,
    'favour': 0,
    'traits': [
      {'name': 'Siła', 'value': '18'},
    ],
  });
  final snap = await ref.get();
  return (db, Character.fromMap(ref.id, snap.data()!));
}

Future<void> pumpEdit(
  WidgetTester tester,
  FakeFirebaseFirestore db,
  Character character,
) async {
  // Both seams must be overridden: the screen reads traitNamesProvider, which
  // reaches back through charactersProvider to appUserProvider and auth.
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'admin@example.com'),
      )),
    ],
    child: MaterialApp(home: EditCharacterScreen(character: character)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fields are populated from the character', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    expect(find.text('Grommash'), findsWidgets);
    expect(find.widgetWithText(TextFormField, '3'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '250'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '40'), findsOneWidget);
    expect(find.text('Siła'), findsOneWidget);
  });

  testWidgets('saving writes the edited values to Firestore', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    await tester.enterText(find.byKey(const Key('field-level')), '7');
    await tester.enterText(find.byKey(const Key('field-current_xp')), '55');
    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    final snap = await db.collection('characters').doc(character.id).get();
    expect(snap.data()!['level'], 7);
    expect(snap.data()!['current_xp'], 55);
  });

  testWidgets('a trait can be removed and a new one added', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    await tester.tap(find.byKey(const Key('remove-trait-0')));
    await tester.pumpAndSettle();
    expect(find.text('Siła'), findsNothing);

    await tester.enterText(find.byKey(const Key('new-trait-name')), 'Spryt');
    await tester.enterText(find.byKey(const Key('new-trait-value')), '14');
    await tester.tap(find.byKey(const Key('add-trait')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    final snap = await db.collection('characters').doc(character.id).get();
    final traits = (snap.data()!['traits'] as List<dynamic>)
        .map((t) => Map<String, dynamic>.from(t as Map))
        .toList();
    expect(traits, hasLength(1));
    expect(traits.single['name'], 'Spryt');
    expect(traits.single['value'], '14');
  });

  testWidgets('a non-numeric level blocks the save', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    await tester.enterText(find.byKey(const Key('field-level')), 'abc');
    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    expect(find.text('Podaj liczbę'), findsOneWidget);
    final snap = await db.collection('characters').doc(character.id).get();
    expect(snap.data()!['level'], 3, reason: 'nothing may be written');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
flutter test test/features/edit_character_screen_test.dart
```
Expected: FAIL — the placeholder screen has no fields and no save key.

- [ ] **Step 3: Write the edit screen**

Replace `lib/features/character/edit_character_screen.dart` entirely:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../feature_flags.dart';
import '../../models/character.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

const TextStyle _fieldLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 9,
  letterSpacing: 2,
  color: crimson,
);

const Color _inkHeading = Color(0xFF2D0A0A);

String? _validateOptionalInt(String? value) {
  final text = (value ?? '').trim();
  if (text.isEmpty) return null;
  return int.tryParse(text) == null ? 'Podaj liczbę' : null;
}

Widget _numberField(String fieldKey, TextEditingController controller) =>
    TextFormField(
      key: Key('field-$fieldKey'),
      controller: controller,
      keyboardType: TextInputType.number,
      validator: _validateOptionalInt,
    );

class EditCharacterScreen extends ConsumerStatefulWidget {
  const EditCharacterScreen({super.key, required this.character});

  final Character character;

  @override
  ConsumerState<EditCharacterScreen> createState() =>
      _EditCharacterScreenState();
}

class _EditCharacterScreenState extends ConsumerState<EditCharacterScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late List<Trait> _traits;
  late int _favour;
  final _newTraitName = TextEditingController();
  final _newTraitValue = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = widget.character;
    _controllers = {
      'level': TextEditingController(text: c.level?.toString() ?? ''),
      'gold': TextEditingController(text: c.gold?.toString() ?? ''),
      'gold_usd': TextEditingController(text: c.goldUsd?.toString() ?? ''),
      'current_xp': TextEditingController(text: c.currentXp.toString()),
      'next_level_xp': TextEditingController(text: c.nextLevelXp.toString()),
    };
    _traits = List<Trait>.from(c.traits);
    _favour = c.favour;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _newTraitName.dispose();
    _newTraitValue.dispose();
    super.dispose();
  }

  int? _intOf(String key) => int.tryParse(_controllers[key]!.text.trim());

  void _addTrait() {
    final name = _newTraitName.text.trim();
    final value = _newTraitValue.text.trim();
    if (name.isEmpty || value.isEmpty) return;
    setState(() {
      _traits = [..._traits, Trait(name: name, value: value)];
      _newTraitName.clear();
      _newTraitValue.clear();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final updated = widget.character.copyWith(
        level: _intOf('level'),
        gold: _intOf('gold'),
        goldUsd: _intOf('gold_usd'),
        currentXp: _intOf('current_xp') ?? 0,
        nextLevelXp: _intOf('next_level_xp') ?? 0,
        favour: _favour,
        traits: _traits,
      );
      await ref.read(characterRepositoryProvider).updateCharacter(updated);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Zapis nieudany: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final traitNames = ref.watch(traitNamesProvider);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: parchmentMuted),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: appBarGradient,
            border: Border(bottom: BorderSide(color: goldBorderFaint)),
          ),
        ),
        title: const Text(
          'Edycja Postaci',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 14,
            letterSpacing: 3,
            color: parchmentLight,
          ),
        ),
        actions: [
          TextButton(
            key: const Key('save-character'),
            onPressed: _saving ? null : _save,
            child: Text(
              _saving ? '...' : 'Zapisz',
              style: const TextStyle(
                fontFamily: fontDisplay,
                letterSpacing: 2,
                color: gold,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: crimson, width: 2),
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    const TopBand(label: '✦ Edycja Postaci ✦'),
                    Container(
                      decoration: const BoxDecoration(gradient: cardGradient),
                      padding: const EdgeInsets.all(16),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: crimsonBorder),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Text(
                                  widget.character.name,
                                  style: const TextStyle(
                                    fontFamily: fontDisplay,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2,
                                    color: _inkHeading,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _LabelledField(
                                  label: 'Poziom',
                                  child: _numberField(
                                      'level', _controllers['level']!),
                                ),
                                _LabelledField(
                                  label: 'Złoto',
                                  child:
                                      _numberField('gold', _controllers['gold']!),
                                ),
                                _LabelledField(
                                  label: 'Dolary',
                                  child: _numberField(
                                      'gold_usd', _controllers['gold_usd']!),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('XP', style: _fieldLabel),
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 64,
                                          child: _numberField('current_xp',
                                              _controllers['current_xp']!),
                                        ),
                                        const Text(' / ',
                                            style: TextStyle(color: crimson)),
                                        SizedBox(
                                          width: 64,
                                          child: _numberField('next_level_xp',
                                              _controllers['next_level_xp']!),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (kShowFavour) _favourRow(),
                                const SizedBox(height: 12),
                                const OrnamentDivider(),
                                const SizedBox(height: 12),
                                _traitEditor(traitNames),
                              ],
                            ),
                          ),
                          const Positioned(
                              top: 5, left: 5, child: CornerOrnament()),
                          const Positioned(
                            top: 5,
                            right: 5,
                            child: CornerOrnament(mirrored: true),
                          ),
                        ],
                      ),
                    ),
                    const BottomBand(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _favourRow() => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Przychylność', style: _fieldLabel),
          Row(
            children: [
              IconButton(
                key: const Key('favour-down'),
                icon: const Text('👎'),
                onPressed: () => setState(() => _favour -= 1),
              ),
              Text(
                '$_favour',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _inkHeading,
                ),
              ),
              IconButton(
                key: const Key('favour-up'),
                icon: const Text('👍'),
                onPressed: () => setState(() => _favour += 1),
              ),
            ],
          ),
        ],
      );

  Widget _traitEditor(List<String> knownNames) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Cechy', style: _fieldLabel, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          for (var i = 0; i < _traits.length; i++)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _traits[i].name,
                    style: const TextStyle(fontFamily: fontBody, fontSize: 12),
                  ),
                ),
                Text(
                  _traits[i].value,
                  style: const TextStyle(
                    fontFamily: fontBody,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  key: Key('remove-trait-$i'),
                  iconSize: 18,
                  color: crimson,
                  icon: const Icon(Icons.delete),
                  onPressed: () =>
                      setState(() => _traits = [..._traits]..removeAt(i)),
                ),
              ],
            ),
          Row(
            children: [
              Expanded(
                child: Autocomplete<String>(
                  optionsBuilder: (value) => value.text.isEmpty
                      ? knownNames
                      : knownNames.where((n) =>
                          n.toLowerCase().contains(value.text.toLowerCase())),
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmitted) {
                    return TextField(
                      key: const Key('new-trait-name'),
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: (v) => _newTraitName.text = v,
                      onSubmitted: (_) => onSubmitted(),
                      decoration: const InputDecoration(labelText: 'Nazwa'),
                    );
                  },
                  onSelected: (v) => _newTraitName.text = v,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: TextField(
                  key: const Key('new-trait-value'),
                  controller: _newTraitValue,
                  decoration: const InputDecoration(labelText: 'Wartość'),
                ),
              ),
              IconButton(
                key: const Key('add-trait'),
                color: crimson,
                icon: const Icon(Icons.add),
                onPressed: _addTrait,
              ),
            ],
          ),
        ],
      );
}

class _LabelledField extends StatelessWidget {
  const _LabelledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: _fieldLabel),
          SizedBox(width: 64, child: child),
        ],
      );
}
```

The numeric fields deliberately use `TextInputType.number` without an input formatter, so the "Podaj liczbę" validation path stays reachable from a hardware keyboard and from tests; the validator is what actually blocks a bad save.

The trait-name `Autocomplete` keeps its own internal controller, so `_newTraitName` is kept in sync through `onChanged` and `onSelected` rather than by listening to it — adding a listener inside `fieldViewBuilder` would attach a fresh one on every rebuild.

- [ ] **Step 4: Run the tests and watch them pass**

```bash
flutter test test/features/edit_character_screen_test.dart
flutter analyze
```
Expected: 4 tests pass; analyze clean.

- [ ] **Step 5: Verify on a device as an admin**

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
```
Expected: the pencil in a card's top band opens the full-screen editor; changing a level and tapping Zapisz pops back, and the card shows the new value **without a manual refresh** — that is the live snapshot doing its job.

- [ ] **Step 6: Commit**

```bash
git add lib/features/character/edit_character_screen.dart test/features/edit_character_screen_test.dart
git commit -m "feat: add full-screen character editor"
```

---

### Task 11: User management screen

**Files:**
- Modify: `lib/features/users/user_management_screen.dart` (replaces the Task 8 placeholder)
- Test: `test/features/user_management_screen_test.dart`

**Interfaces:**
- Consumes: `usersProvider`, `userRepositoryProvider` (Task 7), `AppUser` (Task 4), theme (Task 3).
- Produces: `class UserManagementScreen extends ConsumerStatefulWidget` (`const UserManagementScreen()`) — the same constructor as the placeholder, so `HomeScreen` needs no change.

- [ ] **Step 1: Write the failing test**

Create `test/features/user_management_screen_test.dart`:

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/users/user_management_screen.dart';

Future<FakeFirebaseFirestore> seed() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': true,
    'readOnlyOthers': false,
  });
  await db.collection('users').doc('u2').set({
    'uid': 'u2',
    'name': 'Bob',
    'email': 'bob@example.com',
    'admin': false,
    'readOnlyOthers': false,
  });
  return db;
}

Future<void> pumpScreen(WidgetTester tester, FakeFirebaseFirestore db) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
    ],
    child: const MaterialApp(home: UserManagementScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every user with their email', (tester) async {
    await pumpScreen(tester, await seed());
    expect(find.text('Ala'), findsOneWidget);
    expect(find.text('bob@example.com'), findsOneWidget);
  });

  testWidgets('toggling the switch writes readOnlyOthers', (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(const Key('readonly-u2')));
    await tester.pumpAndSettle();

    final snap = await db.collection('users').doc('u2').get();
    expect(snap.data()!['readOnlyOthers'], isTrue);
  });

  testWidgets('the switch is disabled for admin rows', (tester) async {
    await pumpScreen(tester, await seed());
    final adminSwitch =
        tester.widget<Switch>(find.byKey(const Key('readonly-u1')));
    expect(adminSwitch.onChanged, isNull);
  });
}
```

The last test locks in the behaviour of commit `8b63c1c`: admins already see everything, so the flag is meaningless for them and must not be toggleable.

- [ ] **Step 2: Run it and watch it fail**

```bash
flutter test test/features/user_management_screen_test.dart
```
Expected: FAIL — the placeholder renders no users.

- [ ] **Step 3: Write the screen**

Replace `lib/features/users/user_management_screen.dart` entirely:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../providers/user_providers.dart';
import '../../theme/app_theme.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final Set<String> _pending = {};

  Future<void> _setReadOnly(AppUser user, bool value) async {
    setState(() => _pending.add(user.uid));
    try {
      await ref
          .read(userRepositoryProvider)
          .updateUserFlags(user.uid, {'readOnlyOthers': value});
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Zapis nieudany: $error')));
    } finally {
      if (mounted) setState(() => _pending.remove(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: parchmentMuted),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: appBarGradient,
            border: Border(bottom: BorderSide(color: goldBorderFaint)),
          ),
        ),
        title: const Text(
          'Użytkownicy',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 14,
            letterSpacing: 3,
            color: parchmentLight,
          ),
        ),
      ),
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator(color: gold)),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nie udało się wczytać użytkowników: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: parchmentLight),
            ),
          ),
        ),
        data: (list) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: goldBorderFaint, height: 1),
              itemBuilder: (context, i) {
                final user = list[i];
                final busy = _pending.contains(user.uid);
                return ListTile(
                  title: Text(
                    user.name.isEmpty ? user.email : user.name,
                    style: const TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 13,
                      color: parchmentLight,
                    ),
                  ),
                  subtitle: Text(
                    user.admin ? '${user.email} · admin' : user.email,
                    style: const TextStyle(
                      fontFamily: fontBody,
                      fontSize: 11,
                      color: parchmentFaint,
                    ),
                  ),
                  trailing: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: gold),
                        )
                      : Switch(
                          key: Key('readonly-${user.uid}'),
                          value: user.readOnlyOthers,
                          activeThumbColor: gold,
                          // Admins already see everything, so the flag is
                          // meaningless for them and stays locked.
                          onChanged:
                              user.admin ? null : (v) => _setReadOnly(user, v),
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

If `flutter analyze` reports `activeThumbColor` as undefined, the installed Flutter predates that rename — use `activeColor: gold` instead.

- [ ] **Step 4: Run the whole suite and watch it pass**

```bash
flutter test
flutter analyze
```
Expected: every suite passes; analyze clean.

- [ ] **Step 5: Commit**

```bash
git add lib/features/users/user_management_screen.dart test/features/user_management_screen_test.dart
git commit -m "feat: add admin user management screen"
```

---

### Task 12: Cut over — CI workflows, delete the React app, update docs

**Files:**
- Create: `.github/workflows/android-pr.yml`, `.github/workflows/android-release.yml`, `android/key.properties.example`
- Modify: `android/app/build.gradle.kts`, `firebase.json`, `CLAUDE.md`, `README.md`, `.gitignore`
- Delete: `.github/workflows/firebase-hosting-merge.yml`, `.github/workflows/firebase-hosting-pull-request.yml`, `src/`, `public/`, `index.html`, `vite.config.js`, `package.json`, `package-lock.json`, `tsconfig.json`, `.eslintrc.js`, `.eslintrc.json`, `.prettierrc`, `.env.example`

**Interfaces:**
- Consumes: everything above.
- Produces: nothing further depends on this task.

- [ ] **Step 1: Create the release keystore and register its fingerprints**

Manual, once, by a human:

```bash
keytool -genkey -v -keystore ~/liferpg-release.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias liferpg
keytool -list -v -keystore ~/liferpg-release.jks -alias liferpg | grep -E 'SHA1|SHA256'
base64 -w0 ~/liferpg-release.jks > ~/liferpg-release.jks.b64
```

Add the printed SHA-1 and SHA-256 to the Android app in the Firebase console, alongside the debug ones from Task 1. Without them Google sign-in fails in release builds only, which is a miserable bug to find late.

Then add these GitHub repository secrets: `GOOGLE_SERVICES_JSON` (contents of `android/app/google-services.json`), `GOOGLE_SERVER_CLIENT_ID`, `ANDROID_KEYSTORE_BASE64` (contents of the `.b64` file), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, and `FIREBASE_ANDROID_APP_ID` (the `1:215203057009:android:...` id on the Android app's settings page). `FIREBASE_SERVICE_ACCOUNT_LIFERPG_F3BAB` already exists. Create a `testers` group under App Distribution.

- [ ] **Step 2: Wire release signing into Gradle**

Create `android/key.properties.example`:

```properties
storeFile=/absolute/path/to/liferpg-release.jks
storePassword=
keyAlias=liferpg
keyPassword=
```

```bash
echo "android/key.properties" >> .gitignore
```

In `android/app/build.gradle.kts`, above the `android { }` block:

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
```

Inside `android { }`, replace the generated `buildTypes` block with:

```kotlin
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
```

- [ ] **Step 3: Write the PR workflow**

Create `.github/workflows/android-pr.yml`:

```yaml
name: Android CI

on:
  pull_request:

jobs:
  analyze_test_build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Restore Firebase config
        run: |
          echo '${{ secrets.GOOGLE_SERVICES_JSON }}' > android/app/google-services.json
          dart pub global activate flutterfire_cli
          flutterfire configure --project=liferpg-f3bab --platforms=android --yes
        env:
          GOOGLE_APPLICATION_CREDENTIALS_JSON: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_LIFERPG_F3BAB }}

      - run: flutter pub get
      - run: flutter analyze
      - run: flutter test

      - name: Build debug APK
        run: >
          flutter build apk --debug
          --dart-define=GOOGLE_SERVER_CLIENT_ID=${{ secrets.GOOGLE_SERVER_CLIENT_ID }}

      - uses: actions/upload-artifact@v4
        with:
          name: liferpg-debug-apk
          path: build/app/outputs/flutter-apk/app-debug.apk
```

- [ ] **Step 4: Write the release workflow**

Create `.github/workflows/android-release.yml`:

```yaml
name: Android Release

on:
  push:
    branches:
      - master

jobs:
  build_and_distribute:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Restore Firebase config
        run: |
          echo '${{ secrets.GOOGLE_SERVICES_JSON }}' > android/app/google-services.json
          dart pub global activate flutterfire_cli
          flutterfire configure --project=liferpg-f3bab --platforms=android --yes

      - name: Restore signing keystore
        run: |
          echo '${{ secrets.ANDROID_KEYSTORE_BASE64 }}' | base64 -d > "$RUNNER_TEMP/release.jks"
          cat > android/key.properties <<EOF
          storeFile=$RUNNER_TEMP/release.jks
          storePassword=${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          keyAlias=${{ secrets.ANDROID_KEY_ALIAS }}
          keyPassword=${{ secrets.ANDROID_KEY_PASSWORD }}
          EOF

      - run: flutter pub get
      - run: flutter test

      - name: Build release APK
        run: >
          flutter build apk --release
          --dart-define=GOOGLE_SERVER_CLIENT_ID=${{ secrets.GOOGLE_SERVER_CLIENT_ID }}

      - name: Distribute to testers
        uses: wzieba/Firebase-Distribution-Github-Action@v1
        with:
          appId: ${{ secrets.FIREBASE_ANDROID_APP_ID }}
          serviceCredentialsFileContent: ${{ secrets.FIREBASE_SERVICE_ACCOUNT_LIFERPG_F3BAB }}
          groups: testers
          file: build/app/outputs/flutter-apk/app-release.apk
```

- [ ] **Step 5: Delete the React app**

```bash
rm -rf src public node_modules
rm -f index.html vite.config.js package.json package-lock.json tsconfig.json \
      .eslintrc.js .eslintrc.json .prettierrc .env.example
rm -f .github/workflows/firebase-hosting-merge.yml \
      .github/workflows/firebase-hosting-pull-request.yml
```

- [ ] **Step 6: Drop the hosting block from firebase.json**

Replace `firebase.json` with:

```json
{
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  }
}
```

- [ ] **Step 7: Verify nothing still references the deleted files**

```bash
grep -rn --exclude-dir=.git --exclude-dir=docs --exclude-dir=tools \
  -e "vite" -e "npm run build" -e "src/components" . || echo clean
```
Expected: `clean`. Hits inside `tools/rules-test/` (which keeps its own npm project) and inside `docs/` are fine and excluded above.

- [ ] **Step 8: Rewrite CLAUDE.md**

Replace the Tech Stack, Commands, Project Structure, CI/CD and Conventions sections with the text below. The Firestore Data Model, Key Behaviors and UI Language sections stay exactly as they are.

````markdown
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

## Project Structure

`lib/` holds `main.dart` (Firebase init + auth gate), `theme/` (palette,
ornaments), `models/`, `data/` (repositories plus the `firebaseAuthProvider` /
`firestoreProvider` test seams), `providers/` (Riverpod), and `features/`
(login, home, character, users). Tests mirror that tree under `test/`.
Firestore rules have their own emulator-based test suite in `tools/rules-test/`.

## Conventions

- Never touch `FirebaseAuth.instance` or `FirebaseFirestore.instance` outside
  `lib/data/firebase_providers.dart` — tests override those two providers.
- Colours are `const Color(0xAARRGGBB)` literals with alpha baked in.
- Firestore field names stay snake_case (`current_xp`, `next_level_xp`,
  `gold_usd`); Dart-side names are camelCase and mapped in the models.
- `google-services.json`, `firebase_options.dart` and `android/key.properties`
  are gitignored; CI restores them from secrets.

## CI/CD

- `.github/workflows/android-pr.yml` — analyze, test, debug APK as an artifact.
- `.github/workflows/android-release.yml` — signed release APK to Firebase
  App Distribution on push to `master`.
````

Also update `README.md` so its opening paragraph describes a Flutter Android app and its command list matches the block above.

- [ ] **Step 9: Verify the build end to end**

```bash
flutter analyze
flutter test
flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>
ls -lh build/app/outputs/flutter-apk/app-release.apk
```
Expected: analyze clean, all tests pass, an APK is produced. Install it and confirm Google sign-in works in the **release** build — this is where a missing release SHA fingerprint shows up.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: cut over to Flutter Android, retire the React web app"
```

---

## Verification checklist

Run before declaring the rewrite done:

- [ ] `flutter analyze` reports no issues.
- [ ] `flutter test` passes every suite.
- [ ] `firebase emulators:exec --only firestore --project liferpg-rules-test "npm --prefix tools/rules-test test"` passes.
- [ ] A brand-new Google account can sign in and gets a `users/{uid}` doc with both flags `false`.
- [ ] A plain user sees only their own character; a `readOnlyOthers` user sees all and has no pencil; an admin sees all and can edit.
- [ ] An admin's edit appears on a second signed-in device without a relaunch.
- [ ] Aeroplane mode: the app still opens and renders the last-known roster.
- [ ] The release APK signs in successfully, proving the release SHA is registered.
