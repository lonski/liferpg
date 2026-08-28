---
name: installing-app
description: Use when asked to install, run, or side-load the LifeRPG Android app onto a connected device or emulator via adb — the request will mention "install via adb", "run on my phone", "side-load", or similar, for this repo specifically.
---

# Installing the App on a Device

## Overview

Every `flutter run` / `flutter build apk` invocation needs
`--dart-define=GOOGLE_SERVER_CLIENT_ID=<web client id>` or Google Sign-In
fails to initialize (see `CLAUDE.md`). That value is a secret and is never
committed — it doesn't live in this repo as plain text anywhere. But it
**is** derivable from `android/app/google-services.json`, which is
gitignored but usually already present on a dev machine that has built this
app before.

## Steps

1. Confirm a device is attached: `adb devices -l`. If nothing lists, stop
   and tell the user — don't guess a device id.
2. Get the web client ID. Read `android/app/google-services.json` and find
   the OAuth client with `"client_type": 3` (type 1 is the Android client,
   type 3 is the Web client — Google Sign-In on Android needs the *Web* one
   as its server client ID):
   ```bash
   python3 -c "
   import json
   with open('android/app/google-services.json') as f:
       data = json.load(f)
   for client in data.get('client', []):
       for oauth in client.get('oauth_client', []):
           print(oauth.get('client_type'), oauth.get('client_id'))
   "
   ```
   If `android/app/google-services.json` doesn't exist on this machine, stop
   and ask the user — it's gitignored and CI restores it from secrets, so
   there's no way to derive the client ID without either that file or the
   user pasting the value directly (Firebase console → Authentication →
   Sign-in method → Google → Web SDK configuration).
3. Build a debug APK with that value:
   ```bash
   flutter build apk --debug --dart-define=GOOGLE_SERVER_CLIENT_ID=<client_type 3 value>
   ```
4. Install it on the connected device:
   ```bash
   adb install -r build/app/outputs/flutter-apk/app-debug.apk
   ```
   `-r` reinstalls over an existing install (or a prior uninstall leaves
   nothing to conflict with either way) without wiping the device's other
   app data.

## Gotchas

- Don't use `flutter run` for a plain "install it" request — it builds,
  installs, *and* attaches a debug session/hot-reload loop, which is more
  than asked for and leaves a process to manage. Prefer `flutter build apk`
  + `adb install` for a one-shot install.
- If multiple devices are attached, `adb install` is ambiguous — pass
  `-s <device-serial>` (from `adb devices -l`) to both target and confirm
  which device before installing.
- A release APK (`flutter build apk --release`) needs `android/key.properties`
  (also gitignored) or it silently falls back to debug signing — see
  `CLAUDE.md`'s Build Gotchas. For a quick side-load, debug is almost always
  what's wanted; only reach for `--release` if the user says so.
