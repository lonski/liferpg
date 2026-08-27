import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/change_request_repository.dart';
import 'package:liferpg/models/change_request.dart';

ChangeRequest _request({
  String characterId = 'c1',
  String requesterUid = 'u1',
  ChangeSet changes = const ChangeSet(currentXp: 50),
  String? reason,
}) =>
    ChangeRequest(
      id: '',
      characterId: characterId,
      characterName: 'Grommash',
      requesterUid: requesterUid,
      requesterEmail: 'ala@example.com',
      status: ChangeRequestStatus.pending,
      changes: changes,
      reason: reason,
    );

void main() {
  test('create writes a pending request with a server timestamp', () async {
    final db = FakeFirebaseFirestore();
    await ChangeRequestRepository(db).create(_request(reason: 'Za sprzątanie'));

    final docs = await db.collection('change_requests').get();
    expect(docs.docs, hasLength(1));
    final data = docs.docs.single.data();
    expect(data['status'], 'pending');
    expect(data['characterId'], 'c1');
    expect(data['requesterUid'], 'u1');
    expect(data['reason'], 'Za sprzątanie');
    expect(data['changes'], {'current_xp': 50});
    expect(data['createdAt'], isNotNull);
  });

  test('watchPending returns only pending requests', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    await repo.create(_request());
    await db.collection('change_requests').add({
      'characterId': 'c2',
      'characterName': 'Bob',
      'requesterUid': 'u2',
      'requesterEmail': 'bob@example.com',
      'status': 'accepted',
      'changes': {'gold': 5},
    });

    final pending = await repo.watchPending().first;

    expect(pending, hasLength(1));
    expect(pending.single.characterId, 'c1');
  });

  test('watchForRequester returns only that user\'s requests', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    await repo.create(_request(requesterUid: 'u1'));
    await repo.create(_request(requesterUid: 'u2'));

    final mine = await repo.watchForRequester('u1').first;

    expect(mine, hasLength(1));
    expect(mine.single.requesterUid, 'u1');
  });

  test('a malformed document is skipped rather than blanking the queue',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    await repo.create(_request());
    // A trait entry that is a Map with non-String keys survives the "is Map"
    // check yet throws inside Map<String, dynamic>.from.
    await db.collection('change_requests').add({
      'characterId': 'c9',
      'characterName': 'Corrupt',
      'requesterUid': 'u9',
      'requesterEmail': 'x@example.com',
      'status': 'pending',
      'changes': {
        'traits': [
          {1: 'a', 2: 'b'},
        ],
      },
    });

    final pending = await repo.watchPending().first;

    expect(pending, hasLength(1));
    expect(pending.single.characterId, 'c1');
  });
}
