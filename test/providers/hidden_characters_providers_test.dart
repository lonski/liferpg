import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/providers/auth_providers.dart';
import 'package:liferpg/providers/hidden_characters_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FakeFirebaseFirestore> seed({String uid = 'u1'}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc(uid).set({
    'uid': uid,
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': true,
    'readOnlyOthers': false,
  });
  return db;
}

Future<ProviderContainer> containerFor(
  FakeFirebaseFirestore db, {
  String uid = 'u1',
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, email: 'ala@example.com'),
    )),
    sharedPreferencesProvider.overrideWithValue(
      await SharedPreferences.getInstance(),
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts empty when nothing was ever hidden', () async {
    final container = await containerFor(await seed());
    container.listen(hiddenCharacterIdsProvider, (_, _) {});

    // Let appUserProvider's stream resolve before reading state.
    await container.read(appUserProvider.future);

    expect(container.read(hiddenCharacterIdsProvider), isEmpty);
  });

  test('hide adds a character id to the set', () async {
    final container = await containerFor(await seed());
    container.listen(hiddenCharacterIdsProvider, (_, _) {});
    await container.read(appUserProvider.future);

    container.read(hiddenCharacterIdsProvider.notifier).hide('c1');

    expect(container.read(hiddenCharacterIdsProvider), {'c1'});
  });

  test('unhide removes a character id from the set', () async {
    final container = await containerFor(await seed());
    container.listen(hiddenCharacterIdsProvider, (_, _) {});
    await container.read(appUserProvider.future);

    container.read(hiddenCharacterIdsProvider.notifier).hide('c1');
    container.read(hiddenCharacterIdsProvider.notifier).unhide('c1');

    expect(container.read(hiddenCharacterIdsProvider), isEmpty);
  });

  test('hiding persists across a fresh provider container for the same uid',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = await seed();

    final first = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    first.listen(hiddenCharacterIdsProvider, (_, _) {});
    await first.read(appUserProvider.future);
    first.read(hiddenCharacterIdsProvider.notifier).hide('c1');
    first.dispose();

    final second = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ]);
    addTearDown(second.dispose);
    second.listen(hiddenCharacterIdsProvider, (_, _) {});
    await second.read(appUserProvider.future);

    expect(second.read(hiddenCharacterIdsProvider), {'c1'});
  });
}
