import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/character_repository.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/providers/character_providers.dart';

Future<FakeFirebaseFirestore> seed() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': false,
    'readOnlyOthers': false,
  });
  await db.collection('characters').add({
    'name': 'Ala',
    'email': 'ala@example.com',
    'level': 2,
    'current_xp': 10,
    'next_level_xp': 100,
    'favour': 0,
    'traits': [
      {'name': 'Siła', 'value': '10'},
    ],
  });
  await db.collection('characters').add({
    'name': 'Bob',
    'email': 'bob@example.com',
    'level': 5,
    'current_xp': 0,
    'next_level_xp': 200,
    'favour': 1,
    'traits': [
      {'name': 'Spryt', 'value': '14'},
    ],
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
  test('a plain user sees only their own characters', () async {
    final db = await seed();
    final container = containerFor(db);
    container.listen(charactersProvider, (_, _) {});
    final feed = await container.read(charactersProvider.future);
    expect(feed.characters.map((c) => c.name), ['Ala']);
  });

  test('an admin sees every character', () async {
    final db = await seed();
    await db.collection('users').doc('u1').update({'admin': true});
    final container = containerFor(db);
    container.listen(charactersProvider, (_, _) {});
    final feed = await container.read(charactersProvider.future);
    expect(feed.characters.map((c) => c.name).toSet(), {'Ala', 'Bob'});
  });

  test('a readOnlyOthers user sees every character', () async {
    final db = await seed();
    await db.collection('users').doc('u1').update({'readOnlyOthers': true});
    final container = containerFor(db);
    container.listen(charactersProvider, (_, _) {});
    final feed = await container.read(charactersProvider.future);
    expect(feed.characters.map((c) => c.name).toSet(), {'Ala', 'Bob'});
  });

  test('traitNamesProvider collects distinct names across the roster', () async {
    final db = await seed();
    await db.collection('users').doc('u1').update({'admin': true});
    final container = containerFor(db);
    container.listen(charactersProvider, (_, _) {});
    await container.read(charactersProvider.future);
    expect(container.read(traitNamesProvider).toSet(), {'Siła', 'Spryt'});
  });

  test('updateCharacter writes the snake_case fields back', () async {
    final db = await seed();
    final ref = await db.collection('characters').add({
      'name': 'Cyla',
      'email': 'c@example.com',
      'level': 1,
      'current_xp': 0,
      'next_level_xp': 50,
      'favour': 0,
      'traits': <dynamic>[],
    });
    final snap = await ref.get();
    final updated = Character.fromMap(ref.id, snap.data()!)
        .copyWith(level: 2, currentXp: 25, favour: -1);

    await CharacterRepository(db).updateCharacter(updated);

    final after = await ref.get();
    expect(after.data()!['level'], 2);
    expect(after.data()!['current_xp'], 25);
    expect(after.data()!['favour'], -1);
  });

  test('CharacterFeed reports offline when cached or pending', () {
    CharacterFeed feed({bool cache = false, bool pending = false}) => CharacterFeed(
          characters: const [],
          isFromCache: cache,
          hasPendingWrites: pending,
        );
    expect(feed().isOffline, isFalse);
    expect(feed(cache: true).isOffline, isTrue);
    expect(feed(pending: true).isOffline, isTrue);
  });
}
