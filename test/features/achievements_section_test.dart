import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievements_screen.dart';
import 'package:liferpg/features/achievements/achievements_section.dart';
import 'package:liferpg/features/achievements/award_achievement_screen.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/providers/achievement_providers.dart';

import 'achievements_test_support.dart';

Widget host(Character c, {required bool isAdmin}) => Scaffold(
      body: SingleChildScrollView(
        child: AchievementsSection(character: c, isAdmin: isAdmin),
      ),
    );

/// Renders the section off the live roster, so Firestore updates reach it.
class _LiveHost extends ConsumerWidget {
  const _LiveHost();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(characterByIdProvider('c1'));
    return Scaffold(
      body: SingleChildScrollView(
        child: c == null
            ? const SizedBox()
            : AchievementsSection(character: c, isAdmin: false),
      ),
    );
  }
}

void main() {
  test('visibleFor: players need a badge, admins always see it', () {
    final none = Character.fromMap('c1', zosiaCharacter());
    final some =
        Character.fromMap('c1', zosiaCharacter(achievements: [achievementMap()]));
    expect(AchievementsSection.visibleFor(none, isAdmin: false), isFalse);
    expect(AchievementsSection.visibleFor(none, isAdmin: true), isTrue);
    expect(AchievementsSection.visibleFor(some, isAdmin: false), isTrue);
  });

  testWidgets('admin with no badges gets Brak odznak and an award button',
      (tester) async {
    final db = await seedWorld();
    final c = Character.fromMap('c1', await characterData(db));
    await pumpAchievementsApp(tester, db, host(c, isAdmin: true));
    expect(find.text('ODZNAKI'), findsOneWidget);
    expect(find.text('Brak odznak'), findsOneWidget);
    await tester.tap(find.byKey(const Key('achievements-award')));
    await tester.pumpAndSettle();
    expect(find.byType(AwardAchievementScreen), findsOneWidget);
  });

  testWidgets('shows the 4 newest and links all',
      (tester) async {
    final db = await seedWorld(achievements: [
      for (var i = 1; i <= 5; i++)
        achievementMap(
          id: 'a$i',
          title: 'Odznaka $i',
          date: '2026-10-0$i',
          awardedAt: DateTime(2026, 10, i, 12),
        ),
    ]);
    final c = Character.fromMap('c1', await characterData(db));
    await pumpAchievementsApp(tester, db, host(c, isAdmin: false), uid: 'zosia');

    expect(find.text('ODZNAKI · 5'), findsOneWidget);
    expect(find.byKey(const Key('achievement-tile-a5')), findsOneWidget);
    expect(find.byKey(const Key('achievement-tile-a1')), findsNothing);

    await tester.tap(find.byKey(const Key('achievements-all')));
    await tester.pumpAndSettle();
    expect(find.byType(AchievementsScreen), findsOneWidget);
  });

  // 440 = the home screen's max card width. Narrower at 2x, the shared
  // LabelledDivider heading itself overflows (pre-existing, also hits
  // "Dni elektroniki"); the tiles are what this guards.
  testWidgets('long titles at 2x scale in a card do not overflow',
      (tester) async {
    final db = await seedWorld(achievements: [
      achievementMap(id: 'x', title: 'Bardzo długi tytuł odznaki za wszystko'),
    ]);
    final c = Character.fromMap('c1', await characterData(db));
    await pumpAchievementsApp(
      tester,
      db,
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Center(child: SizedBox(width: 440, child: host(c, isAdmin: false))),
      ),
      uid: 'zosia',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('NOWA marks a badge until its detail is opened', (tester) async {
    final db = await seedWorld(
        achievements: [achievementMap(id: 'old', title: 'Stara')]);
    await pumpAchievementsApp(tester, db, const _LiveHost(), uid: 'zosia');
    // Badges that existed before the first run are not new.
    expect(find.text('NOWA'), findsNothing);

    final data = await characterData(db);
    await db.collection('characters').doc('c1').update({
      'achievements': [
        ...data['achievements'] as List,
        achievementMap(id: 'fresh', title: 'Świeża', date: '2026-10-11'),
      ],
    });
    await tester.pumpAndSettle();
    expect(find.text('NOWA'), findsOneWidget);

    await tester.tap(find.byKey(const Key('achievement-tile-fresh')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('NOWA'), findsNothing);
  });
}
