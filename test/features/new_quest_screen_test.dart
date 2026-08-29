import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/quests/new_quest_screen.dart';

Future<void> _pump(WidgetTester tester, FakeFirebaseFirestore db) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
    ],
    child: const MaterialApp(home: NewQuestScreen()),
  ));
  await tester.pumpAndSettle();
}

Future<FakeFirebaseFirestore> _seed() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
  });
  await db.collection('quest_roster').doc('c1').set({
    'characterName': 'Grommash', 'email': 'ala@example.com',
  });
  return db;
}

void main() {
  testWidgets('leaving the character picker empty posts to the board', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.enterText(find.byKey(const Key('quest-title')), 'Posprzątaj garaż');
    await tester.enterText(find.byKey(const Key('quest-reward-xp')), '50');
    await tester.tap(find.byKey(const Key('submit-quest')));
    await tester.pumpAndSettle();

    final quest = (await db.collection('quests').get()).docs.single.data();
    expect(quest['status'], 'open');
    expect(quest.containsKey('assignedToCharacterId'), isFalse);
  });

  testWidgets('picking a roster character assigns directly', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.enterText(find.byKey(const Key('quest-title')), 'Ugotuj obiad');
    await tester.enterText(find.byKey(const Key('quest-reward-xp')), '30');
    await tester.tap(find.byKey(const Key('quest-target-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grommash').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('submit-quest')));
    await tester.pumpAndSettle();

    final quest = (await db.collection('quests').get()).docs.single.data();
    expect(quest['status'], 'assigned');
    expect(quest['assignedToCharacterId'], 'c1');
  });
}
