import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/character.dart';

Map<String, dynamic> raw() => {
      'name': 'Grommash',
      'clazz': 'Wojownik',
      'email': 'g@example.com',
      'level': 3,
      'current_xp': 40,
      'next_level_xp': 100,
      'gold': 250,
      'gold_usd': 12,
      'favour': -2,
      'traits': [
        {'name': 'Siła', 'value': '18'},
      ],
    };

void main() {
  test('fromMap reads the snake_case Firestore fields', () {
    final c = Character.fromMap('abc', raw());
    expect(c.id, 'abc');
    expect(c.clazz, 'Wojownik');
    expect(c.currentXp, 40);
    expect(c.nextLevelXp, 100);
    expect(c.goldUsd, 12);
    expect(c.favour, -2);
    expect(c.traits.single.name, 'Siła');
  });

  test('missing optional fields fall back safely', () {
    final c = Character.fromMap('abc', {'name': 'X', 'email': 'x@example.com'});
    expect(c.level, isNull);
    expect(c.gold, isNull);
    expect(c.favour, 0);
    expect(c.traits, isEmpty);
    expect(c.xpFraction, 0.0);
  });

  test('xpFraction is clamped to 1.0 and never divides by zero', () {
    expect(Character.fromMap('a', raw()).xpFraction, closeTo(0.4, 1e-9));
    final over = Character.fromMap('a', {...raw(), 'current_xp': 500});
    expect(over.xpFraction, 1.0);
    final zero = Character.fromMap('a', {...raw(), 'next_level_xp': 0});
    expect(zero.xpFraction, 0.0);
  });

  test('xpRemaining is the gap to the next level', () {
    expect(Character.fromMap('a', raw()).xpRemaining, 60);
  });

  test('toMap round-trips through fromMap', () {
    final c = Character.fromMap('abc', raw());
    final back = Character.fromMap('abc', c.toMap());
    expect(back.name, c.name);
    expect(back.currentXp, c.currentXp);
    expect(back.traits.single.value, '18');
  });

  test('copyWith replaces only what it is given', () {
    final c = Character.fromMap('abc', raw());
    final bumped = c.copyWith(level: 4, favour: 1);
    expect(bumped.level, 4);
    expect(bumped.favour, 1);
    expect(bumped.name, 'Grommash');
  });
}
