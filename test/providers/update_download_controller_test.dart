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
