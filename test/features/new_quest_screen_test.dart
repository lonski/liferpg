import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/quests/new_quest_screen.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/quest.dart';

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
  // The poster's own character -- "Wystawione przez:" shows this name, not
  // the account's display name, and it's what the submit button requires
  // before it enables.
  await db.collection('characters').doc('poster1').set({
    'name': 'Elwenna', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': [],
  });
  await db.collection('quest_roster').doc('c1').set({
    'characterName': 'Grommash', 'email': 'ala@example.com',
  });
  return db;
}

void main() {
  testWidgets('submit stays disabled with an empty title', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    ElevatedButton button() =>
        tester.widget<ElevatedButton>(find.byKey(const Key('submit-quest')));
    expect(button().onPressed, isNull);

    await tester.tap(find.byKey(const Key('submit-quest')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Podaj tytuł'), findsOneWidget);

    expect((await db.collection('quests').get()).docs, isEmpty,
        reason: 'a disabled button must not have created a quest');
  });

  testWidgets('submit stays disabled with an empty reward', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.enterText(find.byKey(const Key('quest-title')), 'Posprzątaj garaż');
    await tester.pump();

    ElevatedButton button() =>
        tester.widget<ElevatedButton>(find.byKey(const Key('submit-quest')));
    expect(button().onPressed, isNull);

    await tester.tap(find.byKey(const Key('submit-quest')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Wprowadź nagrodę'), findsOneWidget);

    expect((await db.collection('quests').get()).docs, isEmpty);
  });

  testWidgets('filling in title and reward enables submit', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.enterText(find.byKey(const Key('quest-title')), 'Posprzątaj garaż');
    await tester.enterText(find.byKey(const Key('quest-reward-xp')), '50');
    await tester.pump();

    final button =
        tester.widget<ElevatedButton>(find.byKey(const Key('submit-quest')));
    expect(button.onPressed, isNotNull);
  });

  testWidgets('leaving the character picker empty posts to the board', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.enterText(find.byKey(const Key('quest-title')), 'Posprzątaj garaż');
    await tester.enterText(find.byKey(const Key('quest-reward-xp')), '50');
    await tester.pump();
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

  testWidgets('the trait editor is collapsed behind an add button by '
      'default', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    expect(find.byKey(const Key('add-trait-button')), findsOneWidget);
    expect(find.byKey(const Key('trait-name')), findsNothing);
  });

  testWidgets('adding a trait includes it in the reward', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.enterText(find.byKey(const Key('quest-title')), 'Posprzątaj garaż');
    await tester.enterText(find.byKey(const Key('quest-reward-xp')), '50');
    await tester.tap(find.byKey(const Key('add-trait-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('trait-name')), 'Siła');
    await tester.enterText(find.byKey(const Key('trait-value')), '3');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-quest')));
    await tester.pumpAndSettle();

    final quest = (await db.collection('quests').get()).docs.single.data();
    final reward = Map<String, dynamic>.from(quest['reward'] as Map);
    expect(reward['current_xp'], 50);
    final traits = (reward['traits'] as List).cast<Map>();
    expect(traits.single['name'], 'Siła');
    expect(traits.single['value'], '3');
  });

  testWidgets('posted quest is attributed to the poster\'s character, not their account name', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.enterText(find.byKey(const Key('quest-title')), 'Posprzątaj garaż');
    await tester.enterText(find.byKey(const Key('quest-reward-xp')), '50');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-quest')));
    await tester.pumpAndSettle();

    final quest = (await db.collection('quests').get()).docs.single.data();
    expect(quest['posterName'], 'Elwenna');
  });

  testWidgets('the poster character picker only appears with more than one own character', (tester) async {
    final db = await _seed();
    await _pump(tester, db);
    expect(find.byKey(const Key('poster-character-picker')), findsNothing);
  });

  testWidgets('picking among multiple own characters sets that character as poster', (tester) async {
    final db = await _seed();
    await db.collection('characters').doc('poster2').set({
      'name': 'Thoradin', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': [],
    });
    await _pump(tester, db);

    expect(find.byKey(const Key('poster-character-picker')), findsOneWidget);
    await tester.tap(find.byKey(const Key('poster-character-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thoradin').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('quest-title')), 'Wynieś śmieci');
    await tester.enterText(find.byKey(const Key('quest-reward-xp')), '15');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-quest')));
    await tester.pumpAndSettle();

    final quest = (await db.collection('quests').get()).docs.single.data();
    expect(quest['posterName'], 'Thoradin');
  });

  group('editing an already-posted quest', () {
    Future<void> pumpEdit(WidgetTester tester, FakeFirebaseFirestore db, Quest quest) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
            signedIn: true,
            mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
          )),
        ],
        child: MaterialApp(home: NewQuestScreen(editing: quest)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('pre-fills title/description/XP/trait and hides the poster/target pickers',
        (tester) async {
      final db = await _seed();
      final ref = await db.collection('quests').add({
        'title': 'Posprzątaj garaż',
        'description': 'W tym pod samochodem',
        'posterUid': 'u1',
        'posterEmail': 'ala@example.com',
        'posterName': 'Elwenna',
        'status': 'open',
        'reward': {
          'current_xp': 50,
          'traits': [
            {'name': 'Porządek', 'value': '1'},
          ],
        },
      });
      final quest = Quest(
        id: ref.id,
        title: 'Posprzątaj garaż',
        description: 'W tym pod samochodem',
        posterUid: 'u1',
        posterEmail: 'ala@example.com',
        posterName: 'Elwenna',
        status: QuestStatus.open,
        reward: const ChangeSet(
          currentXp: 50,
          traits: [TraitChange(name: 'Porządek', value: '1')],
        ),
      );

      await pumpEdit(tester, db, quest);

      expect(find.text('Edytuj zadanie'), findsOneWidget);
      final titleField = tester.widget<TextField>(find.byKey(const Key('quest-title')));
      expect(titleField.controller!.text, 'Posprzątaj garaż');
      final descriptionField =
          tester.widget<TextField>(find.byKey(const Key('quest-description')));
      expect(descriptionField.controller!.text, 'W tym pod samochodem');
      final xpField = tester.widget<TextField>(find.byKey(const Key('quest-reward-xp')));
      expect(xpField.controller!.text, '50');
      expect(find.byKey(const Key('trait-name')), findsOneWidget);
      expect(find.byKey(const Key('poster-character-picker')), findsNothing);
      expect(find.byKey(const Key('quest-target-picker')), findsNothing);
    });

    testWidgets('submitting writes the edit without touching status or assignment',
        (tester) async {
      final db = await _seed();
      final ref = await db.collection('quests').add({
        'title': 'Posprzątaj garaż',
        'posterUid': 'u1',
        'posterEmail': 'ala@example.com',
        'posterName': 'Elwenna',
        'status': 'open',
        'reward': {'current_xp': 50},
      });
      final quest = Quest(
        id: ref.id,
        title: 'Posprzątaj garaż',
        posterUid: 'u1',
        posterEmail: 'ala@example.com',
        posterName: 'Elwenna',
        status: QuestStatus.open,
        reward: const ChangeSet(currentXp: 50),
      );

      await pumpEdit(tester, db, quest);

      await tester.enterText(
          find.byKey(const Key('quest-title')), 'Posprzątaj garaż (gruntownie)');
      await tester.enterText(find.byKey(const Key('quest-reward-xp')), '80');
      await tester.pump();
      final button =
          tester.widget<ElevatedButton>(find.byKey(const Key('submit-quest')));
      expect(button.onPressed, isNotNull);
      await tester.tap(find.byKey(const Key('submit-quest')));
      await tester.pumpAndSettle();

      final data = (await db.collection('quests').doc(ref.id).get()).data()!;
      expect(data['title'], 'Posprzątaj garaż (gruntownie)');
      expect(data['reward'], {'current_xp': 80});
      expect(data['status'], 'open');
      expect(data['posterUid'], 'u1');
    });
  });
}
