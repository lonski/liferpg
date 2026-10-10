import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/achievements/achievement_detail_screen.dart';
import 'package:liferpg/features/achievements/achievements_screen.dart';
import 'package:liferpg/features/home/home_screen.dart';
import 'package:liferpg/features/login/login_screen.dart';
import 'package:liferpg/features/quests/quests_screen.dart';
import 'package:liferpg/theme/app_theme.dart';
import 'package:liferpg/theme/decor.dart';
import 'package:liferpg/theme/lagotto_decor.dart';
import 'package:liferpg/theme/lively_kurczak.dart';

import 'theme_test_support.dart';

void main() {
  group('Kurczaki', () {
    testWidgets('the home screen renders with its illustrations', (tester) async {
      await pumpThemed(tester, const HomeScreen(), RpgTheme.kurczaki);

      expect(tester.takeException(), isNull);
      // Band labels carry chick heads instead of ✦ glyphs.
      expect(find.text('KARTA POSTACI'), findsOneWidget);
      expect(find.text('✦ KARTA POSTACI ✦'), findsNothing);
      expect(find.byType(KurczakArt), findsWidgets);
      // The electronics count still renders (inside the egg).
      expect(find.byKey(const Key('electronics-count')), findsOneWidget);
      // A trait value sits in an egg but is still its text.
      expect(find.text('3'), findsWidgets);
    });

    testWidgets('the hen on the character card answers a tap', (tester) async {
      await pumpThemed(tester, const HomeScreen(), RpgTheme.kurczaki);
      final hen = find.byWidgetPredicate(
        (w) => w is LivelyKurczak && w.art == Kurczak.henNest,
      );
      expect(hen, findsOneWidget);

      await tester.tap(hen);
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.byWidgetPredicate((w) =>
            w is Text && LivelyKurczak.linesOf(KurczakVoice.hen).contains(w.data)),
        findsOneWidget,
      );
      await tester.pumpAndSettle();
    });

    testWidgets('the quests, login and badge screens render', (tester) async {
      for (final home in const [
        QuestsScreen(),
        LoginScreen(),
        AchievementsScreen(characterId: 'c1'),
        AchievementDetailScreen(characterId: 'c1', achievementId: 'a1'),
      ]) {
        await pumpThemed(tester, home, RpgTheme.kurczaki);
        expect(tester.takeException(), isNull, reason: '${home.runtimeType}');
        expect(find.byType(KurczakArt), findsWidgets, reason: '${home.runtimeType}');
      }
    });

    test('text drawn on the scaffold is dark, on the straw', () {
      const t = RpgTheme.kurczaki;
      expect(t.onBg.computeLuminance(), lessThan(0.1));
      expect(t.bgDark.computeLuminance(), greaterThan(0.6));
    });
  });

  group('Kronika', () {
    testWidgets('keeps its text glyphs and draws no illustrations', (tester) async {
      await pumpThemed(tester, const HomeScreen(), RpgTheme.kronika);

      expect(find.text('✦ KARTA POSTACI ✦'), findsOneWidget);
      expect(find.byType(KurczakArt), findsNothing);
      expect(find.byType(LagottoArt), findsNothing);
    });
  });
}
