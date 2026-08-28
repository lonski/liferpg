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
