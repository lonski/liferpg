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
