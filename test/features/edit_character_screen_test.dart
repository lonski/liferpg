import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/features/character/edit_character_screen.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/providers/hidden_characters_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<(FakeFirebaseFirestore, Character)> seed({
  bool withGold = true,
}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Admin',
    'email': 'admin@example.com',
    'admin': true,
    'readOnlyOthers': false,
  });
  final ref = await db.collection('characters').add({
    'name': 'Grommash',
    'email': 'g@example.com',
    'level': 3,
    'current_xp': 40,
    'next_level_xp': 100,
    if (withGold) 'gold': 250,
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
  // All three seams must be overridden: the screen reads traitNamesProvider
  // (which reaches back through charactersProvider to appUserProvider and
  // auth) and, for the hide action, hiddenCharacterIdsProvider (which needs
  // both appUserProvider and shared_preferences).
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'admin@example.com'),
      )),
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
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

  // The hide action lives here rather than on the character card: this
  // screen is only ever reached through the card's edit icon, which is
  // already gated on admin (canEdit) -- readOnlyOthers never sees it, so no
  // separate readOnlyOthers-can't-hide test is needed here.
  testWidgets('tapping hide adds the character to the hidden set and closes',
      (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EditCharacterScreen)),
    );

    await tester.tap(find.byKey(const Key('hide-character')));
    await tester.pumpAndSettle();

    expect(container.read(hiddenCharacterIdsProvider), contains(character.id));
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

  testWidgets('an edited trait value is persisted', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    await tester.enterText(find.byKey(const Key('trait-value-0')), '19');
    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    final snap = await db.collection('characters').doc(character.id).get();
    final traits = (snap.data()!['traits'] as List<dynamic>)
        .map((t) => Map<String, dynamic>.from(t as Map))
        .toList();
    expect(traits.single['name'], 'Siła');
    expect(traits.single['value'], '19');
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

  testWidgets('a decimal typed into gold is persisted', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    await tester.enterText(find.byKey(const Key('field-gold')), '7.5');
    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    final snap = await db.collection('characters').doc(character.id).get();
    expect(snap.data()!['gold'], 7.5);
  });

  // I3: an empty field used to parse to null, which copyWith reads as "keep
  // the old value" -- so clearing a field popped the screen having written
  // nothing at all.
  testWidgets('clearing gold writes 0', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    await tester.enterText(find.byKey(const Key('field-gold')), '');
    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    final snap = await db.collection('characters').doc(character.id).get();
    expect(snap.data()!['gold'], 0);
  });

  // I5: the "empty saves as 0" fix over-corrected. A character that never had
  // a gold field must not acquire `gold: 0` just because the admin edited the
  // level -- that made a "ZŁOTO 0 zł" row appear on a card that never had one.
  testWidgets('a save that leaves an absent gold empty keeps it absent',
      (tester) async {
    final (db, character) = await seed(withGold: false);
    await pumpEdit(tester, db, character);

    await tester.enterText(find.byKey(const Key('field-level')), '7');
    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    final data = (await db.collection('characters').doc(character.id).get())
        .data()!;
    expect(data['level'], 7, reason: 'the level the admin did edit must land');
    expect(data['gold'], isNull, reason: 'absent gold must not become 0');
  });

  testWidgets('a save that leaves an absent level empty keeps it absent',
      (tester) async {
    final (db, character) = await seed(withGold: false);
    // Rebuild the character without a level, as documents in production have.
    final noLevel = Character(
      id: character.id,
      name: character.name,
      email: character.email,
      currentXp: character.currentXp,
      nextLevelXp: character.nextLevelXp,
      favour: character.favour,
      traits: character.traits,
    );
    await pumpEdit(tester, db, noLevel);

    await tester.enterText(find.byKey(const Key('field-current_xp')), '55');
    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    final data = (await db.collection('characters').doc(character.id).get())
        .data()!;
    expect(data['current_xp'], 55);
    expect(data['level'], isNull);
  });

  // I4: the name box is owned by Autocomplete. With only a shadow controller
  // it never cleared, so the second add saw a stale-looking but internally
  // empty field and silently did nothing.
  testWidgets('two traits can be added in a row, clearing the name each time',
      (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    String nameFieldText() => tester
        .widget<TextField>(find.byKey(const Key('new-trait-name')))
        .controller!
        .text;

    await tester.enterText(find.byKey(const Key('new-trait-name')), 'Spryt');
    await tester.enterText(find.byKey(const Key('new-trait-value')), '14');
    await tester.tap(find.byKey(const Key('add-trait')));
    await tester.pumpAndSettle();
    expect(nameFieldText(), isEmpty);

    await tester.enterText(find.byKey(const Key('new-trait-name')), 'Charyzma');
    await tester.enterText(find.byKey(const Key('new-trait-value')), '9');
    await tester.tap(find.byKey(const Key('add-trait')));
    await tester.pumpAndSettle();
    expect(nameFieldText(), isEmpty);

    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    final snap = await db.collection('characters').doc(character.id).get();
    final traits = (snap.data()!['traits'] as List<dynamic>)
        .map((t) => Map<String, dynamic>.from(t as Map))
        .toList();
    expect(traits.map((t) => t['name']), containsAll(['Spryt', 'Charyzma']));
  });

  // M15: React's + button only required a non-empty name.
  testWidgets('a trait with an empty value can still be added', (tester) async {
    final (db, character) = await seed();
    await pumpEdit(tester, db, character);

    await tester.enterText(find.byKey(const Key('new-trait-name')), 'Honor');
    await tester.tap(find.byKey(const Key('add-trait')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-character')));
    await tester.pumpAndSettle();

    final snap = await db.collection('characters').doc(character.id).get();
    final traits = (snap.data()!['traits'] as List<dynamic>)
        .map((t) => Map<String, dynamic>.from(t as Map))
        .toList();
    expect(traits.map((t) => t['name']), contains('Honor'));
  });
}
