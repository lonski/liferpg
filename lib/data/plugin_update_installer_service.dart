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
