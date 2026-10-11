import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/boss.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/character.dart';

Character hero({String id = 'c1', String? clazz, int xp = 100, Weapon? weapon}) => Character(
  id: id,
  name: 'Zosia',
  clazz: clazz,
  email: 'zosia@example.com',
  currentXp: xp,
  nextLevelXp: 200,
  favour: 0,
  traits: const [],
  weapon: weapon,
);

void main() {
  group('Weapon.forClass', () {
    test('three classes have a default weapon, any casing', () {
      expect(Weapon.forClass('Barbarzyńca'), Weapon.maczuga);
      expect(Weapon.forClass('BARBARZYŃCA'), Weapon.maczuga);
      expect(Weapon.forClass('pani domu'), Weapon.miotla);
      expect(Weapon.forClass(' Pani Domu '), Weapon.miotla);
      expect(Weapon.forClass('Czarodziej'), Weapon.ksiega);
      expect(Weapon.forClass('czarodziejka'), Weapon.ksiega);
    });

    test('any other class has no fixed weapon', () {
      expect(Weapon.forClass('Bard'), isNull);
      expect(Weapon.forClass(null), isNull);
      expect(Weapon.forClass(''), isNull);
    });

    test("the admin's pick overrides the class's default", () {
      expect(weaponOf(hero(clazz: 'Barbarzyńca', weapon: Weapon.luk)), Weapon.luk);
      expect(weaponOf(hero(clazz: 'Barbarzyńca')), Weapon.maczuga);
      expect(weaponOf(hero(clazz: 'Bard', weapon: Weapon.luk)), Weapon.luk);
      expect(weaponOf(hero(clazz: 'Bard')), isNull);
    });
  });

  test('every weapon has the four tiers in order, with the bonus damage', () {
    for (final w in Weapon.values) {
      expect(w.blows.map((b) => b.tier), BlowTier.values);
    }
    expect([for (final t in BlowTier.values) (t.cost, t.damage)], [(1, 1), (10, 10), (50, 60), (100, 150)]);
    expect(BlowTier.of(50, 60), BlowTier.combo);
    expect(BlowTier.of(10, 60), isNull);
  });

  test('a character keeps its weapon through fromMap/toMap', () {
    final c = Character.fromMap('c1', {'name': 'Kuba', 'weapon': 'luk'});
    expect(c.weapon, Weapon.luk);
    expect(c.toMap()['weapon'], 'luk');
    expect(Character.fromMap('c1', {'weapon': 'kij'}).weapon, isNull);
    expect(c.copyWith(weapon: () => null).weapon, isNull);
    expect(c.copyWith(name: 'X').weapon, Weapon.luk);
  });

  group('Boss', () {
    final boss = Boss.fromMap('b1', {
      'name': 'Smok',
      'look': 'smok',
      'maxHp': 100,
      'hp': 72,
      'status': 'active',
      'baseline': {'c1': 60},
      'spent': {'c1': 15},
      'damage': {'c1': 15, 'c2': 13},
      'rewarded': {'c2': true},
      'reward': {
        'current_xp': 50,
        'traits': [
          {'name': 'Odwaga', 'value': '1'},
          {'name': 'Mądrość', 'value': '2'},
        ],
      },
    });

    test('energy is XP gained since the boss appeared minus what was spent', () {
      expect(boss.energyOf(hero(xp: 100)), 25);
      expect(boss.energyOf(hero(xp: 50)), 0, reason: 'never below zero');
      expect(boss.energyOf(hero(id: 'c3')), isNull, reason: 'no baseline yet');
    });

    test('reads tolerantly', () {
      final odd = Boss.fromMap('b2', {'look': 'nieznany', 'maxHp': '40', 'hp': 99, 'status': 'zly'});
      expect(odd.look, BossLook.smok);
      expect(odd.name, 'Smok Ognisty');
      expect(odd.maxHp, 40);
      expect(odd.hp, 40);
      expect(odd.status, BossStatus.cancelled);
      expect(odd.targets('anyone'), isTrue);
    });

    test('the reward keeps every trait', () {
      expect(boss.reward.traits.map((t) => t.name), ['Odwaga', 'Mądrość']);
      expect(boss.reward.parts, ['+50 XP', 'Odwaga +1', 'Mądrość +2']);
      expect(BossReward.fromMap(boss.reward.toMap()).traits.length, 2);
    });

    test('bossesFor shows live targeted bosses and uncollected wins', () {
      final mine = Boss.fromMap('m', {'status': 'active', 'targetCharacterId': 'c1', 'maxHp': 5});
      final theirs = Boss.fromMap('t', {'status': 'active', 'targetCharacterId': 'c9', 'maxHp': 5});
      final won = Boss.fromMap('w', {'status': 'defeated', 'damage': {'c1': 3}, 'maxHp': 5});
      final collected = Boss.fromMap('x', {'status': 'defeated', 'damage': {'c1': 3}, 'rewarded': {'c1': true}, 'maxHp': 5});
      final idle = Boss.fromMap('i', {'status': 'defeated', 'damage': {'c2': 3}, 'maxHp': 5});
      expect(bossesFor([mine, theirs, won, collected, idle], hero()).map((b) => b.id), ['m', 'w']);
    });
  });

  test('BossReward.toChangeSet carries every trait', () {
    const reward = BossReward(
      gold: 5,
      traits: [TraitChange(name: 'A', value: '1'), TraitChange(name: 'B', value: '3')],
    );
    expect(reward.toChangeSet().traits.length, 2);
    expect(reward.toMap(), {
      'gold': 5,
      'traits': [
        {'name': 'A', 'value': '1'},
        {'name': 'B', 'value': '3'},
      ],
    });
  });
}
