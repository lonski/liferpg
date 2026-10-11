import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/theme/app_theme.dart';
import 'package:liferpg/theme/chatter.dart';
import 'package:liferpg/theme/lagotto_decor.dart';
import 'package:liferpg/theme/lively.dart';
import 'package:liferpg/theme/lively_lagotto.dart';

Widget _park(Widget dog) => MaterialApp(
      theme: buildAppTheme(RpgTheme.lagotto),
      home: Scaffold(body: Center(child: dog)),
    );

const _dog = LivelyLagotto(
  Lagotto.dogSit,
  key: Key('dog'),
  voice: LagottoVoice.dog,
  width: 90,
  height: 97,
);

Finder _anyOf(List<String> lines) =>
    find.byWidgetPredicate((w) => w is Text && lines.contains(w.data));

Future<void> _tap(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('dog')));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() => LivelyLagotto.random = math.Random(7));

  testWidgets('a tapped dog barks, then falls quiet', (tester) async {
    await tester.pumpWidget(_park(_dog));
    expect(_anyOf(LivelyLagotto.linesOf(LagottoVoice.dog)), findsNothing);

    await _tap(tester);
    expect(_anyOf(LivelyLagotto.linesOf(LagottoVoice.dog)), findsOneWidget);

    await tester.pumpAndSettle();
    expect(_anyOf(LivelyLagotto.linesOf(LagottoVoice.dog)), findsNothing);
  });

  testWidgets('a puppy on the grass runs off and back', (tester) async {
    await tester.pumpWidget(_park(const LivelyLagotto(
      Lagotto.puppy,
      key: Key('dog'),
      voice: LagottoVoice.puppy,
      width: 60,
      height: 48,
      runs: true,
    )));
    await tester.tap(find.byKey(const Key('dog')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(_anyOf(LivelyLagotto.linesOf(LagottoVoice.puppy)), findsOneWidget);
    final moved = tester.widgetList<Transform>(find.descendant(
      of: find.byKey(const Key('dog')),
      matching: find.byType(Transform),
    ));
    expect(moved.any((t) => t.transform.getTranslation().x.abs() > 20), isTrue);
    await tester.pumpAndSettle();
  });

  testWidgets('five quick taps make a dog dig up a golden truffle', (tester) async {
    await tester.pumpWidget(_park(_dog));
    for (var i = 0; i < LivelySecret.taps; i++) {
      await _tap(tester);
    }

    expect(find.byKey(const Key('lagotto-truffle')), findsOneWidget);
    expect(find.text(LivelyLagotto.truffleLine), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lagotto-truffle')), findsNothing);
  });

  testWidgets('slow taps never find a truffle', (tester) async {
    await tester.pumpWidget(_park(_dog));
    for (var i = 0; i < LivelySecret.taps + 2; i++) {
      await _tap(tester);
      await tester.pump(LivelySecret.tapWindow);
    }
    expect(find.byKey(const Key('lagotto-truffle')), findsNothing);
    await tester.pumpAndSettle();
  });

  for (final voice in [LagottoVoice.puppy, LagottoVoice.sleepy]) {
    testWidgets('a ${voice.name} dog never digs, however fast it is tapped',
        (tester) async {
      await tester.pumpWidget(_park(LivelyLagotto(
        Lagotto.puppy,
        key: const Key('dog'),
        voice: voice,
        width: 60,
        height: 48,
      )));
      for (var i = 0; i < LivelySecret.taps + 2; i++) {
        await _tap(tester);
      }
      expect(find.byKey(const Key('lagotto-truffle')), findsNothing);
      await tester.pumpAndSettle();
    });
  }

  testWidgets('a long press scratches a dog: it leans in and hearts float up',
      (tester) async {
    await tester.pumpWidget(_park(_dog));
    await tester.longPress(find.byKey(const Key('dog')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(_anyOf(LivelyLagotto.petLines), findsOneWidget);
    expect(find.byKey(const Key('lagotto-heart')), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('lagotto-heart')), findsNothing);
  });

  testWidgets('the sleeping dog only mumbles when held, without hearts',
      (tester) async {
    await tester.pumpWidget(_park(const LivelyLagotto(
      Lagotto.dogLie,
      key: Key('dog'),
      voice: LagottoVoice.sleepy,
      width: 150,
      height: 77,
    )));
    await tester.longPress(find.byKey(const Key('dog')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(_anyOf(LivelyLagotto.sleepLines), findsOneWidget);
    expect(find.byKey(const Key('lagotto-heart')), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a dog shaking itself throws off water drops; asleep it never does',
      (tester) async {
    await tester.pumpWidget(_park(_dog));
    var wet = false;
    for (var i = 0; i < 20 && !wet; i++) {
      await _tap(tester);
      wet = find.byKey(const Key('lagotto-drop')).evaluate().isNotEmpty;
      await tester.pumpAndSettle();
    }
    expect(wet, isTrue);

    await tester.pumpWidget(_park(const LivelyLagotto(
      Lagotto.dogLie,
      key: Key('dog'),
      voice: LagottoVoice.sleepy,
      width: 150,
      height: 77,
    )));
    for (var i = 0; i < 20; i++) {
      await _tap(tester);
      expect(find.byKey(const Key('lagotto-drop')), findsNothing);
      await tester.pumpAndSettle();
    }
  });

  group('sounds', () {
    Widget heard(Widget dog, List<String> played) =>
        _park(ThemeChatter(tips: const [], playSound: played.add, child: dog));

    for (final voice in LagottoVoice.values) {
      testWidgets('a tapped ${voice.name} dog makes one of its own sounds', (tester) async {
        final played = <String>[];
        await tester.pumpWidget(heard(
          LivelyLagotto(Lagotto.dogSit, key: const Key('dog'), voice: voice, width: 90, height: 97),
          played,
        ));
        await _tap(tester);

        expect(played, hasLength(1));
        expect(LivelyLagotto.sounds[voice], contains(played.single));
        await tester.pumpAndSettle();
      });
    }

    testWidgets('digging up the golden truffle is a howl', (tester) async {
      final played = <String>[];
      await tester.pumpWidget(heard(_dog, played));
      for (var i = 0; i < LivelySecret.taps; i++) {
        await _tap(tester);
      }
      expect(played.last, LivelyLagotto.truffleSound);
      await tester.pumpAndSettle();
    });
  });

  test('every sound a dog may play is bundled', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final assets = {
      for (final list in LivelyLagotto.sounds.values) ...list,
      LivelyLagotto.truffleSound,
    };
    for (final asset in assets) {
      final data = await rootBundle.load('assets/$asset');
      expect(data.lengthInBytes, greaterThan(1000), reason: asset);
    }
  });
}
