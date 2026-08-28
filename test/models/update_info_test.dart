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
