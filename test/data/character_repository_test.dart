import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/character_repository.dart';
import 'package:liferpg/models/app_user.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/models/electronics_days.dart';

const _admin = AppUser(
  uid: 'u1',
  name: 'Ala',
  email: 'ala@example.com',
  admin: true,
  readOnlyOthers: false,
);

void main() {
  test(
      'a hopelessly malformed document is skipped rather than blanking the roster',
      () async {
    final db = FakeFirebaseFirestore();
    await db.collection('characters').add({
      'name': 'Ala',
      'email': 'ala@example.com',
      'level': 2,
      'current_xp': 10,
      'next_level_xp': 100,
      'favour': 0,
      'traits': <dynamic>[],
    });
    // A trait entry that is a Map but has non-String keys survives the
    // "is Map" check yet still throws inside Map<String, dynamic>.from --
    // exactly the kind of residual failure the repository must tolerate.
    await db.collection('characters').add({
      'name': 'Corrupt',
      'email': 'corrupt@example.com',
      'level': 2,
      'current_xp': 10,
      'next_level_xp': 100,
      'favour': 0,
      'traits': [
        {1: 'a', 2: 'b'},
      ],
    });
    await db.collection('characters').add({
      'name': 'Bob',
      'email': 'bob@example.com',
      'level': 5,
      'current_xp': 0,
      'next_level_xp': 200,
      'favour': 1,
      'traits': <dynamic>[],
    });

    final feed = await CharacterRepository(db).watchCharacters(_admin).first;

    expect(feed.characters.map((c) => c.name).toSet(), {'Ala', 'Bob'});
  });

  group('electronics', () {
    DateTime clock() => DateTime(2026, 10, 22, 15);

    test('claimElectronicsDay settles and claims today', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('characters').doc('c1').set({
        'name': 'Ala',
        'email': 'a@example.com',
        'electronics': {'days': 3, 'as_of': '2026-10-20', 'claimed': []},
      });
      await CharacterRepository(db, clock: clock).claimElectronicsDay('c1');

      final data = (await db.collection('characters').doc('c1').get()).data()!;
      expect(data['electronics'], {
        'days': 4,
        'as_of': '2026-10-23',
        'claimed': ['2026-10-22'],
      });
    });

    test('claimElectronicsDay works on a character with no electronics map', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('characters').doc('c1').set({'name': 'Ala', 'email': 'a@example.com'});
      await CharacterRepository(db, clock: () => DateTime(2026, 10, 13, 9))
          .claimElectronicsDay('c1');
      final e = ElectronicsDays.fromMap(
          (await db.collection('characters').doc('c1').get()).data()!['electronics']);
      expect(e.available(parseDay('2026-10-13')!), 2); // 3 accrued (10,11,12) - 1
      expect(e.isClaimed(parseDay('2026-10-13')!), isTrue);
    });

    test('setElectronicsDays writes today\'s value and keeps claimed', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('characters').doc('c1').set({
        'name': 'Ala',
        'email': 'a@example.com',
        'electronics': {'days': 3, 'as_of': '2026-10-20', 'claimed': ['2026-10-18']},
      });
      await CharacterRepository(db, clock: clock).setElectronicsDays('c1', 9);
      final data = (await db.collection('characters').doc('c1').get()).data()!;
      expect(data['electronics'], {
        'days': 9,
        'as_of': '2026-10-22',
        'claimed': ['2026-10-18'],
      });
    });

    test('a missing character throws CharacterNotFound', () async {
      final db = FakeFirebaseFirestore();
      expect(
        () => CharacterRepository(db, clock: clock).claimElectronicsDay('nope'),
        throwsA(isA<CharacterNotFound>()),
      );
    });

    test('updateCharacter leaves electronics untouched', () async {
      final db = FakeFirebaseFirestore();
      await db.collection('characters').doc('c1').set({
        'name': 'Ala',
        'email': 'a@example.com',
        'electronics': {'days': 3, 'as_of': '2026-10-20', 'claimed': []},
      });
      final snap = await db.collection('characters').doc('c1').get();
      final stale = Character.fromMap('c1', snap.data()!);
      await CharacterRepository(db, clock: clock).claimElectronicsDay('c1');
      await CharacterRepository(db, clock: clock).updateCharacter(stale.copyWith(level: 9));
      final data = (await db.collection('characters').doc('c1').get()).data()!;
      expect((data['electronics'] as Map)['days'], 4);
      expect(data['level'], 9);
    });
  });
}
