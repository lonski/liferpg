import 'dart:io';

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
import 'package:liferpg/theme/ornaments.dart';

import 'theme_test_support.dart';

void main() {
  group('Lagotto', () {
    testWidgets('the home screen renders with its illustrations', (tester) async {
      await pumpThemed(tester, const HomeScreen(), RpgTheme.lagotto);

      expect(tester.takeException(), isNull);
      // Band labels carry dog faces instead of ✦ glyphs.
      expect(find.text('KARTA POSTACI'), findsOneWidget);
      expect(find.text('✦ KARTA POSTACI ✦'), findsNothing);
      expect(find.byType(LagottoArt), findsWidgets);
      expect(find.byType(KurczakArt), findsNothing);
      // The electronics count still renders (on the paw pad).
      expect(find.byKey(const Key('electronics-count')), findsOneWidget);
      // A trait value sits on a bone but is still its text.
      expect(find.text('3'), findsWidgets);
      // Bands are stitched.
      expect(find.byType(Stitched), findsWidgets);
    });

    testWidgets('the quests, login and badge screens render', (tester) async {
      for (final home in const [
        QuestsScreen(),
        LoginScreen(),
        AchievementsScreen(characterId: 'c1'),
        AchievementDetailScreen(characterId: 'c1', achievementId: 'a1'),
      ]) {
        await pumpThemed(tester, home, RpgTheme.lagotto);
        expect(tester.takeException(), isNull, reason: '${home.runtimeType}');
        expect(find.byType(LagottoArt), findsWidgets, reason: '${home.runtimeType}');
      }
    });

    test('text drawn on the scaffold is dark, on the honey gold', () {
      const t = RpgTheme.lagotto;
      expect(t.onBg.computeLuminance(), lessThan(0.1));
      expect(t.bgDark.computeLuminance(), greaterThan(0.6));
    });

    test('every illustration asset is listed and exists', () {
      for (final art in Lagotto.values) {
        expect(File(art.asset).existsSync(), isTrue, reason: art.asset);
      }
    });

    test('draws its own shapes for badges and the electronics count', () {
      const decor = LagottoDecor();
      expect(decor.badgeShape, BadgeShape.boneTag);
      expect(decor.medallionShape, MedallionShape.paw);
      expect(decor.stitchedBands, isTrue);
    });

    test('a bone and a paw pad stay inside the box they are drawn for', () {
      // getBounds() counts the arcs' control points; trace the outline.
      Rect traced(Path path) {
        var r = Rect.zero;
        var first = true;
        for (final m in path.computeMetrics()) {
          for (var d = 0.0; d <= m.length; d += 0.25) {
            final p = m.getTangentForOffset(d)!.position;
            r = first ? Rect.fromPoints(p, p) : r.expandToInclude(Rect.fromPoints(p, p));
            first = false;
          }
        }
        return r;
      }

      const box = Size(58, 34);
      final bone = traced(bonePath(box));
      expect(bone.left, greaterThanOrEqualTo(-0.01));
      expect(bone.right, lessThanOrEqualTo(box.width + 0.01));
      expect(bone.top, greaterThanOrEqualTo(-0.01));
      expect(bone.bottom, lessThanOrEqualTo(box.height + 0.01));
      final pad = traced(pawPadPath(const Size(52, 52)));
      expect(pad.width, closeTo(30, 0.5));
    });
  });

  test('Kronika and Kurczaki keep their badge and medallion shapes', () {
    expect(RpgTheme.kronika.decor.badgeShape, BadgeShape.medal);
    expect(RpgTheme.kronika.decor.medallionShape, MedallionShape.ring);
    expect(RpgTheme.kurczaki.decor.badgeShape, BadgeShape.egg);
    expect(RpgTheme.kurczaki.decor.medallionShape, MedallionShape.egg);
    expect(RpgTheme.kronika.decor.stitchedBands, isFalse);
  });
}
