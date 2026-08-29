import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/change_request_notification_service.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/providers/change_request_notification_providers.dart';
import 'package:liferpg/providers/quest_notification_providers.dart';
import 'package:liferpg/providers/quest_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeNotificationService implements ChangeRequestNotificationService {
  final shown = <String>[];

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    required String payload,
  }) async {
    shown.add(id);
  }
}

Future<ProviderContainer> _containerFor(
  FakeFirebaseFirestore db, {
  required String uid,
  required String email,
  required FakeNotificationService service,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, email: email),
    )),
    sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance()),
    changeRequestNotificationServiceProvider.overrideWithValue(service),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a new open board quest from someone else notifies once', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    final service = FakeNotificationService();
    final container = await _containerFor(db, uid: 'u1', email: 'ala@example.com', service: service);
    container.listen(questNotificationsProvider, (_, _) {});

    await container.read(openQuestsProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(service.shown, isEmpty);

    final questRef = await db.collection('quests').add({
      'title': 'Posprzątaj garaż',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 50},
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, contains('quest_open_${questRef.id}'));
  });

  test('a poster is not notified about their own board posting', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    final service = FakeNotificationService();
    final container = await _containerFor(db, uid: 'u1', email: 'ala@example.com', service: service);
    container.listen(questNotificationsProvider, (_, _) {});
    await container.read(openQuestsProvider.future);
    await Future<void>.delayed(Duration.zero);

    await db.collection('quests').add({
      'title': 'Zrób pranie',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'status': 'open',
      'reward': {'current_xp': 20},
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, isEmpty);
  });

  test('a quest assigned directly to my character notifies me', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    await db.collection('characters').doc('c1').set({
      'name': 'Grommash', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': [],
    });
    final service = FakeNotificationService();
    final container = await _containerFor(db, uid: 'u1', email: 'ala@example.com', service: service);
    container.listen(questNotificationsProvider, (_, _) {});
    await container.read(myAssignedQuestsProvider.future);
    await Future<void>.delayed(Duration.zero);

    final questRef = await db.collection('quests').add({
      'title': 'Ugotuj obiad',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'assignedToCharacterId': 'c1',
      'assignedToCharacterName': 'Grommash',
      'assignedToEmail': 'ala@example.com',
      'status': 'assigned',
      'reward': {'current_xp': 30},
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, contains('quest_assigned_${questRef.id}'));
  });

  test('a board quest I posted being taken notifies me', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    final questRef = await db.collection('quests').add({
      'title': 'Wynieś śmieci',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'status': 'open',
      'reward': {'current_xp': 15},
    });
    final service = FakeNotificationService();
    final container = await _containerFor(db, uid: 'u1', email: 'ala@example.com', service: service);
    container.listen(questNotificationsProvider, (_, _) {});
    await container.read(myPostedQuestsProvider.future);
    await Future<void>.delayed(Duration.zero);

    await questRef.update({
      'status': 'assigned',
      'assignedToCharacterId': 'c2',
      'assignedToCharacterName': 'Bob the Bold',
      'assignedToEmail': 'bob@example.com',
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, contains('quest_taken_${questRef.id}'));
  });

  test(
      'a quest created already assigned to my own character does not notify "someone took it"',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    final service = FakeNotificationService();
    final container = await _containerFor(db, uid: 'u1', email: 'ala@example.com', service: service);
    container.listen(questNotificationsProvider, (_, _) {});
    await container.read(myPostedQuestsProvider.future);
    await Future<void>.delayed(Duration.zero);

    // A direct self-assignment: posted and assigned in the same create, to
    // the poster's own character -- never `open` at any point.
    await db.collection('quests').add({
      'title': 'Zrób pranie',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'assignedToCharacterId': 'c1',
      'assignedToCharacterName': 'Grommash',
      'assignedToEmail': 'ala@example.com',
      'status': 'assigned',
      'reward': {'current_xp': 20},
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, isEmpty);
  });
}
