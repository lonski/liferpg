import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/user_repository.dart';
import 'package:liferpg/providers/user_providers.dart';

Future<FakeFirebaseFirestore> seed({required bool admin}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': admin,
    'readOnlyOthers': false,
  });
  await db.collection('users').doc('u2').set({
    'uid': 'u2',
    'name': 'Bob',
    'email': 'bob@example.com',
    'admin': false,
    'readOnlyOthers': false,
  });
  return db;
}

ProviderContainer containerFor(FakeFirebaseFirestore db) {
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
    )),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('usersProvider lists everyone for an admin', () async {
    final container = containerFor(await seed(admin: true));
    container.listen(usersProvider, (_, _) {});
    final users = await container.read(usersProvider.future);
    expect(users.map((u) => u.uid).toSet(), {'u1', 'u2'});
  });

  test('usersProvider is empty for a non-admin', () async {
    final container = containerFor(await seed(admin: false));
    container.listen(usersProvider, (_, _) {});
    final users = await container.read(usersProvider.future);
    expect(users, isEmpty);
  });

  test('updateUserFlags writes only the given flags', () async {
    final db = await seed(admin: true);
    await UserRepository(db).updateUserFlags('u2', {'readOnlyOthers': true});
    final snap = await db.collection('users').doc('u2').get();
    expect(snap.data()!['readOnlyOthers'], isTrue);
    expect(snap.data()!['name'], 'Bob', reason: 'other fields must survive');
  });
}
