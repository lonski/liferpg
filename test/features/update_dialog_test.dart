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

    // The download performs real dart:io File writes (against the
    // overridden temp-directory seam), which can't progress on the fake
    // clock the default testWidgets zone runs on. runAsync hands control to
    // the real event loop so those real I/O callbacks can actually fire --
    // but only for async work *started* inside it, so the tap that kicks
    // off the download must happen inside this same runAsync call too.
    await tester.runAsync(() async {
      await tester.tap(find.text('ZAKTUALIZUJ TERAZ'));
      while (installer.installedFile == null) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
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
