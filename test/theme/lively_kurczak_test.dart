import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/theme/app_theme.dart';
import 'package:liferpg/theme/chatter.dart';
import 'package:liferpg/theme/decor.dart';
import 'package:liferpg/theme/lively_kurczak.dart';

Widget _yard(Widget bird) => MaterialApp(
      theme: buildAppTheme(RpgTheme.kurczaki),
      home: Scaffold(body: Center(child: bird)),
    );

const _hen = LivelyKurczak(
  Kurczak.hen,
  key: Key('hen'),
  voice: KurczakVoice.hen,
  width: 90,
  height: 84,
);

Finder _anyLine(KurczakVoice voice) => find.byWidgetPredicate(
      (w) => w is Text && LivelyKurczak.linesOf(voice).contains(w.data),
    );

Future<void> _tap(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('hen')));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() => LivelyKurczak.random = math.Random(7));

  testWidgets('a tapped hen hops and clucks, then falls quiet', (tester) async {
    await tester.pumpWidget(_yard(_hen));
    expect(_anyLine(KurczakVoice.hen), findsNothing);

    await _tap(tester);
    expect(_anyLine(KurczakVoice.hen), findsOneWidget);

    await tester.pumpAndSettle();
    expect(_anyLine(KurczakVoice.hen), findsNothing);
  });

  testWidgets('a tapped chick peeps, also when it runs off', (tester) async {
    await tester.pumpWidget(_yard(const LivelyKurczak(
      Kurczak.chick,
      key: Key('chick'),
      voice: KurczakVoice.chick,
      width: 40,
      height: 38,
      runs: true,
    )));
    await tester.tap(find.byKey(const Key('chick')));
    await tester.pump(); // starts the run
    await tester.pump(const Duration(milliseconds: 450)); // halfway

    expect(_anyLine(KurczakVoice.chick), findsOneWidget);
    // Mid-run it is away from where it stands.
    final moved = tester.widgetList<Transform>(find.descendant(
      of: find.byKey(const Key('chick')),
      matching: find.byType(Transform),
    ));
    expect(moved.any((t) => t.transform.getTranslation().x.abs() > 20), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('five quick taps make a hen lay a golden egg that rolls away',
      (tester) async {
    await tester.pumpWidget(_yard(_hen));
    for (var i = 0; i < LivelyKurczak.eggTaps; i++) {
      await _tap(tester);
    }

    expect(find.byKey(const Key('kurczak-egg')), findsOneWidget);
    expect(find.text(LivelyKurczak.eggLine), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kurczak-egg')), findsNothing);
  });

  testWidgets('slow taps never lay an egg', (tester) async {
    await tester.pumpWidget(_yard(_hen));
    for (var i = 0; i < LivelyKurczak.eggTaps + 2; i++) {
      await _tap(tester);
      await tester.pump(LivelyKurczak.eggTapWindow);
    }
    expect(find.byKey(const Key('kurczak-egg')), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a chick never lays, however fast it is tapped', (tester) async {
    await tester.pumpWidget(_yard(const LivelyKurczak(
      Kurczak.chick,
      key: Key('hen'),
      voice: KurczakVoice.chick,
      width: 40,
      height: 38,
    )));
    for (var i = 0; i < LivelyKurczak.eggTaps + 2; i++) {
      await _tap(tester);
    }
    expect(find.byKey(const Key('kurczak-egg')), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a long press sends a bird to sleep', (tester) async {
    await tester.pumpWidget(_yard(_hen));
    await tester.longPress(find.byKey(const Key('hen')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.byWidgetPredicate(
        (w) => w is Text && LivelyKurczak.sleepLines.contains(w.data),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('a grown bird now and then sheds feathers, a chick never',
      (tester) async {
    await tester.pumpWidget(_yard(const LivelyKurczak(
      Kurczak.rooster,
      key: Key('hen'),
      voice: KurczakVoice.rooster,
      width: 90,
      height: 80,
    )));
    var shed = false;
    for (var i = 0; i < 20 && !shed; i++) {
      await _tap(tester);
      shed = find.byKey(const Key('kurczak-feather')).evaluate().isNotEmpty;
      await tester.pumpAndSettle();
    }
    expect(shed, isTrue);

    await tester.pumpWidget(_yard(const LivelyKurczak(
      Kurczak.chick,
      key: Key('hen'),
      voice: KurczakVoice.chick,
      width: 40,
      height: 38,
    )));
    for (var i = 0; i < 20; i++) {
      await _tap(tester);
      expect(find.byKey(const Key('kurczak-feather')), findsNothing);
      await tester.pumpAndSettle();
    }
  });

  group('with ThemeChatter', () {
    Widget chatty(Widget bird, {List<String> tips = const [], List<String>? played}) =>
        _yard(ThemeChatter(
          tips: tips,
          playSound: played?.add,
          child: bird,
        ));

    testWidgets('a tapped bird plays one of its own sounds', (tester) async {
      final played = <String>[];
      await tester.pumpWidget(chatty(_hen, played: played));
      await _tap(tester);

      expect(played, hasLength(1));
      expect(LivelyKurczak.sounds[KurczakVoice.hen], contains(played.single));
      await tester.pumpAndSettle();
    });

    testWidgets('the laying hen cackles with the egg sound', (tester) async {
      final played = <String>[];
      await tester.pumpWidget(chatty(_hen, played: played));
      for (var i = 0; i < LivelyKurczak.eggTaps; i++) {
        await _tap(tester);
      }
      expect(played.last, LivelyKurczak.eggSound);
      await tester.pumpAndSettle();
    });

    testWidgets('with sounds switched off it stays silent', (tester) async {
      await tester.pumpWidget(chatty(_hen));
      await _tap(tester);
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
    });

    testWidgets('now and then it drops a tip', (tester) async {
      const tip = 'Psst! Za „Zmywarka” jest aż 10 XP!';
      await tester.pumpWidget(chatty(_hen, tips: const [tip]));
      var tipped = false;
      for (var i = 0; i < 20 && !tipped; i++) {
        await _tap(tester);
        tipped = find.text(tip).evaluate().isNotEmpty;
        await tester.pumpAndSettle();
      }
      expect(tipped, isTrue);
    });
  });

  test('every sound a bird may play is bundled', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final assets = {
      for (final list in LivelyKurczak.sounds.values) ...list,
      LivelyKurczak.eggSound,
    };
    for (final asset in assets) {
      final data = await rootBundle.load('assets/$asset');
      expect(data.lengthInBytes, greaterThan(1000), reason: asset);
    }
  });
}
