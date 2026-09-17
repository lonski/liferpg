import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/quests/quest_detail_screen.dart';

Future<void> _pump(WidgetTester tester, FakeFirebaseFirestore db, String questId) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
    ],
    child: MaterialApp(home: QuestDetailScreen(questId: questId)),
  ));
  await tester.pumpAndSettle();
}

Future<void> _seedSelf(FakeFirebaseFirestore db, {String? characterId}) async {
  await db.collection('users').doc('u1').set({
    'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
  });
  if (characterId != null) {
    await db.collection('characters').doc(characterId).set({
      'name': 'Grommash', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': [],
    });
  }
}

void main() {
  testWidgets('renders the quest when the id exists', (tester) async {
    final db = FakeFirebaseFirestore();
    final ref = await db.collection('quests').add({
      'title': 'Posprzątaj garaż',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 50},
    });

    await _pump(tester, db, ref.id);

    expect(find.text('Posprzątaj garaż'), findsOneWidget);
    expect(find.text('Wystawione przez: Bob'), findsOneWidget);
  });

  testWidgets('shows a not-found state for a missing id', (tester) async {
    final db = FakeFirebaseFirestore();

    await _pump(tester, db, 'does-not-exist');

    expect(find.text('Nie znaleziono zadania'), findsOneWidget);
  });

  testWidgets('shows no actions for an open quest when the viewer owns no character', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSelf(db);
    final ref = await db.collection('quests').add({
      'title': 'Posprzątaj garaż',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 50},
    });

    await _pump(tester, db, ref.id);

    expect(find.textContaining('Podejmij'), findsNothing);
  });

  testWidgets('shows a Podejmij action for an open quest posted by someone else', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSelf(db, characterId: 'c1');
    final ref = await db.collection('quests').add({
      'title': 'Posprzątaj garaż',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 50},
    });

    await _pump(tester, db, ref.id);
    expect(find.textContaining('Podejmij'), findsOneWidget);

    await tester.tap(find.textContaining('Podejmij'));
    await tester.pumpAndSettle();

    final quest = (await db.collection('quests').doc(ref.id).get()).data()!;
    expect(quest['status'], 'assigned');
    expect(quest['assignedToCharacterId'], 'c1');
  });

  testWidgets('shows a Wycofaj action for my own open quest', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSelf(db, characterId: 'c1');
    final ref = await db.collection('quests').add({
      'title': 'Zrób pranie',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'status': 'open',
      'reward': {'current_xp': 20},
    });

    await _pump(tester, db, ref.id);

    expect(find.textContaining('Wycofaj'), findsOneWidget);
  });

  testWidgets('shows Ukończ/Porzuć for a quest assigned to my character', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSelf(db, characterId: 'c1');
    final ref = await db.collection('quests').add({
      'title': 'Ugotuj obiad',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'assignedToCharacterId': 'c1',
      'assignedToCharacterName': 'Grommash',
      'assignedToEmail': 'ala@example.com',
      'status': 'assigned',
      'reward': {'current_xp': 30},
    });

    await _pump(tester, db, ref.id);

    expect(find.textContaining('Ukończ'), findsOneWidget);
    expect(find.textContaining('Porzuć'), findsOneWidget);
  });

  testWidgets('shows the pending-review badge and no actions once marked complete', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSelf(db, characterId: 'c1');
    final ref = await db.collection('quests').add({
      'title': 'Ugotuj obiad',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'assignedToCharacterId': 'c1',
      'assignedToCharacterName': 'Grommash',
      'assignedToEmail': 'ala@example.com',
      'status': 'pending_review',
      'reward': {'current_xp': 30},
    });

    await _pump(tester, db, ref.id);

    expect(find.text('OCZEKUJE NA AKCEPTACJĘ'), findsOneWidget);
    expect(find.textContaining('Ukończ'), findsNothing);
    expect(find.textContaining('Porzuć'), findsNothing);
  });

  testWidgets('shows the outcome badge for a completed quest', (tester) async {
    final db = FakeFirebaseFirestore();
    await _seedSelf(db);
    final ref = await db.collection('quests').add({
      'title': 'Wynieś śmieci',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'completed',
      'reward': {'current_xp': 15},
    });

    await _pump(tester, db, ref.id);

    expect(find.text('ZAAKCEPTOWANE'), findsOneWidget);
  });
}
