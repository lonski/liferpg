import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/providers/change_request_providers.dart';

Future<FakeFirebaseFirestore> seed({bool admin = false}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': admin,
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
  await db.collection('change_requests').add({
    'characterId': 'c2',
    'characterName': 'Bob',
    'requesterUid': 'u2',
    'requesterEmail': 'bob@example.com',
    'status': 'pending',
    'changes': {'gold': 5},
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
  test('an admin sees every pending request', () async {
    final container = containerFor(await seed(admin: true));
    // Riverpod 3: a StreamProvider stays paused until it has a listener, so
    // awaiting `.future` without this hangs forever.
    container.listen(pendingChangeRequestsProvider, (_, _) {});

    final pending = await container.read(pendingChangeRequestsProvider.future);

    expect(pending, hasLength(2));
  });

  test('a non-admin sees no pending queue', () async {
    final container = containerFor(await seed());
    container.listen(pendingChangeRequestsProvider, (_, _) {});

    final pending = await container.read(pendingChangeRequestsProvider.future);

    expect(pending, isEmpty);
  });

  test('myChangeRequestsProvider returns only the signed-in user\'s requests',
      () async {
    final container = containerFor(await seed());
    container.listen(myChangeRequestsProvider, (_, _) {});

    final mine = await container.read(myChangeRequestsProvider.future);

    expect(mine, hasLength(1));
    expect(mine.single.requesterUid, 'u1');
    expect(mine.single.status, ChangeRequestStatus.pending);
  });
}
