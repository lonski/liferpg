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
}
