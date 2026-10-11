import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/boss_repository.dart';
import 'package:liferpg/models/boss.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/character.dart';

const reward = BossReward(
  currentXp: 50,
  gold: 20,
  traits: [TraitChange(name: 'Odwaga', value: '1'), TraitChange(name: 'Mądrość', value: '2')],
);

Future<FakeFirebaseFirestore> world() async {
  final db = FakeFirebaseFirestore();
  await db.collection('characters').doc('c1').set({
    'name': 'Zosia',
    'email': 'zosia@example.com',
    'current_xp': 100,
    'gold': 10,
    'traits': [
      {'name': 'Odwaga', 'value': '3'},
    ],
  });
  await db.collection('characters').doc('c2').set({'name': 'Kuba', 'email': 'kuba@example.com', 'current_xp': 7});
  return db;
}

Future<Character> load(FakeFirebaseFirestore db, String id) async =>
    Character.fromMap(id, (await db.collection('characters').doc(id).get()).data()!);

void main() {
  late FakeFirebaseFirestore db;
  late BossRepository repo;

  setUp(() async {
    db = await world();
    repo = BossRepository(db);
  });

  Future<Boss> summon({int hp = 100, Character? target}) async {
    final roster = [await load(db, 'c1'), await load(db, 'c2')];
    await repo.summon(
      name: 'Smok Ognisty',
      look: BossLook.smok,
      hp: hp,
      reward: reward,
      target: target,
      targets: target == null ? roster : [target],
      createdBy: 'admin',
      createdByName: 'Tata',
    );
    return (await repo.watchLive().first).single;
  }

  Future<Boss> reload(String id) async =>
      Boss.fromMap(id, (await db.collection('bosses').doc(id).get()).data()!);

  Future<void> earn(String id, int xp) =>
      db.collection('characters').doc(id).update({'current_xp': xp});

  test('summon records every target\'s XP as its baseline', () async {
    final boss = await summon();
    expect(boss.baseline, {'c1': 100, 'c2': 7});
    expect(boss.hp, 100);
    expect(boss.isActive, isTrue);
    expect(boss.reward.traits.length, 2);
    expect(boss.energyOf(await load(db, 'c1')), 0);
  });

  test('a blow spends energy and takes its damage off the HP', () async {
    final boss = await summon();
    await earn('c1', 160); // 60 energy
    final out = await repo.attack(bossId: boss.id, characterId: 'c1', characterName: 'Zosia', tier: BlowTier.combo);
    expect(out.damage, 60);
    final after = await reload(boss.id);
    expect(after.hp, 40);
    expect(after.spent['c1'], 50);
    expect(after.damage['c1'], 60);
    expect(after.energyOf(await load(db, 'c1')), 10);
    expect(after.lastAttackerName, 'Zosia');
  });

  test('a blow the energy cannot pay is refused and changes nothing', () async {
    final boss = await summon();
    await earn('c1', 105);
    expect(
      () => repo.attack(bossId: boss.id, characterId: 'c1', characterName: 'Zosia', tier: BlowTier.strong),
      throwsA(isA<NotEnoughEnergy>()),
    );
    expect((await reload(boss.id)).hp, 100);
  });

  test('the killing blow beats the boss, and it cannot be hit again', () async {
    final boss = await summon(hp: 8);
    await earn('c1', 200);
    final out = await repo.attack(bossId: boss.id, characterId: 'c1', characterName: 'Zosia', tier: BlowTier.strong);
    expect(out.defeated, isTrue);
    final after = await reload(boss.id);
    expect(after.hp, 0);
    expect(after.status, BossStatus.defeated);
    expect(
      () => repo.attack(bossId: boss.id, characterId: 'c1', characterName: 'Zosia', tier: BlowTier.basic),
      throwsA(isA<BossGone>()),
    );
  });

  test('a boss for one character refuses everybody else', () async {
    final boss = await summon(target: await load(db, 'c2'));
    await earn('c1', 200);
    expect(boss.targetCharacterName, 'Kuba');
    expect(
      () => repo.attack(bossId: boss.id, characterId: 'c1', characterName: 'Zosia', tier: BlowTier.basic),
      throwsA(isA<BossGone>()),
    );
  });

  test('a late character joins with its current XP, once', () async {
    final boss = await summon(target: null);
    await db.collection('bosses').doc(boss.id).update({'baseline': {'c2': 7}});
    await repo.join(boss.id, 'c1');
    expect((await reload(boss.id)).baseline['c1'], 100);
    await earn('c1', 150);
    await repo.join(boss.id, 'c1');
    expect((await reload(boss.id)).baseline['c1'], 100, reason: 'a second join changes nothing');
  });

  test('a fighter collects the whole reward once, every trait included', () async {
    final boss = await summon(hp: 1);
    await earn('c1', 101);
    await repo.attack(bossId: boss.id, characterId: 'c1', characterName: 'Zosia', tier: BlowTier.basic);
    await repo.claimReward(boss.id, 'c1');
    final c1 = await load(db, 'c1');
    expect(c1.currentXp, 151);
    expect(c1.gold, 30);
    expect(c1.traits.map((t) => '${t.name}=${t.value}'), ['Odwaga=4', 'Mądrość=2']);
    expect((await reload(boss.id)).rewarded, {'c1'});
    expect(() => repo.claimReward(boss.id, 'c1'), throwsA(isA<BossRewardNotAvailable>()));
    expect(() => repo.claimReward(boss.id, 'c2'), throwsA(isA<BossRewardNotAvailable>()),
        reason: 'Kuba never hit it');
  });

  test('a cancelled boss leaves the live list', () async {
    final boss = await summon();
    await repo.cancel(boss.id);
    expect(await repo.watchLive().first, isEmpty);
  });
}
