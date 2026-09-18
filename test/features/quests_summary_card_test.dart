import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/quests/quests_screen.dart';
import 'package:liferpg/features/quests/quests_summary_card.dart';

Future<FakeFirebaseFirestore> _seedUser() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': false,
    'readOnlyOthers': false,
  });
  await db.collection('characters').doc('c1').set({
    'name': 'Grommash',
    'email': 'ala@example.com',
    'current_xp': 0,
    'next_level_xp': 100,
    'favour': 0,
    'traits': [],
  });
  return db;
}

Future<void> _pump(WidgetTester tester, FakeFirebaseFirestore db) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
    ],
    child: const MaterialApp(
      home: Scaffold(body: QuestsSummaryCard()),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty state when nothing is assigned', (tester) async {
    await _pump(tester, await _seedUser());

    expect(find.text('BRAK PRZYPISANYCH ZADAŃ'), findsOneWidget);
    expect(find.text('ZADANIA DO WYKONANIA'), findsNothing);
  });

  testWidgets('counts a quest assigned to my own character', (tester) async {
    final db = await _seedUser();
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
    await _pump(tester, db);

    expect(find.text('ZADANIA DO WYKONANIA'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  // A pending-review quest is already done from the player's side -- it
  // must not inflate the "do wykonania" badge, only the separate "oczekuje"
  // count.
  testWidgets(
      'a pending-review quest counts as "oczekuje", not as assigned',
      (tester) async {
    final db = await _seedUser();
    await db.collection('quests').add({
      'title': 'Ugotuj obiad',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'assignedToCharacterId': 'c1',
      'assignedToCharacterName': 'Grommash',
      'assignedToEmail': 'ala@example.com',
      'status': 'pending_review',
      'reward': {'current_xp': 30},
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _pump(tester, db);

    expect(find.text('BRAK PRZYPISANYCH ZADAŃ'), findsOneWidget);
    expect(find.text('oczekuje'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('counts open board quests regardless of who they are assigned to',
      (tester) async {
    final db = await _seedUser();
    await db.collection('quests').add({
      'title': 'Posprzątaj garaż',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 50},
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _pump(tester, db);

    expect(find.text('na tablicy'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('tapping the card opens QuestsScreen', (tester) async {
    await _pump(tester, await _seedUser());

    await tester.tap(find.byKey(const Key('quests-summary-card')));
    await tester.pumpAndSettle();

    expect(find.byType(QuestsScreen), findsOneWidget);
  });
}
