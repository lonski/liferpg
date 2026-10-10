import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievement_badge.dart';
import 'package:liferpg/features/achievements/award_achievement_screen.dart';
import 'package:liferpg/models/achievement.dart';
import 'package:liferpg/models/character.dart';

import 'achievements_test_support.dart';

Future<Character> zosia(db) async =>
    Character.fromMap('c1', await characterData(db));

String fieldText(WidgetTester tester, String key) =>
    tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

Future<void> tapKey(WidgetTester tester, String key) async {
  // A focused text field scrolls itself back into view on the next frame.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pump();
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('picking a place sets emblem, tier and title', (tester) async {
    final db = await seedWorld();
    await pumpAchievementsApp(
        tester, db, AwardAchievementScreen(character: await zosia(db)));

    await tapKey(tester, 'place-2');
    final badge = tester.widget<AchievementBadge>(find.byType(AchievementBadge));
    expect(badge.emblem, AchievementEmblem.place);
    expect(badge.tier, AchievementTier.silver);
    expect(fieldText(tester, 'field-title'), 'II miejsce');
    expect(fieldText(tester, 'field-date'), '2026-10-12');

    await tapKey(tester, 'place-none');
    expect(tester.widget<AchievementBadge>(find.byType(AchievementBadge)).emblem,
        AchievementEmblem.trophy);
  });

  testWidgets('submitting awards the badge with its reward', (tester) async {
    final db = await seedWorld();
    await pumpAchievementsApp(
        tester, db, AwardAchievementScreen(character: await zosia(db)));

    await tapKey(tester, 'place-1');
    await tester.enterText(find.byKey(const Key('field-event')), 'Turniej');
    await tester.enterText(find.byKey(const Key('field-current_xp')), '150');
    await tester.enterText(find.byKey(const Key('field-electronics-days')), '2');
    await tester.pumpAndSettle();
    expect(find.textContaining('Zosia otrzyma odznakę „I miejsce”'), findsOneWidget);
    await tapKey(tester, 'achievement-submit');
    // A second tap would reuse the same id; the repository makes it a no-op.

    final c = await characterData(db);
    expect(c['achievements'], hasLength(1));
    final entry = c['achievements'][0] as Map;
    expect(entry['title'], 'I miejsce');
    expect(entry['event'], 'Turniej');
    expect(entry['tier'], 'gold');
    expect(entry['place'], 1);
    expect(entry['awardedBy'], 'admin');
    expect(entry['awardedByName'], 'Tata');
    expect(entry['reward'], {'current_xp': 150, 'electronics_days': 2});
    expect(c['current_xp'], 490);
    expect(c['electronics']['days'], 3);
  });

  testWidgets('a missing title or bad date blocks the write', (tester) async {
    final db = await seedWorld();
    await pumpAchievementsApp(
        tester, db, AwardAchievementScreen(character: await zosia(db)));

    await tester.enterText(find.byKey(const Key('field-date')), '12.10.2026');
    await tapKey(tester, 'achievement-submit');
    expect(find.text('Podaj tytuł'), findsOneWidget);
    expect(find.text('Podaj datę RRRR-MM-DD'), findsOneWidget);
    expect((await characterData(db))['achievements'], isNull);
  });

  testWidgets('edit mode shows the reward read-only and changes details only',
      (tester) async {
    final db = await seedWorld(achievements: [achievementMap()]);
    final c = await zosia(db);
    await pumpAchievementsApp(tester, db,
        AwardAchievementScreen(character: c, editing: c.achievements.single));

    expect(find.byKey(const Key('field-current_xp')), findsNothing);
    expect(find.text('Aby zmienić nagrodę, usuń odznakę i przyznaj ją ponownie.'),
        findsOneWidget);
    expect(find.text('+150 XP'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('field-title')), 'Wyróżnienie');
    await tapKey(tester, 'achievement-submit');
    final data = await characterData(db);
    expect((data['achievements'][0] as Map)['title'], 'Wyróżnienie');
    expect(data['current_xp'], 340);
  });
}
