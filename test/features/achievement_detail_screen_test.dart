import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievement_detail_screen.dart';
import 'package:liferpg/features/achievements/award_achievement_screen.dart';

import 'achievements_test_support.dart';

const screen = AchievementDetailScreen(characterId: 'c1', achievementId: 'a1');

void main() {
  testWidgets('shows the badge details to its owner, without admin actions',
      (tester) async {
    final db = await seedWorld(achievements: [achievementMap()]);
    await pumpAchievementsApp(tester, db, screen, uid: 'zosia');

    expect(find.text('II miejsce'), findsOneWidget);
    expect(find.text('Wojewódzki Konkurs Recytatorski'), findsOneWidget);
    expect(find.text('12 września 2026'), findsOneWidget);
    expect(find.text('Tata'), findsOneWidget);
    expect(find.text('+150 XP'), findsOneWidget);
    expect(find.text('+2 dni elektroniki'), findsOneWidget);
    expect(find.byKey(const Key('achievement-edit')), findsNothing);
    expect(find.byKey(const Key('achievement-revoke')), findsNothing);
  });

  testWidgets('admin edit opens the form in edit mode', (tester) async {
    final db = await seedWorld(achievements: [achievementMap()]);
    await pumpAchievementsApp(tester, db, screen);
    await tester.tap(find.byKey(const Key('achievement-edit')));
    await tester.pumpAndSettle();
    final form = tester.widget<AwardAchievementScreen>(
        find.byType(AwardAchievementScreen));
    expect(form.editing?.id, 'a1');
  });

  testWidgets('revoke lists what is taken back and reverses the reward',
      (tester) async {
    final db = await seedWorld(achievements: [achievementMap()]);
    await pumpAchievementsApp(tester, db, screen);

    await tester.tap(find.byKey(const Key('achievement-revoke')));
    await tester.pumpAndSettle();
    expect(
      find.text('Cofnięte zostanie: −150 XP, −50 zł, Recytacja −1, '
          '−2 dni elektroniki'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('achievement-revoke-confirm')));
    await tester.pumpAndSettle();

    final c = await characterData(db);
    expect(c['achievements'], isEmpty);
    expect(c['gold'], 75);
    expect(c['current_xp'], 190);
  });

  testWidgets('a vanished badge says so', (tester) async {
    final db = await seedWorld();
    await pumpAchievementsApp(tester, db, screen);
    expect(find.text('Ta odznaka już nie istnieje'), findsOneWidget);
  });
  testWidgets('everyone who sees the badge gets a share action', (tester) async {
    final db = await seedWorld(achievements: [achievementMap()]);
    await pumpAchievementsApp(tester, db, screen, uid: 'zosia');
    expect(find.byKey(const Key('achievement-share')), findsOneWidget);
  });}
