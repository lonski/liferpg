# In-App Auto-Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the app detect a newer GitHub release on launch and let the user download + install it in-app, without hand-downloading the APK from the releases page.

**Architecture:** A plain-Dart `UpdateRepository` polls the public GitHub Releases API once per app launch via a `FutureProvider`. If a newer version is found, `HomeScreen` shows a parchment-styled `UpdateDialog`. Tapping "Zaktualizuj teraz" drives an `UpdateDownloadController` (Riverpod `Notifier`) through a small state machine — permission check → streamed download with progress → handoff to Android's package installer via an injected `UpdateInstallerService` (wrapping `permission_handler` + `open_filex`, following the same fakeable-interface pattern as `ChangeRequestNotificationService`).

**Tech Stack:** Flutter/Dart, Riverpod (`flutter_riverpod`), `http`, `path_provider`, `package_info_plus`, `open_filex`, `permission_handler`.

**Spec:** `docs/superpowers/specs/2026-08-28-auto-update-design.md`

## Global Constraints

- UI copy is Polish, verbatim as written in each task — do not translate or reword.
- Dialog buttons render uppercase via `.toUpperCase()` at the point of use (existing app convention — see `lib/theme/dialogs.dart`), not by writing the string literals in caps.
- The GitHub repo is `lonski/liferpg`; the releases endpoint is public and unauthenticated: `https://api.github.com/repos/lonski/liferpg/releases/latest`.
- A version check failure (offline, non-200, malformed JSON, unparseable tag, no `.apk` asset) must resolve to `null`/no-op — never an error surfaced on an ordinary launch.
- Never touch `FirebaseAuth.instance`/`FirebaseFirestore.instance` outside `lib/data/firebase_providers.dart` (not touched by this feature at all — no Firebase involvement).
- Match existing dialog styling exactly: `backgroundColor: parchment`, `surfaceTintColor: Colors.transparent`, `shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: crimson, width: 2))`, title `TextStyle(fontFamily: fontDisplay, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2, color: inkHeading)`, uppercased; buttons via `dialogActionStyle` (see `lib/theme/dialogs.dart`).

---

## Task 1: Add dependencies and the install-packages permission

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Produces: five new pub dependencies (`http`, `path_provider`, `package_info_plus`, `open_filex`, `permission_handler`) available to all later tasks; the `REQUEST_INSTALL_PACKAGES` manifest permission.

- [ ] **Step 1: Add the dependencies**

Run:
```bash
flutter pub add http path_provider package_info_plus open_filex permission_handler
```

- [ ] **Step 2: Add the install-packages permission**

In `android/app/src/main/AndroidManifest.xml`, add alongside the existing `INTERNET`/`POST_NOTIFICATIONS` permissions:
```xml
    <!-- Lets the in-app updater hand a downloaded APK to Android's package
         installer (see UpdateInstallerService). -->
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```

- [ ] **Step 3: Verify the app still builds and analyzes clean**

