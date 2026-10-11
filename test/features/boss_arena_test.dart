import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/bosses/boss_arena.dart';
import 'package:liferpg/features/bosses/boss_art.dart';
import 'package:liferpg/features/bosses/summon_boss_screen.dart';
import 'package:liferpg/providers/achievement_providers.dart';
import 'package:liferpg/providers/auth_providers.dart';
import 'package:liferpg/providers/boss_providers.dart';

import 'achievements_test_support.dart';

/// The arenas under character c1, as the home screen lays them out.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(characterByIdProvider('c1'));
    final user = ref.watch(appUserProvider).value;
    if (c == null || user == null) return const Scaffold();
    return Scaffold(
      body: ListView(
        children: [
          for (final boss in ref.watch(bossesForCharacterProvider('c1')))
            BossArena(
              key: ValueKey(boss.id),
              boss: boss,
              character: c,
              canFight: c.email == user.email,
              isAdmin: user.admin,
            ),
        ],
      ),
    );
  }
}

Future<FakeFirebaseFirestore> world({
  String clazz = 'Barbarzyńca',
  Map<String, dynamic> boss = const {},
}) async {
  final db = await seedWorld();
  // 340 XP now, 300 when the boss appeared: 40 energy.
  await db.collection('characters').doc('c1').update({'clazz': clazz});
  await db.collection('bosses').doc('b1').set({
    'name': 'Smok Ognisty',
    'look': 'smok',
    'maxHp': 100,
    'hp': 100,
    'status': 'active',
    'targetCharacterId': null,
    'reward': {
      'current_xp': 50,
      'traits': [
        {'name': 'Odwaga', 'value': '1'},
        {'name': 'Mądrość', 'value': '2'},
      ],
    },
    'baseline': {'c1': 300},
    'spent': <String, int>{},
    'damage': <String, int>{},
    'rewarded': <String, bool>{},
    ...boss,
  });
  return db;
}

Future<Map<String, dynamic>> bossData(FakeFirebaseFirestore db) async =>
    (await db.collection('bosses').doc('b1').get()).data()!;

