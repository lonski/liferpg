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
