import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/app_user.dart';

void main() {
  test('fromMap reads flags and defaults them to false', () {
    final user = AppUser.fromMap('u1', {
      'name': 'Ala',
      'email': 'ala@example.com',
      'admin': true,
    });
    expect(user.uid, 'u1');
    expect(user.name, 'Ala');
    expect(user.email, 'ala@example.com');
    expect(user.admin, isTrue);
    expect(user.readOnlyOthers, isFalse);
  });

  test('admins and readOnlyOthers users both see all characters', () {
    AppUser make({bool admin = false, bool ro = false}) => AppUser(
          uid: 'u',
          name: 'n',
          email: 'e',
          admin: admin,
          readOnlyOthers: ro,
        );
    expect(make().canSeeAllCharacters, isFalse);
    expect(make(admin: true).canSeeAllCharacters, isTrue);
    expect(make(ro: true).canSeeAllCharacters, isTrue);
  });

  test('only admins may edit', () {
    const readOnly = AppUser(
        uid: 'u', name: 'n', email: 'e', admin: false, readOnlyOthers: true);
    const admin = AppUser(
        uid: 'u', name: 'n', email: 'e', admin: true, readOnlyOthers: false);
    expect(readOnly.canEdit, isFalse);
    expect(admin.canEdit, isTrue);
  });

  test('admin stored as the String "true" parses to true', () {
    final user = AppUser.fromMap('u1', {
      'name': 'Ala',
      'email': 'ala@example.com',
      'admin': 'true',
    });
    expect(user.admin, isTrue);
  });

  test('a missing or garbage admin value is false', () {
    final missing = AppUser.fromMap('u1', {'name': 'Ala', 'email': 'a@e.com'});
    expect(missing.admin, isFalse);
    final garbage = AppUser.fromMap(
        'u1', {'name': 'Ala', 'email': 'a@e.com', 'admin': 42});
    // 42 as a num is non-zero -> true per _asBool's documented contract.
    expect(garbage.admin, isTrue);
    final map = AppUser.fromMap(
        'u1', {'name': 'Ala', 'email': 'a@e.com', 'admin': <String, dynamic>{}});
    expect(map.admin, isFalse);
  });
}