void main() {
  setUp(() => BossMotion.loops = false);
  tearDown(() => BossMotion.loops = true);

  testWidgets('an owner picks a blow, taps the boss and it loses HP', (tester) async {
    final db = await world();
    await pumpAchievementsApp(tester, db, const _Host(), uid: 'zosia');

    expect(find.text('100 / 100 HP'), findsOneWidget);
    expect(find.textContaining('40'), findsWidgets);

    await tester.tap(find.byKey(const Key('boss-weapon')));
    await tester.pumpAndSettle();
    expect(find.text('Potężne walnięcie'), findsOneWidget);
    expect(find.textContaining('brakuje 10 energii'), findsOneWidget, reason: 'combo costs 50');

    await tester.tap(find.byKey(const Key('blow-strong')));
    await tester.pumpAndSettle();
    expect(find.text('Potężne walnięcie — stuknij bossa!'), findsOneWidget);

    final heroBefore = tester.getTopLeft(find.byKey(const Key('boss-hero')));
    await tester.tap(find.byKey(const Key('boss-target')));
    // The barbarian walks up to the boss first, then swings.
    var sawDamage = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      sawDamage |= find.byKey(const Key('boss-damage')).evaluate().isNotEmpty;
    }
    await tester.pumpAndSettle();
    expect(sawDamage, isTrue);
    expect(
      tester.getTopLeft(find.byKey(const Key('boss-hero'))).dx,
      greaterThan(heroBefore.dx + 40),
      reason: 'it walked over to the boss',
    );

    final data = await bossData(db);
    expect(data['hp'], 90);
    expect(data['spent'], {'c1': 10});
    expect(data['damage'], {'c1': 10});
    expect(find.text('90 / 100 HP'), findsOneWidget);
  });

  testWidgets('a tap on the floor walks the hero there', (tester) async {
    final db = await world();
    await pumpAchievementsApp(tester, db, const _Host(), uid: 'zosia');

    final hero = find.byKey(const Key('boss-hero'));
    final floor = find.byKey(const Key('boss-floor'));
    final start = tester.getCenter(hero).dx;
    final target = tester.getTopLeft(floor) + const Offset(300, 20);
    await tester.tapAt(target);
    await tester.pump(); // the walk's first frame
    await tester.pump(const Duration(milliseconds: 100));
    final midway = tester.getCenter(hero).dx;
    expect(midway, greaterThan(start));
    expect(midway, lessThan(target.dx - 5), reason: 'it walks, it does not jump');
    await tester.pumpAndSettle();
    expect(tester.getCenter(hero).dx, closeTo(target.dx, 1));
  });

  testWidgets('a tap on the boss with no blow picked opens the picker', (tester) async {
    final db = await world();
    await pumpAchievementsApp(tester, db, const _Host(), uid: 'zosia');
    await tester.tap(find.byKey(const Key('boss-target')));
    await tester.pumpAndSettle();
    expect(find.text('WYBIERZ CIOS'), findsOneWidget);
  });

  testWidgets('a wizard turns the spellbook; a spell out of reach is sealed', (tester) async {
    final db = await world(clazz: 'Czarodziejka');
    await pumpAchievementsApp(tester, db, const _Host(), uid: 'zosia');

    await tester.tap(find.byKey(const Key('boss-weapon')));
    await tester.pumpAndSettle();
    // Opens on the strongest spell 40 energy pays for.
    expect(find.text('Kula ognia'), findsOneWidget);

    await tester.tap(find.byTooltip('Następna strona'));
    await tester.pumpAndSettle();
    expect(find.text('Lodowa burza'), findsOneWidget);
    expect(find.text('Zapieczętowane\nbrakuje 10 energii'), findsOneWidget);
    expect(find.byKey(const Key('spell-combo')), findsNothing);

    await tester.tap(find.byTooltip('Poprzednia strona'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('spell-strong')));
    await tester.pumpAndSettle();
    expect(find.text('Kula ognia — stuknij bossa!'), findsOneWidget);
  });

  testWidgets('a class with no weapon set cannot fight', (tester) async {
    final db = await world(clazz: 'Bardka');
    await pumpAchievementsApp(tester, db, const _Host(), uid: 'zosia');
    expect(find.text('BRAK BRONI'), findsOneWidget);
    expect(find.text('Poproś admina o broń'), findsOneWidget);
  });

  testWidgets('a fighter collects the reward from the beaten boss', (tester) async {
    final db = await world(boss: {'hp': 0, 'status': 'defeated', 'damage': {'c1': 64}, 'lastAttackerName': 'Kuba'});
    await pumpAchievementsApp(tester, db, const _Host(), uid: 'zosia');

    expect(find.text('Smok Ognisty pokonany!'), findsOneWidget);
    expect(find.text('Ostatni cios: Kuba'), findsOneWidget);
    expect(find.text('Mądrość +2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('claim-boss-reward')));
    await tester.pumpAndSettle();
    expect(find.text('Nagroda odebrana!'), findsOneWidget);

    final c1 = await characterData(db);
    expect(c1['current_xp'], 390);
    expect((c1['traits'] as List).map((t) => t['name']), containsAll(['Odwaga', 'Mądrość']));
    expect((await bossData(db))['rewarded'], {'c1': true});

    await tester.tap(find.text('Super!'));
    await tester.pumpAndSettle();
    expect(find.text('Smok Ognisty pokonany!'), findsNothing, reason: 'collected: it leaves the card');
  });

  testWidgets('an admin may call a boss off', (tester) async {
    final db = await world();
    await pumpAchievementsApp(tester, db, const _Host());

    expect(find.byKey(const Key('boss-weapon')), findsNothing, reason: "not the admin's character");
    await tester.tap(find.byKey(const Key('cancel-boss')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-cancel-boss')));
    await tester.pumpAndSettle();
    expect((await bossData(db))['status'], 'cancelled');
    expect(find.byType(BossArena), findsNothing);
  });

  testWidgets('the summon form calls a boss with several traits for one character', (tester) async {
    final db = await seedWorld();
    await tester.binding.setSurfaceSize(const Size(420, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpAchievementsApp(tester, db, const SummonBossScreen());

    await tester.tap(find.byKey(const Key('look-rycerz')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextFormField, 'Czarny Rycerz'), findsOneWidget);
    await tester.tap(find.byKey(const Key('hp-250')));
    await tester.tap(find.byKey(const Key('boss-add-trait')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('boss-add-trait')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('boss-trait-name-0')), 'Odwaga');
    await tester.enterText(find.byKey(const Key('boss-trait-name-1')), 'Mądrość');
    await tester.tap(find.byKey(const Key('target-one')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('target-c1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('summon-boss')));
    await tester.pumpAndSettle();

    final docs = (await db.collection('bosses').get()).docs;
    expect(docs, hasLength(1));
    final boss = docs.single.data();
    expect(boss['look'], 'rycerz');
    expect(boss['name'], 'Czarny Rycerz');
    expect(boss['maxHp'], 250);
    expect(boss['targetCharacterId'], 'c1');
    expect(boss['baseline'], {'c1': 340});
    expect(boss['reward'], {
      'current_xp': 50,
      'traits': [
        {'name': 'Odwaga', 'value': '1'},
        {'name': 'Mądrość', 'value': '1'},
      ],
    });
  });
}
