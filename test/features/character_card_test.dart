import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/character/character_card.dart';
import 'package:liferpg/models/character.dart';

Character sample({List<Trait> traits = const []}) => Character(
      id: 'c1',
      name: 'Grommash',
      clazz: 'Wojownik',
      email: 'g@example.com',
      level: 3,
      currentXp: 40,
      nextLevelXp: 100,
      gold: 250,
      goldUsd: 12,
      favour: 0,
      traits: traits,
    );

Widget wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('renders name, class, level, XP and gold in both currencies',
      (tester) async {
    await tester.pumpWidget(
      wrap(CharacterCard(character: sample(), canEdit: false)),
    );

    expect(find.text('Grommash'), findsOneWidget);
    expect(find.text('Wojownik'), findsOneWidget);
    expect(find.text('Poziom'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('250 zł'), findsOneWidget);
    expect(find.text('12 \$'), findsOneWidget);
    expect(find.text('40 / 100 XP'), findsOneWidget);
  });

  testWidgets('tapping the XP bar toggles the remaining-XP hint',
      (tester) async {
    await tester.pumpWidget(
      wrap(CharacterCard(character: sample(), canEdit: false)),
    );

    expect(find.textContaining('Do następnego poziomu'), findsNothing);

    await tester.tap(find.byKey(const Key('xp-bar')));
    await tester.pumpAndSettle();
    expect(find.text('Do następnego poziomu: 60 XP'), findsOneWidget);

    await tester.tap(find.byKey(const Key('xp-bar')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Do następnego poziomu'), findsNothing);
  });

  testWidgets('renders traits under a Cechy heading', (tester) async {
    await tester.pumpWidget(wrap(CharacterCard(
      character: sample(traits: const [Trait(name: 'Siła', value: '18')]),
      canEdit: false,
    )));

    expect(find.text('Cechy'), findsOneWidget);
    expect(find.text('Siła'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
  });

  testWidgets('the edit affordance appears only when canEdit', (tester) async {
    await tester.pumpWidget(
      wrap(CharacterCard(character: sample(), canEdit: false)),
    );
    expect(find.byKey(const Key('edit-character')), findsNothing);

    await tester.pumpWidget(
      wrap(CharacterCard(character: sample(), canEdit: true)),
    );
    expect(find.byKey(const Key('edit-character')), findsOneWidget);
  });
}
