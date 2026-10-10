import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievement_detail_screen.dart';
import 'package:liferpg/features/achievements/achievements_screen.dart';
import 'package:liferpg/features/achievements/award_achievement_screen.dart';

import 'achievements_test_support.dart';

final badges = [
  achievementMap(id: 'a1', title: 'II miejsce', date: '2026-09-12'),
  achievementMap(id: 'a2', title: 'Koncert jesienny', date: '2026-10-04',
      emblem: 'note', place: null, tier: 'gold'),
];

void main() {
  testWidgets('lists badges newest first with short dates', (tester) async {
    final db = await seedWorld(achievements: badges);
    await pumpAchievementsApp(
        tester, db, const AchievementsScreen(characterId: 'c1'), uid: 'zosia');
    expect(find.text('Odznaki · Zosia'), findsOneWidget);
    expect(find.text('4 paź 2026'), findsOneWidget);
    final first = tester.getTopLeft(find.byKey(const Key('gallery-tile-a2')));
    final second = tester.getTopLeft(find.byKey(const Key('gallery-tile-a1')));
    expect(first.dx, lessThan(second.dx));
    expect(find.byKey(const Key('achievement-award')), findsNothing);
  });

  testWidgets('a tile opens its detail; admin gets +', (tester) async {
    final db = await seedWorld(achievements: badges);
    await pumpAchievementsApp(
        tester, db, const AchievementsScreen(characterId: 'c1'));
    await tester.tap(find.byKey(const Key('achievement-award')));
    await tester.pumpAndSettle();
    expect(find.byType(AwardAchievementScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('gallery-tile-a1')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<AchievementDetailScreen>(find.byType(AchievementDetailScreen))
          .achievementId,
      'a1',
    );
  });

  testWidgets('long titles at 2x text scale do not overflow', (tester) async {
    final db = await seedWorld(achievements: [
      achievementMap(
          id: 'long',
          title: 'Zdobywczyni najwyższego szczytu Karkonoszy w zimie'),
    ]);
    await pumpAchievementsApp(
      tester,
      db,
      const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: AchievementsScreen(characterId: 'c1'),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