Run: `flutter pub get && flutter analyze`
Expected: no errors (new unused-dependency warnings, if any, are fine at this stage — they'll be used starting Task 3).

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock android/app/src/main/AndroidManifest.xml
git commit -m "chore: add auto-update dependencies and install-packages permission"
```

---

## Task 2: UpdateInfo model

**Files:**
- Create: `lib/models/update_info.dart`
- Test: `test/models/update_info_test.dart`

**Interfaces:**
- Produces: `UpdateInfo({required String version, required String releaseNotes, required String apkUrl})`, value-equal via `==`/`hashCode`.

- [ ] **Step 1: Write the failing test**

```dart
// test/models/update_info_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/update_info.dart';

void main() {
  test('two UpdateInfo with the same fields are equal', () {
    const a = UpdateInfo(
      version: '1.2.0',
      releaseNotes: 'Poprawki',
      apkUrl: 'https://example.com/app.apk',
    );
    const b = UpdateInfo(
      version: '1.2.0',
      releaseNotes: 'Poprawki',
      apkUrl: 'https://example.com/app.apk',
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('a different version is not equal', () {
    const a = UpdateInfo(version: '1.2.0', releaseNotes: '', apkUrl: 'x');
    const b = UpdateInfo(version: '1.3.0', releaseNotes: '', apkUrl: 'x');
    expect(a, isNot(b));
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/models/update_info_test.dart`
Expected: FAIL — `lib/models/update_info.dart` doesn't exist yet.

- [ ] **Step 3: Implement**

```dart
// lib/models/update_info.dart
/// A newer release found by [UpdateRepository.checkForUpdate]: the target
/// version, its release notes, and the direct download URL for its APK
/// asset.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.releaseNotes,
    required this.apkUrl,
  });

  final String version;
  final String releaseNotes;
  final String apkUrl;

  @override
  bool operator ==(Object other) =>
      other is UpdateInfo &&
      other.version == version &&
      other.releaseNotes == releaseNotes &&
      other.apkUrl == apkUrl;

  @override
  int get hashCode => Object.hash(version, releaseNotes, apkUrl);
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/models/update_info_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/models/update_info.dart test/models/update_info_test.dart
git commit -m "feat: add UpdateInfo model"
```

---

## Task 3: UpdateRepository — check GitHub for a newer release

**Files:**
- Create: `lib/data/update_repository.dart`
- Test: `test/data/update_repository_test.dart`

**Interfaces:**
- Consumes: `UpdateInfo` (Task 2).
- Produces: `UpdateRepository(http.Client client, String currentVersion)` with `Future<UpdateInfo?> checkForUpdate()`. `currentVersion` is expected to already exclude the `+build` suffix (i.e. `PackageInfo.version`, not `pubspec.yaml`'s full `version:` string) — later tasks must pass it that way.

- [ ] **Step 1: Write the failing tests**

```dart
// test/data/update_repository_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferpg/data/update_repository.dart';
import 'package:liferpg/models/update_info.dart';

http.Response _releaseResponse({
  required String tag,
  String body = '',
  List<Map<String, String>> assets = const [
    {'name': 'app-release.apk', 'url': 'https://example.com/app-release.apk'},
  ],
}) {
  return http.Response(
    jsonEncode({
      'tag_name': tag,
      'body': body,
      'assets': [
        for (final a in assets)
          {'name': a['name'], 'browser_download_url': a['url']},
      ],
    }),
    200,
  );
}

void main() {
  test('returns update info when the latest tag is newer', () async {
    final repo = UpdateRepository(
      MockClient((_) async => _releaseResponse(tag: 'v1.2.0', body: 'Poprawki')),
      '1.1.0',
    );
    final result = await repo.checkForUpdate();
    expect(
      result,
      const UpdateInfo(
        version: '1.2.0',
        releaseNotes: 'Poprawki',
        apkUrl: 'https://example.com/app-release.apk',
      ),
    );
  });

  test('returns null when already up to date', () async {
    final repo = UpdateRepository(
      MockClient((_) async => _releaseResponse(tag: 'v1.1.0')),
      '1.1.0',
    );
    expect(await repo.checkForUpdate(), isNull);
  });

  test('compares numerically, not lexicographically', () async {
    final repo = UpdateRepository(
      MockClient((_) async => _releaseResponse(tag: 'v1.9.0')),
      '1.10.0',
    );
    expect(await repo.checkForUpdate(), isNull);
  });

  test('returns null on a non-200 response', () async {
    final repo = UpdateRepository(
      MockClient((_) async => http.Response('error', 500)),
      '1.0.0',
    );
    expect(await repo.checkForUpdate(), isNull);
  });

  test('returns null on a network error', () async {
    final repo = UpdateRepository(
      MockClient((_) async => throw const SocketException('offline')),
      '1.0.0',
    );
    expect(await repo.checkForUpdate(), isNull);
  });

  test('returns null when the tag does not parse as a version', () async {
    final repo = UpdateRepository(
      MockClient((_) async => _releaseResponse(tag: 'latest')),
      '1.0.0',
    );
    expect(await repo.checkForUpdate(), isNull);
  });

  test('returns null when no asset is an apk', () async {
    final repo = UpdateRepository(
      MockClient((_) async => _releaseResponse(
            tag: 'v9.9.9',
            assets: [
              {'name': 'source.zip', 'url': 'https://example.com/source.zip'},
            ],
          )),
      '1.0.0',
    );
    expect(await repo.checkForUpdate(), isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/data/update_repository_test.dart`
Expected: FAIL — `lib/data/update_repository.dart` doesn't exist yet.

- [ ] **Step 3: Implement**

```dart
// lib/data/update_repository.dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/update_info.dart';

const _releasesUrl =
    'https://api.github.com/repos/lonski/liferpg/releases/latest';

/// Parses a `N.N.N` (optionally `vN.N.N`) version string into three
/// components. Returns null if the string doesn't match that shape.
List<int>? _parseVersion(String raw) {
  final stripped = raw.startsWith('v') ? raw.substring(1) : raw;
  final parts = stripped.split('.');
  if (parts.length != 3) return null;
  final numbers = <int>[];
  for (final part in parts) {
    final n = int.tryParse(part);
    if (n == null) return null;
    numbers.add(n);
  }
  return numbers;
}

bool _isNewer(List<int> candidate, List<int> current) {
  for (var i = 0; i < 3; i++) {
    if (candidate[i] != current[i]) return candidate[i] > current[i];
  }
  return false;
}

/// Checks the public GitHub Releases API for a newer build than the one
/// currently running. Best-effort: any failure (offline, non-200, malformed
/// JSON, an unparseable tag, no `.apk` asset on the release) resolves to
/// `null` rather than throwing, so an ordinary launch never shows an error
/// for this.
class UpdateRepository {
  UpdateRepository(this._client, this._currentVersion);

  final http.Client _client;
  final String _currentVersion;

  Future<UpdateInfo?> checkForUpdate() async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(_releasesUrl));
    } catch (_) {
      return null;
    }
    if (response.statusCode != 200) return null;

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }

    final tag = json['tag_name'];
    if (tag is! String) return null;
    final latest = _parseVersion(tag);
    if (latest == null) return null;

    final current = _parseVersion(_currentVersion);
    if (current == null) return null;
    if (!_isNewer(latest, current)) return null;

    final assets = json['assets'];
    if (assets is! List) return null;
    String? apkUrl;
    for (final asset in assets) {
      if (asset is Map<String, dynamic> &&
          asset['name'] is String &&
          (asset['name'] as String).endsWith('.apk') &&
          asset['browser_download_url'] is String) {
        apkUrl = asset['browser_download_url'] as String;
        break;
      }
    }
    if (apkUrl == null) return null;

    final notes = json['body'];

    return UpdateInfo(
      version: latest.join('.'),
      releaseNotes: notes is String ? notes : '',
      apkUrl: apkUrl,
    );
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/data/update_repository_test.dart`
Expected: PASS (all 7 cases)

- [ ] **Step 5: Commit**

```bash
git add lib/data/update_repository.dart test/data/update_repository_test.dart
git commit -m "feat: add UpdateRepository for GitHub release checks"
```

---

## Task 4: UpdateInstallerService — permission + install seam

**Files:**
- Create: `lib/data/update_installer_service.dart`
- Create: `lib/data/plugin_update_installer_service.dart`

**Interfaces:**
- Produces: abstract `UpdateInstallerService` with `Future<bool> hasInstallPermission()`, `Future<void> openInstallPermissionSettings()`, `Future<bool> installApk(File apkFile)`; and `PluginUpdateInstallerService implements UpdateInstallerService`, the real `permission_handler`/`open_filex`-backed implementation.

No unit test for `PluginUpdateInstallerService` — it is a thin wrapper directly over two plugins' platform channels, exactly like `FlutterLocalNotificationsChangeRequestService` (which also has no direct test); its abstract interface is what tests fake, in Tasks 6 and 7.

- [ ] **Step 1: Define the interface**

```dart
// lib/data/update_installer_service.dart
import 'dart:io';

/// The seam through which the update flow requests install permission and
/// hands off a downloaded APK to Android, and through which tests swap in a
/// fake. See [PluginUpdateInstallerService] for the real implementation.
abstract class UpdateInstallerService {
  /// Whether this app is currently allowed to install packages from files it
  /// provides (Android's per-app "install unknown apps" setting).
  Future<bool> hasInstallPermission();

  /// Sends the user to the system settings screen where they can grant
  /// [hasInstallPermission] for this app. There is no ordinary runtime
  /// permission dialog for this permission on Android.
  Future<void> openInstallPermissionSettings();

  /// Hands [apkFile] to Android's package installer. Returns `true` if the
  /// installer was launched successfully — this does not mean the user
  /// completed the install, only that the handoff succeeded.
  Future<bool> installApk(File apkFile);
}
```

- [ ] **Step 2: Implement the real, plugin-backed version**

```dart
// lib/data/plugin_update_installer_service.dart
import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';

import 'update_installer_service.dart';

class PluginUpdateInstallerService implements UpdateInstallerService {
  @override
  Future<bool> hasInstallPermission() async {
    final status = await Permission.requestInstallPackages.status;
    return status.isGranted;
  }

  @override
  Future<void> openInstallPermissionSettings() async {
    // On Android, requesting this specific permission opens the system
    // "install unknown apps" settings screen for this app directly — there
    // is no normal runtime dialog for it.
    await Permission.requestInstallPackages.request();
  }

  @override
  Future<bool> installApk(File apkFile) async {
    final result = await OpenFilex.open(apkFile.path);
    return result.type == ResultType.done;
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `flutter analyze`
Expected: no errors.

- [ ] **Step 4: Commit**

```bash
git add lib/data/update_installer_service.dart lib/data/plugin_update_installer_service.dart
git commit -m "feat: add UpdateInstallerService and its plugin-backed implementation"
```

---

## Task 5: Providers — repository wiring and the launch-time check

**Files:**
- Create: `lib/providers/update_providers.dart`
- Test: `test/providers/update_providers_test.dart`

**Interfaces:**
- Consumes: `UpdateRepository` (Task 3), `UpdateInstallerService` (Task 4), `UpdateInfo` (Task 2).
- Produces: `updateHttpClientProvider` (`Provider<http.Client>`), `updateTempDirectoryProvider` (`Provider<Future<Directory> Function()>`, defaults to `path_provider`'s `getTemporaryDirectory`), `updateInstallerServiceProvider` (`Provider<UpdateInstallerService>`, throws `UnimplementedError` unless overridden — mirrors `changeRequestNotificationServiceProvider`), `updateRepositoryProvider` (`FutureProvider<UpdateRepository>`), `updateCheckProvider` (`FutureProvider<UpdateInfo?>`).

- [ ] **Step 1: Write the failing test**

```dart
// test/providers/update_providers_test.dart
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferpg/data/update_repository.dart';
import 'package:liferpg/models/update_info.dart';
import 'package:liferpg/providers/update_providers.dart';

void main() {
  test('updateCheckProvider surfaces a newer release from the repository',
      () async {
    final container = ProviderContainer(overrides: [
      updateRepositoryProvider.overrideWith(
        (ref) async => UpdateRepository(
          MockClient((_) async => http.Response(
                jsonEncode({
                  'tag_name': 'v9.9.9',
                  'body': 'Nowości',
                  'assets': [
                    {
                      'name': 'app-release.apk',
                      'browser_download_url': 'https://example.com/app.apk',
                    },
                  ],
                }),
                200,
                // http.Response defaults to latin1 when no content-type is
                // given, which cannot encode "Nowości" (Polish diacritics
                // aren't in Latin-1) and throws — caught by
                // UpdateRepository's own catch-all and misread as "no
                // update". application/json makes it default to utf8
                // instead, matching how GitHub's real API responds.
                headers: {'content-type': 'application/json'},
              )),
          '1.0.0',
        ),
      ),
    ]);
    addTearDown(container.dispose);

    final result = await container.read(updateCheckProvider.future);

    expect(
      result,
      const UpdateInfo(
        version: '9.9.9',
        releaseNotes: 'Nowości',
        apkUrl: 'https://example.com/app.apk',
      ),
    );
  });

  test('updateCheckProvider returns null when up to date', () async {
    final container = ProviderContainer(overrides: [
      updateRepositoryProvider.overrideWith(
        (ref) async => UpdateRepository(
          MockClient((_) async => http.Response(
                jsonEncode({'tag_name': 'v1.0.0', 'body': '', 'assets': <dynamic>[]}),
                200,
              )),
          '1.0.0',
        ),
      ),
    ]);
    addTearDown(container.dispose);

    expect(await container.read(updateCheckProvider.future), isNull);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/providers/update_providers_test.dart`
Expected: FAIL — `lib/providers/update_providers.dart` doesn't exist yet.

- [ ] **Step 3: Implement**

```dart
// lib/providers/update_providers.dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../data/update_installer_service.dart';
import '../data/update_repository.dart';
import '../models/update_info.dart';

final updateHttpClientProvider =
    Provider<http.Client>((ref) => http.Client());

/// A seam around `path_provider`'s `getTemporaryDirectory()` so tests can
/// override it instead of hitting a real platform channel (there is no
/// platform channel in `flutter_test`, and unlike `package_info_plus` this
/// plugin has no built-in test-mode fallback).
final updateTempDirectoryProvider =
    Provider<Future<Directory> Function()>((ref) => getTemporaryDirectory);

/// Overridden in `main()` with a real, plugin-backed implementation.
final updateInstallerServiceProvider = Provider<UpdateInstallerService>((ref) {
  throw UnimplementedError(
    'updateInstallerServiceProvider must be overridden in main() with a '
    'real UpdateInstallerService.',
  );
});

final updateRepositoryProvider = FutureProvider<UpdateRepository>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return UpdateRepository(ref.watch(updateHttpClientProvider), info.version);
});

/// Runs exactly once per app process (a plain, non-stream `FutureProvider`
/// isn't re-triggered by rebuilds) — this alone gives "check on every
/// launch, and if the resulting dialog is dismissed, ask again next launch"
/// with no dismissal state to persist.
final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  final repository = await ref.watch(updateRepositoryProvider.future);
  return repository.checkForUpdate();
});
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/providers/update_providers_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/providers/update_providers.dart test/providers/update_providers_test.dart
git commit -m "feat: add update-check providers"
```

---

## Task 6: UpdateDownloadController — download and install state machine

**Files:**
- Create: `lib/providers/update_download_controller.dart`
- Test: `test/providers/update_download_controller_test.dart`

**Interfaces:**
- Consumes: `updateHttpClientProvider`, `updateTempDirectoryProvider`, `updateInstallerServiceProvider` (Task 5), `UpdateInfo` (Task 2), `UpdateInstallerService` (Task 4).
- Produces: sealed `UpdateDownloadState` (`UpdateDownloadIdle`, `UpdateDownloadNeedsPermission`, `UpdateDownloadInProgress(int received, int? total)`, `UpdateDownloadInstalling`, `UpdateDownloadInstallerLaunched`, `UpdateDownloadFailed(String message)`); `UpdateDownloadController extends Notifier<UpdateDownloadState>` with `start(UpdateInfo)`, `retryAfterSettings(UpdateInfo)`, `openSettings()`, `retryDownload(UpdateInfo)`; `updateDownloadControllerProvider` (`NotifierProvider<UpdateDownloadController, UpdateDownloadState>`).

- [ ] **Step 1: Write the failing tests**

```dart
// test/providers/update_download_controller_test.dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferpg/data/update_installer_service.dart';
import 'package:liferpg/models/update_info.dart';
import 'package:liferpg/providers/update_download_controller.dart';
import 'package:liferpg/providers/update_providers.dart';

class FakeUpdateInstallerService implements UpdateInstallerService {
  FakeUpdateInstallerService({this.granted = true, this.installResult = true});
  bool granted;
  final bool installResult;
  var settingsOpenedCount = 0;
  File? installedFile;

  @override
  Future<bool> hasInstallPermission() async => granted;

  @override
  Future<void> openInstallPermissionSettings() async {
    settingsOpenedCount++;
  }

  @override
  Future<bool> installApk(File apkFile) async {
    installedFile = apkFile;
    return installResult;
  }
}

const _info = UpdateInfo(
  version: '9.9.9',
  releaseNotes: '',
  apkUrl: 'https://example.com/app.apk',
);

ProviderContainer _containerWith({
  required FakeUpdateInstallerService installer,
  required http.Client client,
}) {
  final container = ProviderContainer(overrides: [
    updateInstallerServiceProvider.overrideWithValue(installer),
    updateHttpClientProvider.overrideWithValue(client),
    // getTemporaryDirectory() has no platform channel in flutter_test.
    updateTempDirectoryProvider.overrideWithValue(
      () async => Directory.systemTemp,
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('start() downloads and installs when permission is already granted',
      () async {
    final installer = FakeUpdateInstallerService();
    final container = _containerWith(
      installer: installer,
      client: MockClient((_) async => http.Response('apk-bytes', 200)),
    );
    final states = <UpdateDownloadState>[];
    container.listen(
      updateDownloadControllerProvider,
      (previous, next) => states.add(next),
      fireImmediately: true,
    );

    await container
        .read(updateDownloadControllerProvider.notifier)
        .start(_info);

    expect(states.last, isA<UpdateDownloadInstallerLaunched>());
    expect(installer.installedFile, isNotNull);
    expect(states.any((s) => s is UpdateDownloadInProgress), isTrue);
  });

  test('start() asks for permission first when not granted', () async {
    final installer = FakeUpdateInstallerService(granted: false);
    final container = _containerWith(
      installer: installer,
      client: MockClient((_) async => http.Response('apk-bytes', 200)),
    );

    await container
        .read(updateDownloadControllerProvider.notifier)
        .start(_info);

    expect(
      container.read(updateDownloadControllerProvider),
      isA<UpdateDownloadNeedsPermission>(),
    );
    expect(installer.installedFile, isNull);
  });

  test('retryAfterSettings() proceeds once permission is granted', () async {
    final installer = FakeUpdateInstallerService(granted: false);
    final container = _containerWith(
      installer: installer,
      client: MockClient((_) async => http.Response('apk-bytes', 200)),
    );
    final controller = container.read(updateDownloadControllerProvider.notifier);
    await controller.start(_info);
    expect(
      container.read(updateDownloadControllerProvider),
      isA<UpdateDownloadNeedsPermission>(),
    );

    installer.granted = true;
    await controller.retryAfterSettings(_info);

    expect(
      container.read(updateDownloadControllerProvider),
      isA<UpdateDownloadInstallerLaunched>(),
    );
  });

  test('a download failure surfaces UpdateDownloadFailed', () async {
    final installer = FakeUpdateInstallerService();
    final container = _containerWith(
      installer: installer,
      client: MockClient((_) async => http.Response('error', 500)),
    );

    await container
        .read(updateDownloadControllerProvider.notifier)
        .start(_info);

    expect(
      container.read(updateDownloadControllerProvider),
      isA<UpdateDownloadFailed>(),
    );
  });

  test('an install failure surfaces UpdateDownloadFailed', () async {
    final installer = FakeUpdateInstallerService(installResult: false);
    final container = _containerWith(
      installer: installer,
      client: MockClient((_) async => http.Response('apk-bytes', 200)),
    );

    await container
        .read(updateDownloadControllerProvider.notifier)
        .start(_info);

    expect(
      container.read(updateDownloadControllerProvider),
      isA<UpdateDownloadFailed>(),
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/providers/update_download_controller_test.dart`
Expected: FAIL — `lib/providers/update_download_controller.dart` doesn't exist yet.

- [ ] **Step 3: Implement**

```dart
// lib/providers/update_download_controller.dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../models/update_info.dart';
import 'update_providers.dart';

sealed class UpdateDownloadState {
  const UpdateDownloadState();
}

class UpdateDownloadIdle extends UpdateDownloadState {
  const UpdateDownloadIdle();
}

class UpdateDownloadNeedsPermission extends UpdateDownloadState {
  const UpdateDownloadNeedsPermission();
}

class UpdateDownloadInProgress extends UpdateDownloadState {
  const UpdateDownloadInProgress(this.received, this.total);
  final int received;
  final int? total;
}

class UpdateDownloadInstalling extends UpdateDownloadState {
  const UpdateDownloadInstalling();
}

/// Terminal success: the system installer was handed the APK. This app has
/// no further visibility into accept/cancel/success from here.
class UpdateDownloadInstallerLaunched extends UpdateDownloadState {
  const UpdateDownloadInstallerLaunched();
}

class UpdateDownloadFailed extends UpdateDownloadState {
  const UpdateDownloadFailed(this.message);
  final String message;
}

class UpdateDownloadController extends Notifier<UpdateDownloadState> {
  @override
  UpdateDownloadState build() => const UpdateDownloadIdle();

  Future<void> start(UpdateInfo info) async {
    final installer = ref.read(updateInstallerServiceProvider);
    if (!await installer.hasInstallPermission()) {
      state = const UpdateDownloadNeedsPermission();
      return;
    }
    await _download(info);
  }

  /// Called when the app resumes after the user was sent to Settings to
  /// grant install permission. A no-op unless we're actually waiting on
  /// that permission.
  Future<void> retryAfterSettings(UpdateInfo info) async {
    if (state is! UpdateDownloadNeedsPermission) return;
    final installer = ref.read(updateInstallerServiceProvider);
    if (await installer.hasInstallPermission()) {
      await _download(info);
    }
  }

  Future<void> openSettings() =>
      ref.read(updateInstallerServiceProvider).openInstallPermissionSettings();

  Future<void> retryDownload(UpdateInfo info) => start(info);

  Future<void> _download(UpdateInfo info) async {
    state = const UpdateDownloadInProgress(0, null);
    try {
      final client = ref.read(updateHttpClientProvider);
      final response =
          await client.send(http.Request('GET', Uri.parse(info.apkUrl)));
      if (response.statusCode != 200) {
        state = const UpdateDownloadFailed('Nie udało się pobrać aktualizacji.');
        return;
      }

      final getTempDir = ref.read(updateTempDirectoryProvider);
      final dir = await getTempDir();
      final file = File('${dir.path}/update.apk');
      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength;
      await response.stream.listen((chunk) {
        received += chunk.length;
        sink.add(chunk);
        state = UpdateDownloadInProgress(received, total);
      }).asFuture<void>();
      await sink.close();

      state = const UpdateDownloadInstalling();
      final installer = ref.read(updateInstallerServiceProvider);
      final opened = await installer.installApk(file);
      state = opened
          ? const UpdateDownloadInstallerLaunched()
          : const UpdateDownloadFailed('Nie udało się otworzyć instalatora.');
    } catch (_) {
      state = const UpdateDownloadFailed('Nie udało się pobrać aktualizacji.');
    }
  }
}

final updateDownloadControllerProvider =
    NotifierProvider<UpdateDownloadController, UpdateDownloadState>(
  UpdateDownloadController.new,
);
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/providers/update_download_controller_test.dart`
Expected: PASS (all 5 cases)

- [ ] **Step 5: Commit**

```bash
git add lib/providers/update_download_controller.dart test/providers/update_download_controller_test.dart
git commit -m "feat: add UpdateDownloadController"
```

---

## Task 7: UpdateDialog

**Files:**
- Create: `lib/features/update/update_dialog.dart`
- Test: `test/features/update_dialog_test.dart`

**Interfaces:**
- Consumes: `UpdateInfo` (Task 2), `updateDownloadControllerProvider` + `UpdateDownloadState` variants (Task 6), `updateInstallerServiceProvider` + `updateHttpClientProvider` + `updateTempDirectoryProvider` (Task 5), theme constants `parchment`, `crimson`, `fontDisplay`, `inkHeading`, `parchmentLight`, `goldGlyph` and `dialogActionStyle` from `lib/theme/app_theme.dart` / `lib/theme/dialogs.dart`.
- Produces: `UpdateDialog` widget and `UpdateDialog.show(BuildContext, UpdateInfo)`, used by Task 8's `HomeScreen` wiring.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/update_dialog_test.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferpg/data/update_installer_service.dart';
import 'package:liferpg/features/update/update_dialog.dart';
import 'package:liferpg/models/update_info.dart';
import 'package:liferpg/providers/update_providers.dart';

class FakeUpdateInstallerService implements UpdateInstallerService {
  FakeUpdateInstallerService({this.granted = true, this.installResult = true});
  bool granted;
  final bool installResult;
  var settingsOpened = false;
  File? installedFile;

  @override
  Future<bool> hasInstallPermission() async => granted;

  @override
  Future<void> openInstallPermissionSettings() async {
    settingsOpened = true;
    granted = true;
  }

  @override
  Future<bool> installApk(File apkFile) async {
    installedFile = apkFile;
    return installResult;
  }
}

const _info = UpdateInfo(
  version: '9.9.9',
  releaseNotes: 'Nowości',
  apkUrl: 'https://example.com/app.apk',
);

Future<void> _pumpDialog(
  WidgetTester tester, {
  required FakeUpdateInstallerService installer,
  required http.Client client,
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      updateInstallerServiceProvider.overrideWithValue(installer),
      updateHttpClientProvider.overrideWithValue(client),
      // getTemporaryDirectory() has no platform channel in flutter_test.
      updateTempDirectoryProvider.overrideWithValue(
        () async => Directory.systemTemp,
      ),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => UpdateDialog.show(context, _info),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the version and release notes', (tester) async {
    await _pumpDialog(
      tester,
      installer: FakeUpdateInstallerService(),
      client: MockClient((_) async => http.Response('apk-bytes', 200)),
    );

    expect(find.textContaining('9.9.9'), findsOneWidget);
    expect(find.textContaining('Nowości'), findsOneWidget);
  });

  testWidgets('downloads and installs, then closes', (tester) async {
    final installer = FakeUpdateInstallerService();
    await _pumpDialog(
      tester,
      installer: installer,
      client: MockClient((_) async => http.Response('apk-bytes', 200)),
    );

    await tester.tap(find.text('ZAKTUALIZUJ TERAZ'));
    await tester.pumpAndSettle();

    expect(installer.installedFile, isNotNull);
    expect(find.byType(UpdateDialog), findsNothing);
  });

  testWidgets('asks to open settings when permission is missing', (tester) async {
    final installer = FakeUpdateInstallerService(granted: false);
    await _pumpDialog(
      tester,
      installer: installer,
      client: MockClient((_) async => http.Response('apk-bytes', 200)),
    );

    await tester.tap(find.text('ZAKTUALIZUJ TERAZ'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Aby zainstalować aktualizację, zezwól na instalowanie z tego źródła.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('OTWÓRZ USTAWIENIA'));
    await tester.pumpAndSettle();

    expect(installer.settingsOpened, isTrue);
  });

  testWidgets('shows a retry action when the download fails', (tester) async {
    final installer = FakeUpdateInstallerService();
    await _pumpDialog(
      tester,
      installer: installer,
      client: MockClient((_) async => http.Response('error', 500)),
    );

    await tester.tap(find.text('ZAKTUALIZUJ TERAZ'));
    await tester.pumpAndSettle();

    expect(find.text('SPRÓBUJ PONOWNIE'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/update_dialog_test.dart`
Expected: FAIL — `lib/features/update/update_dialog.dart` doesn't exist yet.

- [ ] **Step 3: Implement**

```dart
// lib/features/update/update_dialog.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/update_info.dart';
import '../../providers/update_download_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/dialogs.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.info});

  final UpdateInfo info;

  static Future<void> show(BuildContext context, UpdateInfo info) =>
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpdateDialog(info: info),
      );

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref
          .read(updateDownloadControllerProvider.notifier)
          .retryAfterSettings(widget.info);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(updateDownloadControllerProvider);

    ref.listen<UpdateDownloadState>(updateDownloadControllerProvider,
        (previous, next) {
      if (next is UpdateDownloadInstallerLaunched) {
        Navigator.of(context).pop();
      }
    });

    return AlertDialog(
      backgroundColor: parchment,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: crimson, width: 2),
      ),
      title: Text(
        'Nowa wersja dostępna'.toUpperCase(),
        style: const TextStyle(
          fontFamily: fontDisplay,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 2,
          color: inkHeading,
        ),
      ),
      content: _content(state),
      actions: _actions(context, state),
    );
  }

  Widget _content(UpdateDownloadState state) {
    return switch (state) {
      UpdateDownloadIdle() => Text(
          'Wersja ${widget.info.version}\n\n${widget.info.releaseNotes}',
          style: const TextStyle(color: inkHeading),
        ),
      UpdateDownloadNeedsPermission() => const Text(
          'Aby zainstalować aktualizację, zezwól na instalowanie z tego '
          'źródła.',
          style: TextStyle(color: inkHeading),
        ),
      UpdateDownloadInProgress(:final received, :final total) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: (total != null && total > 0) ? received / total : null,
              color: crimson,
            ),
            const SizedBox(height: 8),
            Text(
              'Pobieranie aktualizacji...',
              style: const TextStyle(color: inkHeading),
            ),
          ],
        ),
      UpdateDownloadInstalling() => const Text(
          'Otwieranie instalatora...',
          style: TextStyle(color: inkHeading),
        ),
      UpdateDownloadInstallerLaunched() => const Text(
          'Otwieranie instalatora...',
          style: TextStyle(color: inkHeading),
        ),
      UpdateDownloadFailed(:final message) =>
        Text(message, style: const TextStyle(color: inkHeading)),
    };
  }

  List<Widget> _actions(BuildContext context, UpdateDownloadState state) {
    final controller = ref.read(updateDownloadControllerProvider.notifier);
    final later = TextButton(
      onPressed: () => Navigator.of(context).pop(),
      style: TextButton.styleFrom(foregroundColor: crimson),
      child: Text('Później'.toUpperCase(), style: dialogActionStyle),
    );
    Widget primary(String label, VoidCallback onPressed) => TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor: crimson,
            foregroundColor: parchmentLight,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
              side: const BorderSide(color: goldGlyph),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: Text(label.toUpperCase(), style: dialogActionStyle),
        );

    return switch (state) {
      UpdateDownloadIdle() => [
          later,
          primary('Zaktualizuj teraz', () => controller.start(widget.info)),
        ],
      UpdateDownloadNeedsPermission() => [
          later,
          primary('Otwórz ustawienia', () => controller.openSettings()),
        ],
      UpdateDownloadFailed() => [
          later,
          primary(
            'Spróbuj ponownie',
            () => controller.retryDownload(widget.info),
          ),
        ],
      UpdateDownloadInProgress() ||
      UpdateDownloadInstalling() ||
      UpdateDownloadInstallerLaunched() =>
        const [],
    };
  }
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/features/update_dialog_test.dart`
Expected: PASS (all 4 cases)

- [ ] **Step 5: Commit**

```bash
git add lib/features/update/update_dialog.dart test/features/update_dialog_test.dart
git commit -m "feat: add UpdateDialog"
```

---

## Task 8: Wire it into the app

**Files:**
- Modify: `lib/features/home/home_screen.dart`
- Modify: `lib/main.dart`
- Modify: `test/features/home_screen_test.dart`

**Interfaces:**
- Consumes: `updateCheckProvider` (Task 5), `UpdateDialog` (Task 7), `PluginUpdateInstallerService` (Task 4), `updateInstallerServiceProvider` (Task 5).

- [ ] **Step 1: Write the failing test**

Add to `test/features/home_screen_test.dart` (alongside the existing tests, using its existing `pumpHome` helper and imports — add the two new imports shown, and the `Override` import already present in that file):

```dart
import 'package:liferpg/models/update_info.dart';
import 'package:liferpg/providers/update_providers.dart';
import 'package:liferpg/features/update/update_dialog.dart';
```

```dart
  testWidgets('shows the update dialog when a newer version is found',
      (tester) async {
    await pumpHome(
      tester,
      await seed(),
      extraOverrides: [
        updateCheckProvider.overrideWith(
          (ref) async => const UpdateInfo(
            version: '9.9.9',
            releaseNotes: '',
            apkUrl: 'https://example.com/app.apk',
          ),
        ),
      ],
    );

    expect(find.byType(UpdateDialog), findsOneWidget);
  });

  testWidgets('shows no update dialog when already up to date',
      (tester) async {
    await pumpHome(
      tester,
      await seed(),
      extraOverrides: [
        updateCheckProvider.overrideWith((ref) async => null),
      ],
    );

    expect(find.byType(UpdateDialog), findsNothing);
  });
```

Note: the pre-existing tests in this file pass no `updateCheckProvider` override. That's fine by construction — without an override, `updateCheckProvider` depends on `updateRepositoryProvider`'s real `PackageInfo.fromPlatform()` call, which has no platform channel in a widget test and resolves to an `AsyncError`; `HomeScreen`'s listener (Step 2 below) only reads `next.value`, which is `null` for an errored `AsyncValue`, so no dialog appears and no test fails. Don't add overrides to the pre-existing tests.

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/features/home_screen_test.dart`
Expected: FAIL on the two new tests — `HomeScreen` doesn't show `UpdateDialog` yet.

- [ ] **Step 3: Wire the dialog into HomeScreen**

In `lib/features/home/home_screen.dart`, add the imports:
```dart
import '../../models/update_info.dart';
import '../../providers/update_providers.dart';
import '../update/update_dialog.dart';
```

At the top of `build`, alongside the other `ref.watch`/`ref.listen` setup (right after the existing `ownsACharacter` computation, before `return Scaffold(`), add:
```dart
    // Checked once per app launch (see updateCheckProvider); shows at most
    // once here too, since the provider only transitions loading -> data
    // once per process.
    ref.listen<AsyncValue<UpdateInfo?>>(updateCheckProvider, (previous, next) {
      final info = next.value;
      if (info != null) UpdateDialog.show(context, info);
    });
```

- [ ] **Step 4: Wire the real installer service in main()**

In `lib/main.dart`, add the imports:
```dart
import 'data/plugin_update_installer_service.dart';
import 'providers/update_providers.dart';
```

Add to the `ProviderScope`'s `overrides` list (alongside the existing `sharedPreferencesProvider`/`changeRequestNotificationServiceProvider` overrides):
```dart
      updateInstallerServiceProvider
          .overrideWithValue(PluginUpdateInstallerService()),
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/features/home_screen_test.dart`
Expected: PASS (all cases, old and new)

- [ ] **Step 6: Run the full test suite and analyzer**

Run: `flutter test && flutter analyze`
Expected: no failures, no analyzer errors.

- [ ] **Step 7: Commit**

```bash
git add lib/features/home/home_screen.dart lib/main.dart test/features/home_screen_test.dart
git commit -m "feat: check for and offer in-app updates on launch"
```

---

## Manual verification (after Task 8)

Automated tests fake every platform channel this feature touches (`open_filex`, `permission_handler`, `package_info_plus`), so a real-device pass is the only way to see the actual Android permission screen and installer handoff. After all tasks land:

1. Build and install a debug APK with a version *older* than the latest GitHub release's tag (temporarily edit `pubspec.yaml`'s `version:` down if needed, or wait for the next real tagged release).
2. Launch the app, confirm the dialog appears with the correct version/notes.
3. Tap "Zaktualizuj teraz" on a fresh install (permission not yet granted) — confirm it explains and redirects to the "install unknown apps" settings screen, and that returning to the app resumes the download automatically once granted.
4. Confirm the download progress bar advances and Android's package installer opens with the correct APK.
5. Revert any temporary `pubspec.yaml` version edit.
