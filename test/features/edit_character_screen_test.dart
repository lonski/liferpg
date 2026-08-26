import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/character/edit_character_screen.dart';
import 'package:liferpg/models/character.dart';

Future<(FakeFirebaseFirestore, Character)> seed() async {
  final db = FakeFirebaseFirestore();
  final ref = await db.collection('characters').add({
    'name': 'Grommash',
    'email': 'g@example.com',
    'level': 3,
    'current_xp': 40,
    'next_level_xp': 100,
    'gold': 250,
    'gold_usd': 12,
    'favour': 0,
    'traits': [
      {'name': 'Siła', 'value': '18'},
    ],
  });
  final snap = await ref.get();
  return (db, Character.fromMap(ref.id, snap.data()!));
}

Future<void> pumpEdit(
  WidgetTester tester,
  FakeFirebaseFirestore db,
  Character character,
) async {
  // Both seams must be overridden: the screen reads traitNamesProvider, which
  // reaches back through charactersProvider to appUserProvider and auth.
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'admin@example.com'),
      )),
    ],
    child: MaterialApp(home: EditCharacterScreen(character: character)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('fields are populated from the character', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    expect(find.text('Grommash'), findsWidgets);
    expect(find.widgetWithText(TextFormField, '3'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '250'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '40'), findsOneWidget);
    expect(find.text('Siła'), findsOneWidget);
  });

  testWidgets('saving writes the edited values to Firestore', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    await tester.enterText(find.byKey(const Key('field-level')), '7');
    await tester.enterText(find.byKey(const Key('field-current_xp')), '55');
    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    final snap = await db.collection('characters').doc(character.id).get();
    expect(snap.data()!['level'], 7);
    expect(snap.data()!['current_xp'], 55);
  });

  testWidgets('a trait can be removed and a new one added', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    await tester.tap(find.byKey(const Key('remove-trait-0')));
    await tester.pumpAndSettle();
    expect(find.text('Siła'), findsNothing);

    await tester.enterText(find.byKey(const Key('new-trait-name')), 'Spryt');
    await tester.enterText(find.byKey(const Key('new-trait-value')), '14');
    await tester.tap(find.byKey(const Key('add-trait')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    final snap = await db.collection('characters').doc(character.id).get();
    final traits = (snap.data()!['traits'] as List<dynamic>)
        .map((t) => Map<String, dynamic>.from(t as Map))
        .toList();
    expect(traits, hasLength(1));
    expect(traits.single['name'], 'Spryt');
    expect(traits.single['value'], '14');
  });

  testWidgets('a non-numeric level blocks the save', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    await tester.enterText(find.byKey(const Key('field-level')), 'abc');
    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    expect(find.text('Podaj liczbę'), findsOneWidget);
    final snap = await db.collection('characters').doc(character.id).get();
    expect(snap.data()!['level'], 3, reason: 'nothing may be written');
  });
}
