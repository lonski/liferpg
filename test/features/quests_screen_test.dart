import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/quests/quests_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(WidgetTester tester, FakeFirebaseFirestore db) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
    ],
    child: const MaterialApp(home: QuestsScreen()),
  ));
  await tester.pumpAndSettle();
}

Future<FakeFirebaseFirestore> _seed() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
  });
  await db.collection('characters').doc('c1').set({
    'name': 'Grommash', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': [],
  });
  await db.collection('quests').add({
    'title': 'Posprzątaj garaż',
    'posterUid': 'u2',
    'posterEmail': 'bob@example.com',
    'posterName': 'Bob',
    'status': 'open',
    'reward': {'current_xp': 50},
    'createdAt': FieldValue.serverTimestamp(),
  });
  return db;
}

Future<FakeFirebaseFirestore> _seedMine() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
  });
  await db.collection('characters').doc('c1').set({
    'name': 'Grommash', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': [],
  });
  await db.collection('quests').add({
    'title': 'Ugotuj obiad',
    'posterUid': 'u2',
    'posterEmail': 'bob@example.com',
    'posterName': 'Bob',
    'assignedToCharacterId': 'c1',
    'assignedToCharacterName': 'Grommash',
    'assignedToEmail': 'ala@example.com',
    'status': 'assigned',
    'reward': {'current_xp': 30},
    'createdAt': FieldValue.serverTimestamp(),
  });
  await db.collection('quests').add({
    'title': 'Zrób pranie',
    'posterUid': 'u1',
    'posterEmail': 'ala@example.com',
    'posterName': 'Ala',
    'status': 'open',
    'reward': {'current_xp': 20},
    'createdAt': FieldValue.serverTimestamp(),
  });
  return db;
}

void main() {
  testWidgets('the Tablica tab lists open quests with a Podejmij action', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    expect(find.text('Posprzątaj garaż'), findsOneWidget);
    expect(find.textContaining('Podejmij'), findsOneWidget);
  });

  testWidgets('tapping Podejmij with exactly one owned character takes it immediately', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.tap(find.textContaining('Podejmij'));
    await tester.pumpAndSettle();

    final quest = (await db.collection('quests').get()).docs.single.data();
    expect(quest['status'], 'assigned');
    expect(quest['assignedToCharacterId'], 'c1');
    expect(find.text('Posprzątaj garaż'), findsNothing);
  });

  testWidgets('Moje shows an assigned-to-me quest (Ukończ/Porzuć) and a posted-by-me one (Wycofaj)', (tester) async {
    final db = await _seedMine();
    await _pump(tester, db);

    await tester.tap(find.byKey(const Key('quests-tab-mine')));
    await tester.pumpAndSettle();

    expect(find.text('Ugotuj obiad'), findsOneWidget);
    expect(find.textContaining('Ukończ'), findsOneWidget);
    expect(find.textContaining('Porzuć'), findsOneWidget);
    expect(find.text('Zrób pranie'), findsOneWidget);
    expect(find.textContaining('Wycofaj'), findsOneWidget);
  });

  testWidgets('tapping Ukończ raises a linked change request and clears the action', (tester) async {
    final db = await _seedMine();
    await _pump(tester, db);
    await tester.tap(find.byKey(const Key('quests-tab-mine')));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Ukończ'));
    await tester.pumpAndSettle();

    final quests = (await db.collection('quests').get()).docs;
    final ugotuj = quests.firstWhere((d) => d.data()['title'] == 'Ugotuj obiad');
    expect(ugotuj.data()['status'], 'pending_review');
    expect((await db.collection('change_requests').get()).docs, hasLength(1));
  });

  testWidgets('Dziennik shows completed (green) and failed (red) outcomes', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
    });
    await db.collection('quests').add({
      'title': 'Wynieś śmieci',
      'posterUid': 'u2', 'posterEmail': 'bob@example.com', 'posterName': 'Bob',
      'status': 'completed', 'reward': {'current_xp': 15},
      'createdAt': FieldValue.serverTimestamp(),
    });
    await db.collection('quests').add({
      'title': 'Umyj okna',
      'posterUid': 'u2', 'posterEmail': 'bob@example.com', 'posterName': 'Bob',
      'status': 'failed', 'reward': {'current_xp': 25},
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _pump(tester, db);

    await tester.tap(find.byKey(const Key('quests-tab-log')));
    await tester.pumpAndSettle();

    expect(find.text('Wynieś śmieci'), findsOneWidget);
    expect(find.text('ZAAKCEPTOWANE'), findsOneWidget);
    expect(find.text('Umyj okna'), findsOneWidget);
    expect(find.text('ODRZUCONE'), findsOneWidget);

    final acceptedBadge = tester.widget<Text>(find.text('ZAAKCEPTOWANE'));
    final rejectedBadge = tester.widget<Text>(find.text('ODRZUCONE'));
    expect(acceptedBadge.style!.color, isNot(rejectedBadge.style!.color));
  });
}
