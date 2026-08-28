# In-App Auto-Update — Design

## Motivation

Releases are published as APKs attached to GitHub Releases
(`.github/workflows/android-release.yml`, triggered by `v*` tags). Today the
only way to get a new build is to remember to check the releases page and
sideload the APK by hand. This adds an in-app check that finds a newer
release automatically and lets the user download and install it without
leaving the app.

Firebase App Distribution was tried for this purpose already and pulled
after its service account started returning 403 on upload (see
`android-release.yml` comment) — out of scope here; if that gets fixed later
it can complement this feature as a separate distribution channel for
testers, not a replacement for it.

## New dependencies

`http`, `path_provider`, `package_info_plus`, `open_filex`,
`permission_handler`.

## Components

Follows the existing `data/` → `providers/` → `features/` layering, and
mirrors the `ChangeRequestNotificationService` pattern (abstract interface in
`data/`, a real plugin-backed implementation, a provider seam for tests) for
the one part of this feature that touches platform channels.

- **`lib/models/update_info.dart`** — immutable data class: `version`
  (three-part numeric, e.g. `1.2.0`), `releaseNotes` (the release body,
  possibly empty), `apkUrl`.

- **`lib/data/update_repository.dart`** — `UpdateRepository`, constructed
  with an injected `http.Client` (test seam — same role `MockClient` from
  `package:http/testing.dart` plays in tests as fake Firestore/Auth play
  elsewhere) and the app's own version string.
  - `Future<UpdateInfo?> checkForUpdate()`:
    1. `GET https://api.github.com/repos/lonski/liferpg/releases/latest`
       (public repo, unauthenticated — no secret/token needed).
    2. On any non-200 response, network error, or JSON body that doesn't
       parse as expected: return `null`. This check is best-effort and must
       never surface an error dialog on an ordinary (possibly offline)
       launch — consistent with the tolerant-parsing philosophy already used
       for legacy Firestore fields (`Character.fromMap`, change-request delta
       coercion).
    3. Take `tag_name`, strip a leading `v` if present, and parse three
       numeric components. If the tag doesn't parse as `N.N.N`, treat as no
       update available (return `null`) rather than throwing.
    4. Find the first entry in `assets` whose `name` ends with `.apk`; if
       none exists, return `null` (nothing installable to offer).
    5. Compare the parsed tag version against the running app's version
       (from `PackageInfo.version`, e.g. `1.1.0` — note this is
       `pubspec.yaml`'s `version:` field *before* the `+build` suffix, so a
       build-number-only bump, e.g. `1.1.0+3` → `1.1.0+4` with the same
       `version:` string, never triggers a prompt). Numeric three-part
       comparison, no `pub_semver` dependency needed.
    6. Return `UpdateInfo` if the tag is strictly newer, else `null`.
  - Version comparison lives as a small private pure function so it's
    directly unit-testable.

- **`lib/data/update_installer_service.dart`** — abstract interface:
  ```dart
  abstract class UpdateInstallerService {
    Future<bool> hasInstallPermission();
    Future<void> openInstallPermissionSettings();
    Future<void> installApk(File apkFile);
  }
  ```

- **`lib/data/plugin_update_installer_service.dart`** —
  `PluginUpdateInstallerService implements UpdateInstallerService`:
  - `hasInstallPermission()` → `Permission.requestInstallPackages.status.isGranted`.
  - `openInstallPermissionSettings()` → `Permission.requestInstallPackages.request()`
    (on Android, requesting this specific permission itself opens the
    system "install unknown apps" settings screen for this app — there is no
    normal runtime dialog for it).
  - `installApk(file)` → `OpenFilex.open(file.path)`.

