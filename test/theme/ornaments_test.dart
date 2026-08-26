import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/theme/ornaments.dart';

// NOTE: deliberately not wrapping in a Scaffold. On Flutter 3.47, Scaffold
// unconditionally builds a _FloatingActionButtonTransition (a ScaleTransition
// + RotationTransition) even with no floatingActionButton, which itself
// contains two Transform widgets. That would pollute the Transform count
// assertion in the CornerOrnament test below, which is only about the
// widget under test. MaterialApp + Center still provides everything these
// widgets need (Directionality, MaterialLocalizations, text styling).
Widget wrap(Widget child) => MaterialApp(home: Center(child: child));

void main() {
  testWidgets('OrnamentDivider renders the diamond glyph', (tester) async {
    await tester.pumpWidget(wrap(const OrnamentDivider()));
    expect(find.text('✦'), findsOneWidget);
  });

  testWidgets('CornerOrnament mirrors horizontally when asked', (tester) async {
    await tester.pumpWidget(wrap(const CornerOrnament(mirrored: true)));
    expect(find.text('❧'), findsOneWidget);
    expect(find.byType(Transform), findsOneWidget);
  });

  testWidgets('TopBand shows its label and trailing widget', (tester) async {
    await tester.pumpWidget(wrap(const TopBand(
      label: '✦ Karta Postaci ✦',
      trailing: Icon(Icons.edit),
    )));
    expect(find.text('✦ Karta Postaci ✦'), findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });

  testWidgets('BottomBand renders its rule', (tester) async {
    await tester.pumpWidget(wrap(const BottomBand()));
    expect(find.text('— ✦ —'), findsOneWidget);
  });
}
