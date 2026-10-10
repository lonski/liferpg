import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/theme/app_theme.dart';
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
}
