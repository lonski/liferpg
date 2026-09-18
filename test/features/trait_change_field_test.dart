import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/requests/trait_change_field.dart';
import 'package:liferpg/models/change_request.dart';

Future<Future<TraitChange?> Function()> pumpField(
  WidgetTester tester, {
  TraitChange? initial,
}) async {
  TraitChange? latest = initial;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: TraitChangeField(
            initial: initial,
            onChanged: (trait) => latest = trait,
          ),
        ),
      ),
    ),
  );
  return () async => latest;
}

void main() {
  testWidgets('collapsed by default: only the add button shows', (
    tester,
  ) async {
    await pumpField(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-trait-button')), findsOneWidget);
    expect(find.byKey(const Key('trait-name')), findsNothing);
    expect(find.byKey(const Key('trait-value')), findsNothing);
  });

  testWidgets('tapping the add button reveals the name and value fields', (
    tester,
  ) async {
    await pumpField(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-trait-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-trait-button')), findsNothing);
    expect(find.byKey(const Key('trait-name')), findsOneWidget);
    expect(find.byKey(const Key('trait-value')), findsOneWidget);
    expect(find.byKey(const Key('remove-trait')), findsOneWidget);
  });

  testWidgets('typing a name and value reports the trait change', (
    tester,
  ) async {
    final latest = await pumpField(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-trait-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('trait-name')), 'Siła');
    await tester.enterText(find.byKey(const Key('trait-value')), '12');
    await tester.pump();

    expect(await latest(), const TraitChange(name: 'Siła', value: '12'));
  });

  testWidgets('expanded with an empty name reports no trait', (tester) async {
    final latest = await pumpField(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-trait-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('trait-value')), '12');
    await tester.pump();

    expect(await latest(), isNull);
  });

  testWidgets('tapping remove collapses the field and clears the trait', (
    tester,
  ) async {
    final latest = await pumpField(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add-trait-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('trait-name')), 'Siła');
    await tester.enterText(find.byKey(const Key('trait-value')), '12');
    await tester.pump();
    expect(await latest(), isNotNull);

    await tester.tap(find.byKey(const Key('remove-trait')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-trait-button')), findsOneWidget);
    expect(await latest(), isNull);
  });

  testWidgets('prefills already expanded from an initial trait', (
    tester,
  ) async {
    await pumpField(
      tester,
      initial: const TraitChange(name: 'Siła', value: '12'),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('add-trait-button')), findsNothing);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('trait-value')))
          .controller
          ?.text,
      '12',
    );
  });
}
