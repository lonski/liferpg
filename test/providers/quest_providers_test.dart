import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/providers/character_providers.dart';
import 'package:liferpg/providers/quest_providers.dart';

Future<ProviderContainer> _containerFor(FakeFirebaseFirestore db) async {
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
  test('myOwnCharacterIdsProvider returns only the signed-in user\'s own characters', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    await db.collection('characters').add({'name': 'Grommash', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': []});
    await db.collection('characters').add({'name': 'Nie moje', 'email': 'bob@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': []});

    final container = await _containerFor(db);
    container.listen(charactersProvider, (_, _) {});
    // charactersProvider must resolve first for the character-derived
    // provider to see real data.
    await container.read(charactersProvider.future);
    container.listen(myOwnCharacterIdsProvider, (_, _) {});
    container.listen(myAssignedQuestsProvider, (_, _) {});
    await container.read(myAssignedQuestsProvider.future);

    expect(container.read(myOwnCharacterIdsProvider), hasLength(1));
  });

  test('openQuestsProvider streams open quests once signed in', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    await db.collection('quests').add({
      'title': 'Posprzątaj garaż',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 50},
    });

    final container = await _containerFor(db);
    container.listen(openQuestsProvider, (_, _) {});
    final quests = await container.read(openQuestsProvider.future);

    expect(quests, hasLength(1));
    expect(quests.single.title, 'Posprzątaj garaż');
  });
}
