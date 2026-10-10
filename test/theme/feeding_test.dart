import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/theme/app_theme.dart';
import 'package:liferpg/theme/chatter.dart';
import 'package:liferpg/theme/decor.dart';
import 'package:liferpg/theme/lagotto_decor.dart';
import 'package:liferpg/theme/lively.dart';
import 'package:liferpg/theme/lively_kurczak.dart';
import 'package:liferpg/theme/lively_lagotto.dart';

const _hen = LivelyKurczak(
  Kurczak.hen,
  key: Key('animal'),
  voice: KurczakVoice.hen,
  width: 90,
  height: 84,
);

const _dog = LivelyLagotto(
  Lagotto.dogSit,
  key: Key('animal'),
  voice: LagottoVoice.dog,
  width: 76,
  height: 82,
);

/// [food] on the left, [animal] on the right; sounds land in [played].
Future<void> _pump(WidgetTester tester, Widget food, Widget animal, {List<String>? played}) =>
    tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(RpgTheme.kurczaki),
      home: ThemeChatter(
        tips: const [],
        playSound: played?.add,
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.only(top: 120),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [food, animal],
            ),
          ),
        ),
      ),
    ));

/// Drags a handful from [food] and drops it on the animal.
Future<void> _feed(WidgetTester tester, Finder food) async {
  final gesture = await tester.startGesture(tester.getCenter(food));
  final target = tester.getCenter(find.byKey(const Key('animal')));
  for (var i = 1; i <= 5; i++) {
    await gesture.moveTo(Offset.lerp(tester.getCenter(food), target, i / 5)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Finder _saying(List<String> lines) =>
    find.byWidgetPredicate((w) => w is Text && lines.contains(w.data));

void main() {
  setUp(() => Lively.random = math.Random(5));

  testWidgets('grain dropped on a hen: she eats, thanks, clucks and hearts rise',
      (tester) async {
    final played = <String>[];
    await _pump(tester, const GrainPile(), _hen, played: played);
    await _feed(tester, find.byType(GrainPile));

    expect(_saying(LivelyKurczak.feedLines[KurczakVoice.hen]!), findsOneWidget);
    expect(find.byKey(const Key('kurczak-heart')), findsWidgets);
    expect(played, [LivelyKurczak.sounds[KurczakVoice.hen]!.first]);
    // The pile is bottomless: it is still there to drag again.
    expect(find.byType(GrainPile), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('kibble dropped on a dog: it eats and thanks', (tester) async {
    await _pump(tester, const KibbleBowl(), _dog);
    await _feed(tester, find.byType(KibbleBowl));

    expect(_saying(LivelyLagotto.feedLines[LagottoVoice.dog]!), findsOneWidget);
    expect(find.byKey(const Key('lagotto-fed-heart')), findsWidgets);
    await tester.pumpAndSettle();
  });

  testWidgets('a hen turns her beak up at kibble', (tester) async {
    await _pump(tester, const KibbleBowl(), _hen);
    await _feed(tester, find.byType(KibbleBowl));

    expect(_saying(LivelyKurczak.feedLines[KurczakVoice.hen]!), findsNothing);
    await tester.pumpAndSettle();
  });

  testWidgets('a dog ignores grain', (tester) async {
    await _pump(tester, const GrainPile(), _dog);
    await _feed(tester, find.byType(GrainPile));

    expect(_saying(LivelyLagotto.feedLines[LagottoVoice.dog]!), findsNothing);
    await tester.pumpAndSettle();
  });
}
