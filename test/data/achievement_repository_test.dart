import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/achievement_repository.dart';
import 'package:liferpg/data/character_repository.dart';
import 'package:liferpg/models/achievement.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/models/electronics_days.dart';

final now = DateTime(2026, 10, 12, 10);
final today = dayOf(now);

Achievement badge({String id = 'a1', AchievementReward? reward}) => Achievement(
      id: id,
      title: 'II miejsce',
      event: 'Konkurs',
      date: today,
      emblem: AchievementEmblem.place,
      place: 2,
      tier: AchievementTier.silver,
      reward: reward ??
          const AchievementReward(
            currentXp: 150,
            gold: 50,
            trait: TraitChange(name: 'Recytacja', value: '1'),
            electronicsDays: 2,
          ),
      awardedBy: 'admin',
      awardedByName: 'Tata',
      awardedAt: now,
    );

Future<FakeFirebaseFirestore> world() async {
  final db = FakeFirebaseFirestore();
  await db.collection('characters').doc('c1').set({
    'name': 'Zosia',
    'email': 'zosia@example.com',
    'current_xp': 340,
    'gold': 10,
    'traits': [
      {'name': 'Siła', 'value': '5'}
    ],
    'electronics': {'days': 1, 'as_of': formatDay(today), 'claimed': []},
  });
  return db;
}

Future<Map<String, dynamic>> character(FakeFirebaseFirestore db) async =>
    (await db.collection('characters').doc('c1').get()).data()!;

void main() {
  late FakeFirebaseFirestore db;
  late AchievementRepository repo;

  setUp(() async {
    db = await world();
    repo = AchievementRepository(db, clock: () => now);
  });

  test('award appends the badge and applies the whole reward', () async {
    await repo.award('c1', badge());
    final c = await character(db);
    expect(c['achievements'], hasLength(1));
    expect(c['achievements'][0]['id'], 'a1');
    expect(c['current_xp'], 490);
    expect(c['gold'], 60);
    expect(c['traits'], [
      {'name': 'Siła', 'value': '5'},
      {'name': 'Recytacja', 'value': '1'},
    ]);
    expect(c['electronics']['days'], 3);
  });

  test('awarding the same id twice applies it once', () async {
    await repo.award('c1', badge());
    await repo.award('c1', badge());
    final c = await character(db);
    expect(c['achievements'], hasLength(1));
    expect(c['gold'], 60);
  });

  test('an empty reward touches nothing but the list', () async {
    await repo.award('c1', badge(reward: const AchievementReward()));
    final c = await character(db);
    expect(c['gold'], 10);
    expect(c['current_xp'], 340);
  });

  test('award on a missing character throws', () async {
    expect(() => repo.award('nope', badge()),
        throwsA(isA<AchievementCharacterGone>()));
  });

  test('edit changes presentation only', () async {
    await repo.award('c1', badge());
    await repo.edit(
      'c1',
      'a1',
      AchievementDetails(
        title: 'I miejsce',
        date: today,
        emblem: AchievementEmblem.place,
        place: 1,
        tier: AchievementTier.gold,
      ),
    );
    final c = await character(db);
    final entry = c['achievements'][0] as Map;
    expect(entry['title'], 'I miejsce');
    expect(entry['tier'], 'gold');
    expect(entry.containsKey('event'), isFalse);
    expect(entry['reward']['gold'], 50);
    expect(c['gold'], 60);
  });

  test('edit of a missing badge throws AchievementGone', () async {
    expect(
      () => repo.edit(
        'c1',
        'zzz',
        AchievementDetails(
          title: 'X',
          date: today,
          emblem: AchievementEmblem.star,
          tier: AchievementTier.gold,
        ),
      ),
      throwsA(isA<AchievementGone>()),
    );
  });

  test('revoke removes the badge and reverses the reward, below zero', () async {
    await repo.award('c1', badge());
    await db.collection('characters').doc('c1').update({
      'gold': 10, // spent 50 of it meanwhile
      'electronics': {'days': 1, 'as_of': formatDay(today), 'claimed': []},
    });
    await repo.revoke('c1', 'a1');
    final c = await character(db);
    expect(c['achievements'], isEmpty);
    expect(c['current_xp'], 340);
    expect(c['gold'], -40);
    expect(c['traits'], [
      {'name': 'Siła', 'value': '5'},
      {'name': 'Recytacja', 'value': '0'},
    ]);
    expect(c['electronics']['days'], 0);
  });

  test('revoking twice reverses once', () async {
    await repo.award('c1', badge());
    await repo.revoke('c1', 'a1');
    await repo.revoke('c1', 'a1');
    expect((await character(db))['gold'], 10);
  });

  test('saving the edit screen does not wipe badges', () async {
    await repo.award('c1', badge());
    final snap = await db.collection('characters').doc('c1').get();
    final stale = Character.fromMap('c1', {...snap.data()!, 'achievements': []});
    await CharacterRepository(db).updateCharacter(stale.copyWith(name: 'Zosia K.'));
    final c = await character(db);
    expect(c['name'], 'Zosia K.');
    expect(c['achievements'], hasLength(1));
  });

  test('newId is unique per call', () {
    expect(repo.newId(), isNot(repo.newId()));
  });
}
