import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/character/electronics_section.dart';
import 'package:liferpg/models/electronics_days.dart';

Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('charging: count, Ładowanie…, status and ODBIERZ', (tester) async {
    var claimed = 0;
    await tester.pumpWidget(wrap(ElectronicsSection(
      available: 3,
      state: ElectronicsCardState.charging,
      dayFraction: 0.6,
      onClaim: () => claimed++,
    )));
    expect(find.text('DNI ELEKTRONIKI'), findsOneWidget);
    expect(find.byKey(const Key('electronics-count')), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('dostępne'), findsNothing);
    expect(find.text('DZISIEJSZY DZIEŃ'), findsNothing);
    expect(find.text('Ładowanie…'), findsOneWidget);
    expect(find.text('dzień bez elektroniki'), findsOneWidget);
    await tester.tap(find.byKey(const Key('electronics-claim')));
    expect(claimed, 1);
    expect(find.text('ODBIERZ'), findsOneWidget);
  });

  testWidgets('charging without onClaim shows no button', (tester) async {
    await tester.pumpWidget(wrap(const ElectronicsSection(
      available: 3, state: ElectronicsCardState.charging, dayFraction: 0.1)));
    expect(find.byKey(const Key('electronics-claim')), findsNothing);
  });

  testWidgets('pending: question headline, status, ANULUJ with tooltip', (tester) async {
    var cancelled = 0;
    await tester.pumpWidget(wrap(ElectronicsSection(
      available: 3,
      state: ElectronicsCardState.pending,
      dayFraction: 0.6,
      onCancel: () => cancelled++,
    )));
    expect(find.text('Dzień z elektroniką?'), findsOneWidget);
    expect(find.text('czeka na akceptację'), findsOneWidget);
    expect(find.text('ANULUJ'), findsOneWidget);
    expect(find.byTooltip('Anuluj prośbę'), findsOneWidget);
    await tester.tap(find.byKey(const Key('electronics-cancel')));
    expect(cancelled, 1);
    expect(find.byKey(const Key('electronics-claim')), findsNothing);
  });

  testWidgets('pending without onCancel (admin view) shows no button', (tester) async {
    await tester.pumpWidget(wrap(const ElectronicsSection(
      available: 3, state: ElectronicsCardState.pending, dayFraction: 0.6)));
    expect(find.text('czeka na akceptację'), findsOneWidget);
    expect(find.byKey(const Key('electronics-cancel')), findsNothing);
    expect(find.byKey(const Key('electronics-claim')), findsNothing);
  });

  testWidgets('claimed: no button, odebrano dzisiaj', (tester) async {
    await tester.pumpWidget(wrap(ElectronicsSection(
      available: 2,
      state: ElectronicsCardState.claimed,
      dayFraction: 0.6,
      onClaim: () {},
      onCancel: () {},
    )));
    expect(find.text('Dzień z elektroniką'), findsOneWidget);
    expect(find.text('odebrano dzisiaj'), findsOneWidget);
    expect(find.byKey(const Key('electronics-claim')), findsNothing);
    expect(find.byKey(const Key('electronics-cancel')), findsNothing);
  });

  testWidgets('empty: zero and no button even with onClaim', (tester) async {
    await tester.pumpWidget(wrap(ElectronicsSection(
      available: 0,
      state: ElectronicsCardState.empty,
      dayFraction: 0.6,
      onClaim: () {},
    )));
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Ładowanie…'), findsOneWidget);
    expect(find.byKey(const Key('electronics-claim')), findsNothing);
  });

  testWidgets('a 3-digit count at 2x text scale does not overflow the medallion',
      (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
      child: wrap(const ElectronicsSection(
        available: 365,
        state: ElectronicsCardState.charging,
        dayFraction: 0.3,
      )),
    ));
    expect(find.text('365'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact: 52px ring with the action on the same row, to its right',
      (tester) async {
    await tester.pumpWidget(wrap(SizedBox(
      width: 320,
      child: ElectronicsSection(
        available: 3,
        state: ElectronicsCardState.charging,
        dayFraction: 0.5,
        onClaim: () {},
      ),
    )));
    expect(tester.getSize(find.byKey(const Key('electronics-ring'))),
        const Size(52, 52));
    final ring = tester.getCenter(find.byKey(const Key('electronics-ring')));
    final button = tester.getCenter(find.byKey(const Key('electronics-claim')));
    expect(button.dx, greaterThan(ring.dx));
    expect((button.dy - ring.dy).abs(), lessThan(4));
  });

  // 440 = the home screen's max card width. Narrower than ~420 at 2x, the
  // shared LabelledDivider heading itself overflows (pre-existing).
  testWidgets('pending with the cancel button fits a 440px card at 2x text scale',
      (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
      child: wrap(SizedBox(
        width: 440,
        child: ElectronicsSection(
          available: 12,
          state: ElectronicsCardState.pending,
          dayFraction: 0.5,
          onCancel: () {},
        ),
      )),
    ));
    expect(tester.takeException(), isNull);
  });
}
