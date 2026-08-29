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

/// The running build's version + build number, so a user can confirm which
/// APK they actually installed. `PackageInfo.fromPlatform()` throws under
/// `flutter_test` (no platform channel), which surfaces here as an
/// `AsyncError` -- callers reading `.value` just get `null` and show
/// nothing, so no test needs to override this to render cleanly.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'v${info.version}+${info.buildNumber}';
});

/// Runs exactly once per app process (a plain, non-stream `FutureProvider`
/// isn't re-triggered by rebuilds) — this alone gives "check on every
/// launch, and if the resulting dialog is dismissed, ask again next launch"
/// with no dismissal state to persist.
final updateCheckProvider = FutureProvider<UpdateInfo?>((ref) async {
  final repository = await ref.watch(updateRepositoryProvider.future);
  return await repository.checkForUpdate();
});
