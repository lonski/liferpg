import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/change_request_notification_service.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/providers/change_request_notification_providers.dart';
import 'package:liferpg/providers/change_request_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Shown {
  _Shown(this.id, this.title, this.body, this.payload);
  final String id;
  final String title;
  final String body;
  final String payload;
}

class FakeChangeRequestNotificationService implements ChangeRequestNotificationService {
  final shown = <_Shown>[];

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    required String payload,
  }) async {
    shown.add(_Shown(id, title, body, payload));
  }
}

Future<ProviderContainer> containerFor(
  FakeFirebaseFirestore db, {
  required String uid,
  required String email,
  required bool admin,
  required FakeChangeRequestNotificationService service,
}) async {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, email: email),
    )),
    sharedPreferencesProvider.overrideWithValue(
      await SharedPreferences.getInstance(),
    ),
    changeRequestNotificationServiceProvider.overrideWithValue(service),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a pre-existing pending request does not notify on first load', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('admin1').set({
      'uid': 'admin1',
      'name': 'Admin',
      'email': 'admin@example.com',
      'admin': true,
      'readOnlyOthers': false,
    });
    await db.collection('change_requests').add({
      'characterId': 'c1',
      'characterName': 'Grommash',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'changes': {'current_xp': 50},
    });
    final service = FakeChangeRequestNotificationService();
    final container = await containerFor(
      db,
      uid: 'admin1',
      email: 'admin@example.com',
      admin: true,
      service: service,
    );
    container.listen(changeRequestNotificationsProvider, (_, _) {});

    await container.read(pendingChangeRequestsProvider.future);
    // Let the listener's reaction to the first emission run.
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, isEmpty);
  });

  test('a newly created pending request notifies the admin', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('admin1').set({
      'uid': 'admin1',
      'name': 'Admin',
      'email': 'admin@example.com',
      'admin': true,
      'readOnlyOthers': false,
    });
    final service = FakeChangeRequestNotificationService();
    final container = await containerFor(
      db,
      uid: 'admin1',
      email: 'admin@example.com',
      admin: true,
      service: service,
    );
    container.listen(changeRequestNotificationsProvider, (_, _) {});

    await container.read(pendingChangeRequestsProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(service.shown, isEmpty);

    await db.collection('change_requests').add({
      'characterId': 'c1',
      'characterName': 'Grommash',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'changes': {'current_xp': 50},
    });
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, hasLength(1));
    expect(service.shown.single.payload, 'admin_queue');
    // Character name only -- the requester's email is not this admin's
    // business to see in a notification body.
    expect(service.shown.single.body, 'Grommash');
  });

  test('a request accepted since the last check notifies the requester',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1',
      'name': 'Ala',
      'email': 'ala@example.com',
      'admin': false,
      'readOnlyOthers': false,
    });
    final ref = await db.collection('change_requests').add({
      'characterId': 'c1',
      'characterName': 'Grommash',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'changes': {'current_xp': 50},
    });
    final service = FakeChangeRequestNotificationService();
    final container = await containerFor(
      db,
      uid: 'u1',
      email: 'ala@example.com',
      admin: false,
      service: service,
    );
    container.listen(changeRequestNotificationsProvider, (_, _) {});

    await container.read(myChangeRequestsProvider.future);
    await Future<void>.delayed(Duration.zero);
    expect(service.shown, isEmpty);

    await ref.update({'status': 'accepted'});
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, hasLength(1));
    expect(service.shown.single.payload, 'my_requests');
  });

  test('a request rejected before this device ever saw it pending does not notify',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1',
      'name': 'Ala',
      'email': 'ala@example.com',
      'admin': false,
      'readOnlyOthers': false,
    });
    await db.collection('change_requests').add({
      'characterId': 'c1',
      'characterName': 'Grommash',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'rejected',
      'changes': {'current_xp': 50},
    });
    final service = FakeChangeRequestNotificationService();
    final container = await containerFor(
      db,
      uid: 'u1',
      email: 'ala@example.com',
      admin: false,
      service: service,
    );
    container.listen(changeRequestNotificationsProvider, (_, _) {});

    await container.read(myChangeRequestsProvider.future);
    await Future<void>.delayed(Duration.zero);

    expect(service.shown, isEmpty);
  });
}