- **`lib/providers/update_providers.dart`**:
  - `updateRepositoryProvider` — builds `UpdateRepository` with a real
    `http.Client()` and `PackageInfo.fromPlatform()`.
  - `updateInstallerServiceProvider` — provides `UpdateInstallerService`,
    defaulting to `PluginUpdateInstallerService()`; overridden with a fake in
    tests, exactly like `firebaseAuthProvider`/`firestoreProvider`.
  - `updateCheckProvider` — `FutureProvider<UpdateInfo?>` calling
    `updateRepositoryProvider.checkForUpdate()`. Being a plain
    (non-autoDispose, non-stream) `FutureProvider`, it runs exactly once per
    app process and is not re-triggered by widget rebuilds — this alone
    satisfies "check on every launch, and if dismissed, ask again next
    launch" with no extra dismissal state to persist.
  - `UpdateDownloadController` (`Notifier<UpdateDownloadState>`) — drives the
    download/install flow once the user taps "Zaktualizuj teraz". States:
    `idle`, `needsPermission`, `downloading(received, total)`, `installing`,
    `error(message)`.

- **`lib/features/update/update_dialog.dart`** — `UpdateDialog`, shown from
  the home screen (`ConsumerWidget` watching `updateCheckProvider`; on a
  non-null value not yet shown this build, `showDialog` once) as a
  parchment-styled dialog matching the app's existing dialog visual language
  (see the confirm dialogs referenced in
  `2026-08-28-change-request-lifecycle-design.md`).
  - Idle content: "Nowa wersja dostępna" title, the target version number,
    the release notes text (verbatim, no markdown rendering — plain text is
    enough), "Później" (closes, no persisted state — see above) and
    "Zaktualizuj teraz" buttons.
  - Tapping "Zaktualizuj teraz" drives `UpdateDownloadController`:
    - `needsPermission` → dialog content swaps to a short explanation
      ("Aby zainstalować aktualizację, zezwól na instalowanie z tego
      źródła") plus "Otwórz ustawienia", which calls
      `openInstallPermissionSettings()`; on the app's next resume
      (`AppLifecycleListener`/`WidgetsBindingObserver.didChangeAppLifecycleState`)
      the controller re-checks `hasInstallPermission()` and, if now granted,
      proceeds to download automatically.
    - `downloading` → a `LinearProgressIndicator` driven by
      received/total bytes, streamed by the controller from
      `http.Client().send(Request('GET', apkUrl))`, writing chunks to
      `${(await getTemporaryDirectory()).path}/update.apk` (overwritten each
      attempt).
    - `installing` → briefly shown while `installApk` is invoked, then the
      dialog closes. Once `open_filex` hands off to Android's package
      installer UI, this app has no further visibility into
      accept/cancel/success — nothing more to track.
    - `error` → inline error text plus "Spróbuj ponownie" (retry), since
      this failure is in direct response to a user action and silence here
      would be confusing (unlike the silent-on-launch check).

## Manifest changes

Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```
No manual `FileProvider`/`file_paths.xml` entry — `open_filex` declares its
own via manifest merging under its own authority. The app must not declare a
conflicting `FileProvider` under the same authority.

## Testing

- `UpdateRepository`: unit tests using `package:http/testing.dart`'s
  `MockClient` to fake the GitHub API response. Cases: newer version
  available; already up to date; build-number-only difference (no update);
  malformed/non-200 response; release with no `.apk` asset; unparseable tag.
- Version comparator: pure-function unit tests for the same edge cases plus
  ordering (`1.2.0` > `1.10.0` is false under numeric-not-lexicographic
  comparison — this matters since a plain string compare would get this
  wrong).
- `UpdateDialog`: widget tests with `updateCheckProvider` and
  `updateInstallerServiceProvider` overridden to fakes/canned futures —
  covering the happy path (idle → downloading → installing), the
  needs-permission branch, and the download-error/retry branch. No real
  platform channel is exercised, matching how
  `ChangeRequestNotificationService` is faked in existing tests.

## Out of scope

- Periodic/background checking while the app is open (decided: launch-time
  check only).
- "Skip this version" persistence (decided: a dismissed prompt reappears
  next launch, deliberately, with no extra state).
- Re-enabling Firebase App Distribution.
- Publishing to Google Play.
