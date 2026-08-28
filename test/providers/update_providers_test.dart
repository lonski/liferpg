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
