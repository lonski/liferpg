# LifeRPG

A native Flutter Android app that gamifies real life — users are RPG characters with levels, XP, gold, and a "favour" (mood/disposition) score tracked over time. Backed by Firebase (Firestore + Google Auth).

See [CLAUDE.md](CLAUDE.md) for the full architecture, data model, and conventions.

## Available Commands

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>   # debug on device
flutter test                                                        # run tests
flutter analyze                                                     # lint
flutter build apk --release --dart-define=GOOGLE_SERVER_CLIENT_ID=<id>
```

Add `--dart-define=SHOW_FAVOUR=true` to enable the favour UI. `<web client id>` is the OAuth web client id from the Firebase console.

Firestore security rules have their own emulator-based test suite in `tools/rules-test/` — see that directory for its own setup.
