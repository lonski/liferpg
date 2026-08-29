import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/change_request_repository.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/character.dart';

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

  Future<String> seedCharacter(
    FakeFirebaseFirestore db, {
    Map<String, dynamic> extra = const {},
  }) async {
    final ref = await db.collection('characters').add({
      'name': 'Grommash',
      'email': 'ala@example.com',
      'level': 3,
      'current_xp': 40,
      'next_level_xp': 100,
      'favour': 0,
      'traits': <dynamic>[],
      ...extra,
    });
    return ref.id;
  }

  Future<ChangeRequest> onlyRequest(FakeFirebaseFirestore db) async {
    final docs = await db.collection('change_requests').get();
    final d = docs.docs.single;
    return ChangeRequest.fromMap(d.id, d.data());
  }

  test('accept adds the deltas to the character and marks the request',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db, extra: {'gold': 100});
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(currentXp: 50, gold: -10),
    ));

    await repo.accept(await onlyRequest(db), adminUid: 'admin1');

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 90);
    expect(character['gold'], 90);

    final decided = await onlyRequest(db);
    expect(decided.status, ChangeRequestStatus.accepted);
    expect(decided.decidedBy, 'admin1');
    expect(decided.decidedAt, isNotNull);
    expect(decided.appliedChanges!.currentXp, 50);
    expect(decided.appliedChanges!.gold, -10);
  });

  test('a delta against an absent field materialises it from zero', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    // No `gold` key at all on this character.
    final characterId = await seedCharacter(db);
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(gold: 10),
    ));

    await repo.accept(await onlyRequest(db), adminUid: 'admin1');

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['gold'], 10);
  });

  test(
      'trait changes add to an existing name\'s value and set a new one\'s '
      'starting value', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db, extra: {
      'traits': [
        {'name': 'Siła', 'value': '10'},
      ],
    });
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(traits: [
        TraitChange(name: 'Siła', value: '12'),
        TraitChange(name: 'Spryt', value: '7'),
      ]),
    ));

    await repo.accept(await onlyRequest(db), adminUid: 'admin1');

    final character = Character.fromMap(
      characterId,
      (await db.collection('characters').doc(characterId).get()).data()!,
    );
    expect(character.traits.map((t) => '${t.name}=${t.value}').toList(),
        ['Siła=22', 'Spryt=7']);
  });

  test('a non-numeric existing trait value is treated as 0 before adding',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db, extra: {
      'traits': [
        {'name': 'Klasa', 'value': 'Wojownik'},
      ],
    });
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(
        traits: [TraitChange(name: 'Klasa', value: '5')],
      ),
    ));

    await repo.accept(await onlyRequest(db), adminUid: 'admin1');

    final character = Character.fromMap(
      characterId,
      (await db.collection('characters').doc(characterId).get()).data()!,
    );
    expect(character.traits.single.value, '5');
  });

  test('overrides are applied and recorded while changes are preserved',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(currentXp: 50),
    ));

    await repo.accept(
      await onlyRequest(db),
      overrides: const ChangeSet(currentXp: 20),
      adminUid: 'admin1',
    );

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 60);

    final decided = await onlyRequest(db);
    expect(decided.changes.currentXp, 50, reason: 'original ask is preserved');
    expect(decided.appliedChanges!.currentXp, 20);
  });

  test('accepting an already-decided request throws and does not re-apply',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(currentXp: 50),
    ));
    final stale = await onlyRequest(db);
    await repo.accept(stale, adminUid: 'admin1');

    // `stale` still says pending — exactly the double-tap / stale-list case.
    await expectLater(
      repo.accept(stale, adminUid: 'admin1'),
      throwsA(isA<ChangeRequestNoLongerPending>()),
    );

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 90, reason: 'applied exactly once');
  });

  test('reject marks the request without touching the character', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(
      characterId: characterId,
      changes: const ChangeSet(currentXp: 50),
    ));

    await repo.reject(await onlyRequest(db), adminUid: 'admin1');

    final decided = await onlyRequest(db);
    expect(decided.status, ChangeRequestStatus.rejected);
    expect(decided.decidedBy, 'admin1');
    expect(decided.appliedChanges, isNull);
    expect(decided.rejectionReason, isNull);

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 40, reason: 'untouched');
  });

  test('reject records an optional reason', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(characterId: characterId));

    await repo.reject(
      await onlyRequest(db),
      adminUid: 'admin1',
      reason: 'Za mało szczegółów',
    );

    final decided = await onlyRequest(db);
    expect(decided.rejectionReason, 'Za mało szczegółów');
  });

  test('restoreToPending flips a rejected request back to pending',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(characterId: characterId));
    await repo.reject(
      await onlyRequest(db),
      adminUid: 'admin1',
      reason: 'Za mało szczegółów',
    );

    await repo.restoreToPending(await onlyRequest(db));

    final restored = await onlyRequest(db);
    expect(restored.status, ChangeRequestStatus.pending);
    expect(restored.decidedBy, isNull);
    expect(restored.decidedAt, isNull);
    expect(restored.rejectionReason, isNull,
        reason: 'a stale reason must not survive a restore');
  });

  test('restoreToPending un-fails a linked quest back to pending_review',
      () async {
    final db = FakeFirebaseFirestore();
    final questRef = await db.collection('quests').add({
      'title': 'Umyj okna',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'assignedToCharacterId': 'c1',
      'status': 'pending_review',
      'reward': {'current_xp': 25},
    });
    final repo = ChangeRequestRepository(db);
    await repo.create(ChangeRequest(
      id: '',
      characterId: 'c1',
      characterName: 'Grommash',
      requesterUid: 'u1',
      requesterEmail: 'ala@example.com',
      status: ChangeRequestStatus.pending,
      changes: const ChangeSet(currentXp: 25),
      questId: questRef.id,
      questTitle: 'Umyj okna',
    ));
    final saved = (await repo.watchPending().first).single;
    await repo.reject(saved, adminUid: 'admin1');
    final questAfterReject =
        await db.collection('quests').doc(questRef.id).get();
    expect(questAfterReject.data()!['status'], 'failed');

    await repo.restoreToPending(await onlyRequest(db));

    final questAfterRestore =
        await db.collection('quests').doc(questRef.id).get();
    expect(questAfterRestore.data()!['status'], 'pending_review');
  });

  test('restoreToPending on a non-quest request does not touch /quests',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(characterId: characterId));
    await repo.reject(await onlyRequest(db), adminUid: 'admin1');

    await repo.restoreToPending(await onlyRequest(db));

    expect((await db.collection('quests').get()).docs, isEmpty);
  });

  test('restoreToPending throws if the request is not rejected', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(characterId: characterId));

    await expectLater(
      repo.restoreToPending(await onlyRequest(db)),
      throwsA(isA<ChangeRequestNotRejected>()),
    );
  });

  test('cancel marks a pending request cancelled', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(characterId: characterId));

    await repo.cancel(await onlyRequest(db));

    final cancelled = await onlyRequest(db);
    expect(cancelled.status, ChangeRequestStatus.cancelled);
  });

  test('cancel throws if the request is already decided', () async {
    final db = FakeFirebaseFirestore();
    final repo = ChangeRequestRepository(db);
    final characterId = await seedCharacter(db);
    await repo.create(_request(characterId: characterId));
    await repo.reject(await onlyRequest(db), adminUid: 'admin1');

    await expectLater(
      repo.cancel(await onlyRequest(db)),
      throwsA(isA<ChangeRequestNoLongerPending>()),
    );
  });

  test('accept flips a linked quest to completed', () async {
    final db = FakeFirebaseFirestore();
    final questRef = await db.collection('quests').add({
      'title': 'Posprzątaj garaż',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'assignedToCharacterId': 'c1',
      'status': 'pending_review',
      'reward': {'current_xp': 50},
    });
    await db.collection('characters').doc('c1').set({
      'name': 'Grommash',
      'email': 'ala@example.com',
      'current_xp': 10,
    });
    final request = _request(characterId: 'c1', changes: const ChangeSet(currentXp: 50));
    final repo = ChangeRequestRepository(db);
    await repo.create(ChangeRequest(
      id: '',
      characterId: request.characterId,
      characterName: request.characterName,
      requesterUid: request.requesterUid,
      requesterEmail: request.requesterEmail,
      status: ChangeRequestStatus.pending,
      changes: request.changes,
      questId: questRef.id,
      questTitle: 'Posprzątaj garaż',
    ));
    final saved = (await repo.watchPending().first).single;

    await repo.accept(saved, adminUid: 'admin1');

    final questDoc = await db.collection('quests').doc(questRef.id).get();
    expect(questDoc.data()!['status'], 'completed');
  });

  test('reject flips a linked quest to failed', () async {
    final db = FakeFirebaseFirestore();
    final questRef = await db.collection('quests').add({
      'title': 'Umyj okna',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'assignedToCharacterId': 'c1',
      'status': 'pending_review',
      'reward': {'current_xp': 25},
    });
    final repo = ChangeRequestRepository(db);
    await repo.create(ChangeRequest(
      id: '',
      characterId: 'c1',
      characterName: 'Grommash',
      requesterUid: 'u1',
      requesterEmail: 'ala@example.com',
      status: ChangeRequestStatus.pending,
      changes: const ChangeSet(currentXp: 25),
      questId: questRef.id,
      questTitle: 'Umyj okna',
    ));
    final saved = (await repo.watchPending().first).single;

    await repo.reject(saved, adminUid: 'admin1');

    final questDoc = await db.collection('quests').doc(questRef.id).get();
    expect(questDoc.data()!['status'], 'failed');
  });

  test('accept on a request with no questId does not touch /quests', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('characters').doc('c1').set({
      'name': 'Grommash',
      'email': 'ala@example.com',
      'current_xp': 10,
    });
    final repo = ChangeRequestRepository(db);
    await repo.create(_request(characterId: 'c1'));
    final saved = (await repo.watchPending().first).single;

    await repo.accept(saved, adminUid: 'admin1');

    expect((await db.collection('quests').get()).docs, isEmpty);
  });
}
