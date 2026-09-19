import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/change_request_notification_service.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/features/quests/new_quest_screen.dart';
import 'package:liferpg/features/quests/quest_card.dart';
import 'package:liferpg/features/quests/quests_screen.dart';
import 'package:liferpg/models/quest.dart' show dailyQuestStamp;
import 'package:liferpg/providers/change_request_notification_providers.dart';
import 'package:liferpg/providers/quest_notification_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationService implements ChangeRequestNotificationService {
  final shown = <String>[];

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> show({
    required String id,
    required String title,
    required String body,
    required String payload,
  }) async {
    shown.add(id);
  }
}

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
    expect(find.byTooltip('Podejmij'), findsOneWidget);
    expect(find.byIcon(Icons.share), findsOneWidget);
  });

  testWidgets('tapping Podejmij with exactly one owned character takes it immediately '
      'after confirming', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.tap(find.byTooltip('Podejmij'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TAK, PODEJMIJ'));
    await tester.pumpAndSettle();

    final quest = (await db.collection('quests').get()).docs.single.data();
    expect(quest['status'], 'assigned');
    expect(quest['assignedToCharacterId'], 'c1');
    expect(find.text('Posprzątaj garaż'), findsNothing);
  });

  testWidgets('Moje shows an assigned-to-me quest (Ukończ/Porzuć) and a posted-by-me one '
      '(Edytuj/Wycofaj)', (tester) async {
    final db = await _seedMine();
    await _pump(tester, db);

    await tester.tap(find.byKey(const Key('quests-tab-mine')));
    await tester.pumpAndSettle();

    expect(find.text('Ugotuj obiad'), findsOneWidget);
    expect(find.byTooltip('Ukończ'), findsOneWidget);
    expect(find.byTooltip('Porzuć'), findsOneWidget);
    expect(find.text('Zrób pranie'), findsOneWidget);
    expect(find.byTooltip('Edytuj'), findsOneWidget);
    expect(find.byTooltip('Wycofaj'), findsOneWidget);
  });

  testWidgets('tapping Edytuj on a posted-by-me quest opens it pre-filled for editing',
      (tester) async {
    final db = await _seedMine();
    await _pump(tester, db);
    await tester.tap(find.byKey(const Key('quests-tab-mine')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edytuj'));
    await tester.pumpAndSettle();

    expect(find.byType(NewQuestScreen), findsOneWidget);
    final titleField = tester.widget<TextField>(find.byKey(const Key('quest-title')));
    expect(titleField.controller!.text, 'Zrób pranie');
    expect(find.byKey(const Key('quest-target-picker')), findsNothing);
  });

  testWidgets('tapping Ukończ and confirming raises a linked change request and clears '
      'the action', (tester) async {
    final db = await _seedMine();
    await _pump(tester, db);
    await tester.tap(find.byKey(const Key('quests-tab-mine')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Ukończ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TAK, UKOŃCZ'));
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

  testWidgets(
      'taking a board quest does not self-notify "assigned to you"',
      (tester) async {
    final db = await _seed();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = _FakeNotificationService();
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
      sharedPreferencesProvider.overrideWithValue(prefs),
      changeRequestNotificationServiceProvider.overrideWithValue(service),
    ]);
    addTearDown(container.dispose);
    container.listen(questNotificationsProvider, (_, _) {});

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: QuestsScreen()),
    ));
    await tester.pumpAndSettle();

    final questId = (await db.collection('quests').get()).docs.single.id;

    await tester.tap(find.byTooltip('Podejmij'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TAK, PODEJMIJ'));
    await tester.pumpAndSettle();

    expect(service.shown, isNot(contains('quest_assigned_$questId')));
  });

  testWidgets('tapping the + AppBar action opens NewQuestScreen', (tester) async {
    final db = await _seed();
    await _pump(tester, db);

    await tester.tap(find.byKey(const Key('open-new-quest')));
    await tester.pumpAndSettle();

    expect(find.byType(NewQuestScreen), findsOneWidget);
  });

  group('daily quests (CODZIENNE tab)', () {
    Future<FakeFirebaseFirestore> seedDaily({String? lastCompletedDate}) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('u1').set({
        'uid': 'u1', 'name': 'Ala', 'email': 'ala@example.com', 'admin': false, 'readOnlyOthers': false,
      });
      await db.collection('characters').doc('c1').set({
        'name': 'Grommash', 'email': 'ala@example.com', 'current_xp': 0, 'next_level_xp': 100, 'favour': 0, 'traits': [],
      });
      await db.collection('quests').add({
        'title': 'Wyprowadzić psa',
        'posterUid': 'u2',
        'posterEmail': 'bob@example.com',
        'posterName': 'Admin',
        'assignedToCharacterId': 'c1',
        'assignedToCharacterName': 'Grommash',
        'assignedToEmail': 'ala@example.com',
        'status': 'assigned',
        'reward': {'current_xp': 10},
        'isDaily': true,
        'lastCompletedDate': ?lastCompletedDate,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return db;
    }

    testWidgets('a due-today daily quest shows an Ukończ action and no Porzuć', (tester) async {
      final db = await seedDaily();
      await _pump(tester, db);
      await tester.tap(find.byKey(const Key('quests-tab-daily')));
      await tester.pumpAndSettle();

      expect(find.text('Wyprowadzić psa'), findsOneWidget);
      expect(find.byTooltip('Ukończ'), findsOneWidget);
      expect(find.byTooltip('Porzuć'), findsNothing);
      expect(find.textContaining('DO ZROBIENIA DZIŚ'), findsOneWidget);
    });

    testWidgets('a done-today daily quest hides the Ukończ action', (tester) async {
      final db = await seedDaily(lastCompletedDate: dailyQuestStamp());
      await _pump(tester, db);
      await tester.tap(find.byKey(const Key('quests-tab-daily')));
      await tester.pumpAndSettle();

      expect(find.text('Wyprowadzić psa'), findsOneWidget);
      expect(find.byTooltip('Ukończ'), findsNothing);
      expect(find.textContaining('ZROBIONE DZIŚ'), findsOneWidget);
    });

    testWidgets('a daily quest does not appear on the MOJE tab', (tester) async {
      final db = await seedDaily();
      await _pump(tester, db);
      await tester.tap(find.byKey(const Key('quests-tab-mine')));
      await tester.pumpAndSettle();

      expect(find.text('Wyprowadzić psa'), findsNothing);
      expect(find.text('Brak własnych zadań'), findsOneWidget);
    });

    testWidgets('tapping Ukończ and confirming raises a linked change request', (tester) async {
      final db = await seedDaily();
      await _pump(tester, db);
      await tester.tap(find.byKey(const Key('quests-tab-daily')));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Ukończ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TAK, UKOŃCZ'));
      await tester.pumpAndSettle();

      final quest = (await db.collection('quests').get()).docs.single.data();
      expect(quest['status'], 'pending_review');
      expect(quest['lastCompletedDate'], dailyQuestStamp());
    });

    Future<FakeFirebaseFirestore> seedDailyAsAdmin() async {
      final db = await seedDaily();
      await db.collection('users').doc('u1').update({'admin': true});
      return db;
    }

    testWidgets('an admin sees a ZARZĄDZANIE section with Edytuj and Zakończ', (tester) async {
      final db = await seedDailyAsAdmin();
      await _pump(tester, db);
      await tester.tap(find.byKey(const Key('quests-tab-daily')));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Edytuj'), findsOneWidget);
      expect(find.byTooltip('Zakończ'), findsOneWidget);
    });

    testWidgets('the ZARZĄDZANIE row is a compact list item, not the player-facing QuestCard',
        (tester) async {
      final db = await seedDailyAsAdmin();
      await _pump(tester, db);
      await tester.tap(find.byKey(const Key('quests-tab-daily')));
      await tester.pumpAndSettle();

      // The same quest is both admin's own (rendered as a QuestCard in
      // "TWOJE ZADANIA CODZIENNE") and admin-managed -- exactly one
      // QuestCard should exist, not two, because the ZARZĄDZANIE row uses a
      // distinct, flatter widget rather than reusing QuestCard.
      expect(find.byType(QuestCard), findsOneWidget);
      expect(find.text('CZEKA'), findsOneWidget);
    });

    testWidgets('tapping Zakończ and confirming deactivates the daily quest', (tester) async {
      final db = await seedDailyAsAdmin();
      await _pump(tester, db);
      await tester.tap(find.byKey(const Key('quests-tab-daily')));
      await tester.pumpAndSettle();

      // The quest is admin's own AND admin-managed, so it renders twice
      // (once per section) -- tall enough to push Zakończ below the test
      // viewport, hence the explicit scroll before tapping it.
      await tester.ensureVisible(find.byTooltip('Zakończ'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zakończ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TAK, ZAKOŃCZ'));
      await tester.pumpAndSettle();

      final quest = (await db.collection('quests').get()).docs.single.data();
      expect(quest['status'], 'cancelled');
    });
  });
}
