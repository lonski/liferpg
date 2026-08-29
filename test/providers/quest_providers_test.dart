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

  test('myAssignedQuestsProvider streams quests assigned to user\'s own character', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    final charRef = await db.collection('characters').add({
      'name': 'Grommash', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': [],
    });
    await db.collection('quests').add({
      'title': 'Ugotuj obiad',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'assignedToCharacterId': charRef.id,
      'assignedToCharacterName': 'Grommash',
      'assignedToEmail': 'ala@example.com',
      'status': 'assigned',
      'reward': {'current_xp': 30},
    });
    await db.collection('quests').add({
      'title': 'Not mine',
      'posterUid': 'u3',
      'posterEmail': 'charlie@example.com',
      'posterName': 'Charlie',
      'assignedToCharacterId': 'other',
      'status': 'assigned',
      'reward': {'current_xp': 15},
    });

    final container = await _containerFor(db);
    container.listen(charactersProvider, (_, _) {});
    await container.read(charactersProvider.future);
    container.listen(myAssignedQuestsProvider, (_, _) {});
    final assigned = await container.read(myAssignedQuestsProvider.future);

    expect(assigned, hasLength(1));
    expect(assigned.single.title, 'Ugotuj obiad');
  });

  test('myPostedQuestsProvider streams quests posted by the signed-in user', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    await db.collection('quests').add({
      'title': 'Posted by me - open',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'status': 'open',
      'reward': {'current_xp': 50},
    });
    await db.collection('quests').add({
      'title': 'Posted by me - assigned',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'assignedToCharacterId': 'c1',
      'assignedToCharacterName': 'Someone',
      'assignedToEmail': 'someone@example.com',
      'status': 'assigned',
      'reward': {'current_xp': 30},
    });
    await db.collection('quests').add({
      'title': 'Posted by someone else',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 20},
    });

    final container = await _containerFor(db);
    container.listen(myPostedQuestsProvider, (_, _) {});
    final posted = await container.read(myPostedQuestsProvider.future);

    expect(posted, hasLength(2));
    expect(posted.map((q) => q.title), containsAll(['Posted by me - open', 'Posted by me - assigned']));
  });

  test('questLogProvider streams quests in terminal statuses (completed, failed, cancelled)', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    await db.collection('quests').add({
      'title': 'Completed quest',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'completed',
      'reward': {'current_xp': 50},
    });
    await db.collection('quests').add({
      'title': 'Failed quest',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'failed',
      'reward': {'current_xp': 30},
    });
    await db.collection('quests').add({
      'title': 'Cancelled quest',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'cancelled',
      'reward': {'current_xp': 20},
    });
    await db.collection('quests').add({
      'title': 'Open quest - should not appear',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 15},
    });
    await db.collection('quests').add({
      'title': 'Assigned quest - should not appear',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'assignedToCharacterId': 'c1',
      'assignedToCharacterName': 'Someone',
      'assignedToEmail': 'someone@example.com',
      'status': 'assigned',
      'reward': {'current_xp': 10},
    });

    final container = await _containerFor(db);
    container.listen(questLogProvider, (_, _) {});
    final log = await container.read(questLogProvider.future);

    expect(log, hasLength(3));
    expect(log.map((q) => q.title), containsAll(['Completed quest', 'Failed quest', 'Cancelled quest']));
  });

  test('questRosterProvider streams quest roster entries for characters', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    await db.collection('quest_roster').doc('c1').set({
      'characterId': 'c1',
      'characterName': 'Grommash',
      'email': 'grommash@example.com',
    });
    await db.collection('quest_roster').doc('c2').set({
      'characterId': 'c2',
      'characterName': 'Ala',
      'email': 'ala@example.com',
    });

    final container = await _containerFor(db);
    container.listen(questRosterProvider, (_, _) {});
    final roster = await container.read(questRosterProvider.future);

    expect(roster, hasLength(2));
    expect(roster.map((e) => e.characterName), ['Ala', 'Grommash']);
  });

  test('openQuestsProvider yields empty list when signed out', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('quests').add({
      'title': 'Should not be visible',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 50},
    });

    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(signedIn: false)),
    ]);
    addTearDown(container.dispose);

    container.listen(openQuestsProvider, (_, _) {});
    final quests = await container.read(openQuestsProvider.future);

    expect(quests, isEmpty);
  });
}
