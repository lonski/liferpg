import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/main.dart';

void main() {
  testWidgets('LifeRpgApp builds a MaterialApp', (tester) async {
    await tester.pumpWidget(const LifeRpgApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
