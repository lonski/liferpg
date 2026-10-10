import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/data/update_repository.dart';
import 'package:liferpg/features/achievements/achievement_detail_screen.dart';
import 'package:liferpg/features/achievements/achievements_screen.dart';
import 'package:liferpg/features/home/home_screen.dart';
import 'package:liferpg/features/login/login_screen.dart';
import 'package:liferpg/features/quests/quests_screen.dart';
import 'package:liferpg/providers/clock_provider.dart';
import 'package:liferpg/providers/update_providers.dart';
import 'package:liferpg/theme/app_theme.dart';
import 'package:liferpg/theme/decor.dart';
import 'package:liferpg/theme/lively_kurczak.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/achievements_test_support.dart';

Future<FakeFirebaseFirestore> _world() => seedWorld(achievements: [
      achievementMap(id: 'a1', title: 'I miejsce', tier: 'gold', place: 1),
      achievementMap(id: 'a2', title: 'Gwiazda', tier: 'ruby', emblem: 'star', place: null),
    ]);

Future<void> _pump(WidgetTester tester, Widget home, RpgTheme theme) async {
  tester.view.physicalSize = const Size(412, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(await _world()),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'zosia', email: 'zosia@example.com'),
      )),
      clockProvider.overrideWithValue(() => testNow),
      sharedPreferencesProvider.overrideWithValue(prefs),
      updateRepositoryProvider.overrideWith((ref) async =>
          UpdateRepository(MockClient((_) async => http.Response('{}', 200)), '99.0.0')),
    ],
    child: MaterialApp(theme: buildAppTheme(theme), home: home),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('Kurczaki', () {
    testWidgets('the home screen renders with its illustrations', (tester) async {
      await _pump(tester, const HomeScreen(), RpgTheme.kurczaki);

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
      await _pump(tester, const HomeScreen(), RpgTheme.kurczaki);
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
        await _pump(tester, home, RpgTheme.kurczaki);
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
      await _pump(tester, const HomeScreen(), RpgTheme.kronika);

      expect(find.text('✦ KARTA POSTACI ✦'), findsOneWidget);
      expect(find.byType(KurczakArt), findsNothing);
    });
  });
}
