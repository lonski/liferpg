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
    headers: const {'content-type': 'application/json'},
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
