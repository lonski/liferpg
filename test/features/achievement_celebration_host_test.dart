import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievement_celebration_host.dart';

import 'achievements_test_support.dart';

void main() {
  testWidgets('a badge awarded after launch pops the dialog once',
      (tester) async {
    final db = await seedWorld();
    await pumpAchievementsApp(
      tester,
      db,
      const AchievementCelebrationHost(child: Scaffold(body: Text('dom'))),
      uid: 'zosia',
    );
    expect(find.text('Koncert jesienny'), findsNothing);

    await db.collection('characters').doc('c1').update({
      'achievements': [achievementMap(id: 'n1', title: 'Koncert jesienny')],
    });
    await tester.pumpAndSettle();
    expect(find.text('✦ NOWA ODZNAKA ✦'), findsOneWidget);
    expect(find.text('Koncert jesienny'), findsOneWidget);
    expect(find.text('+150 XP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-achievement-close')));
    await tester.pumpAndSettle();
    expect(find.text('✦ NOWA ODZNAKA ✦'), findsNothing);
  });
}
