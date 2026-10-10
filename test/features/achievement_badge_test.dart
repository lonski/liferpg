import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievement_badge.dart';
import 'package:liferpg/features/achievements/achievement_widgets.dart';
import 'package:liferpg/models/achievement.dart';
import 'package:liferpg/models/change_request.dart';

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('a place badge draws its Roman numeral at the requested size',
      (tester) async {
    await tester.pumpWidget(wrap(const AchievementBadge(
      tier: AchievementTier.silver,
      emblem: AchievementEmblem.place,
      place: 2,
      size: 80,
    )));
    expect(find.text('II'), findsOneWidget);
    expect(tester.getSize(find.byType(AchievementBadge)), const Size(80, 100));
    expect(find.bySemanticsLabel('Odznaka srebrna'), findsOneWidget);
  });

  testWidgets('icon emblems, and a place emblem with no place is a trophy',
      (tester) async {
    await tester.pumpWidget(wrap(const Row(mainAxisSize: MainAxisSize.min, children: [
      AchievementBadge(tier: AchievementTier.gold, emblem: AchievementEmblem.note),
      AchievementBadge(tier: AchievementTier.ruby, emblem: AchievementEmblem.place),
    ])));
    expect(find.byIcon(Icons.music_note), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsOneWidget);
  });

  testWidgets('the numeral ignores text scaling', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(3)),
      child: wrap(const AchievementBadge(
        tier: AchievementTier.bronze,
        emblem: AchievementEmblem.place,
        place: 3,
        size: 32,
      )),
    ));
    expect(tester.takeException(), isNull);
  });

  testWidgets('RewardChips shows one chip per non-zero part', (tester) async {
    await tester.pumpWidget(wrap(const RewardChips(
      reward: AchievementReward(
        currentXp: 150,
        gold: 0,
        trait: TraitChange(name: 'Recytacja', value: '1'),
      ),
    )));
    expect(find.text('+150 XP'), findsOneWidget);
    expect(find.text('Recytacja +1'), findsOneWidget);
    expect(find.textContaining('zł'), findsNothing);
  });

  testWidgets('ParchmentFrame bands its title and optional footer', (tester) async {
    await tester.pumpWidget(wrap(const ParchmentFrame(
      band: 'Odznaka',
      footerLabel: 'LifeRPG',
      child: Text('treść'),
    )));
    expect(find.text('✦ ODZNAKA ✦'), findsOneWidget);
    expect(find.text('— ✦ LIFERPG ✦ —'), findsOneWidget);
    expect(find.text('treść'), findsOneWidget);
  });
}
