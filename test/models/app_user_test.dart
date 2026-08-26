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
}
