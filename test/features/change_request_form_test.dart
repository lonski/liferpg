import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/requests/change_request_form.dart';
import 'package:liferpg/models/change_request.dart';

// The brief's helper called `tester.pumpWidget(...)` without awaiting it,
// which trips flutter_test's "guarded function conflict" check the moment a
// later awaited pump (e.g. pumpAndSettle) runs before the unawaited pump has
// finished. Mechanical repair: make pumpForm itself async and await the
// pump, so callers `await pumpForm(tester)` instead of calling it bare. Every
// expectation below is unchanged.
Future<Future<ChangeSet> Function()> pumpForm(
  WidgetTester tester, {
  ChangeSet? initial,
}) async {
  var latest = const ChangeSet();
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: ChangeRequestForm(
          initial: initial,
          onChanged: (changes, _) => latest = changes,
        ),
      ),
    ),
  ));
  return () async => latest;
}

void main() {
  testWidgets('reports the typed deltas', (tester) async {
    final latest = await pumpForm(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field-current_xp')), '50');
    await tester.enterText(find.byKey(const Key('field-gold')), '-10');
    await tester.pump();

    final changes = await latest();
    expect(changes.currentXp, 50);
    expect(changes.gold, -10);
  });

  testWidgets('an empty field reports null rather than zero', (tester) async {
    final latest = await pumpForm(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field-current_xp')), '50');
    await tester.pump();
    expect((await latest()).currentXp, 50);
    await tester.enterText(find.byKey(const Key('field-current_xp')), '');
    await tester.pump();

    expect((await latest()).currentXp, isNull);
    expect((await latest()).isEmpty, isTrue);
  });

  testWidgets('adds a trait upsert', (tester) async {
    final latest = await pumpForm(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('trait-name')), 'Siła');
    await tester.enterText(find.byKey(const Key('trait-value')), '12');
    await tester.tap(find.byKey(const Key('add-trait')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('trait-row-Siła')), findsOneWidget);
    expect((await latest()).traits.single,
        const TraitChange(name: 'Siła', value: '12'));
  });

  testWidgets('a trait with an empty name is not added', (tester) async {
    final latest = await pumpForm(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field-current_xp')), '50');
    await tester.pump();
    expect((await latest()).currentXp, 50);

    await tester.enterText(find.byKey(const Key('trait-value')), '12');
    await tester.tap(find.byKey(const Key('add-trait')));
    await tester.pumpAndSettle();

    expect((await latest()).traits, isEmpty);
  });

  testWidgets('prefills from an initial ChangeSet', (tester) async {
    await pumpForm(
      tester,
      initial: const ChangeSet(
        currentXp: 50,
        traits: [TraitChange(name: 'Siła', value: '12')],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('field-current_xp')))
          .controller
          ?.text,
      '50',
    );
    expect(find.byKey(const Key('trait-row-Siła')), findsOneWidget);
  });

  testWidgets('shows the Polish validation message for non-numeric input',
      (tester) async {
    await pumpForm(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field-current_xp')), 'abc');
    await tester.pumpAndSettle();

    expect(find.text('Podaj liczbę'), findsOneWidget);
  });

  testWidgets('shows a validation message when reason is left empty',
      (tester) async {
    await pumpForm(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field-reason')), 'x');
    await tester.enterText(find.byKey(const Key('field-reason')), '');
    await tester.pump();

    expect(find.text('Podaj powód'), findsOneWidget);
  });
}
