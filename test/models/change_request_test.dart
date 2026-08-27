import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/change_request.dart';

void main() {
  test('parses a full document', () {
    final r = ChangeRequest.fromMap('r1', {
      'characterId': 'c1',
      'characterName': 'Grommash',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'reason': 'Posprzątałem garaż',
      'createdAt': Timestamp.fromMillisecondsSinceEpoch(1000),
      'changes': {
        'current_xp': 50,
        'gold': -10,
        'gold_usd': 2.5,
        'traits': [
          {'name': 'Siła', 'value': '12'},
        ],
      },
    });

    expect(r.id, 'r1');
    expect(r.characterId, 'c1');
    expect(r.characterName, 'Grommash');
    expect(r.requesterUid, 'u1');
    expect(r.status, ChangeRequestStatus.pending);
    expect(r.reason, 'Posprzątałem garaż');
    expect(r.changes.currentXp, 50);
    expect(r.changes.gold, -10);
    expect(r.changes.goldUsd, 2.5);
    expect(r.changes.traits.single.name, 'Siła');
    expect(r.changes.traits.single.value, '12');
    expect(r.appliedChanges, isNull);
    expect(r.decidedBy, isNull);
  });

  test('tolerates numbers written as strings and a missing changes map', () {
    final r = ChangeRequest.fromMap('r2', {
      'characterId': 'c1',
      'characterName': 'Grommash',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'changes': {'current_xp': '50', 'gold': 'nonsense'},
    });

    expect(r.changes.currentXp, 50);
    expect(r.changes.gold, isNull);
    expect(r.changes.traits, isEmpty);
    expect(r.reason, isNull);
    expect(r.createdAt, isNull);
  });

  test('an unknown status parses as pending', () {
    final r = ChangeRequest.fromMap('r3', {
      'characterId': 'c1',
      'characterName': 'X',
      'requesterUid': 'u1',
      'requesterEmail': 'a@b.c',
      'status': 'weird',
      'changes': {'current_xp': 1},
    });
    expect(r.status, ChangeRequestStatus.pending);
  });

  test('toMap omits absent optional fields', () {
    final map = ChangeRequest(
      id: 'r1',
      characterId: 'c1',
      characterName: 'Grommash',
      requesterUid: 'u1',
      requesterEmail: 'ala@example.com',
      status: ChangeRequestStatus.pending,
      changes: const ChangeSet(currentXp: 50),
    ).toMap();

    expect(map['status'], 'pending');
    expect(map['changes'], {'current_xp': 50});
    expect(map.containsKey('reason'), isFalse);
    expect(map.containsKey('appliedChanges'), isFalse);
    expect(map.containsKey('decidedBy'), isFalse);
    expect(map.containsKey('decidedAt'), isFalse);
  });

  test('an empty ChangeSet is reported empty', () {
    expect(const ChangeSet().isEmpty, isTrue);
    expect(const ChangeSet(currentXp: 0).isEmpty, isFalse);
    expect(
      const ChangeSet(traits: [TraitChange(name: 'Siła', value: '1')]).isEmpty,
      isFalse,
    );
  });
}
