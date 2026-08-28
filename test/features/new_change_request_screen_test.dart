import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/requests/new_change_request_screen.dart';
import 'package:liferpg/theme/app_theme.dart';

Future<FakeFirebaseFirestore> seed({int characters = 1}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': false,
    'readOnlyOthers': false,
  });
  for (var i = 0; i < characters; i++) {
    await db.collection('characters').add({
      'name': 'Bohater $i',
      'email': 'ala@example.com',
      'level': 1,
      'current_xp': 0,
      'next_level_xp': 100,
      'favour': 0,
      'traits': <dynamic>[],
    });
  }
  return db;
}

Future<void> pumpScreen(WidgetTester tester, FakeFirebaseFirestore db) async {
  // The default 800x600 test surface is too short to fit the request form
  // card plus the own-requests list: with even a single request row present,
  // the row (and anything tappable inside it, e.g. the cancel button added
  // in Task 5) renders below the fold and tester.tap() cannot reach it. A
  // taller surface -- restored after the test -- keeps the whole scroll
  // view's content hit-testable without changing any actual widget layout.
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
    ],
    child: const MaterialApp(home: NewChangeRequestScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('hides the character picker when there is only one character',
      (tester) async {
    await pumpScreen(tester, await seed());
    expect(find.byKey(const Key('character-picker')), findsNothing);
  });

  testWidgets('shows the character picker when there are two characters',
      (tester) async {
    await pumpScreen(tester, await seed(characters: 2));
    expect(find.byKey(const Key('character-picker')), findsOneWidget);
  });

  testWidgets(
      'submit stays disabled until both a change and a reason are entered',
      (tester) async {
    await pumpScreen(tester, await seed());

    ElevatedButton button() => tester
        .widget<ElevatedButton>(find.byKey(const Key('submit-request')));
    expect(button().onPressed, isNull);

    await tester.enterText(find.byKey(const Key('field-current_xp')), '50');
    await tester.pump();
    expect(button().onPressed, isNull, reason: 'reason is still required');

    await tester.enterText(
        find.byKey(const Key('field-reason')), 'Posprzątałem garaż');
    await tester.pump();

    expect(button().onPressed, isNotNull);
  });

  testWidgets(
      'tapping the disabled submit button explains what is missing',
      (tester) async {
    await pumpScreen(tester, await seed());

    await tester.tap(find.byKey(const Key('submit-request')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Wprowadź przynajmniej jedną zmianę'), findsOneWidget);

    // Dismiss, then satisfy that requirement and check the tooltip moves on
    // to the next missing one.
    await tester.tap(find.byKey(const Key('submit-request')));
    await tester.enterText(find.byKey(const Key('field-current_xp')), '50');
    await tester.pump();

    await tester.tap(find.byKey(const Key('submit-request')));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Podaj powód'), findsOneWidget);
  });

  testWidgets('submitting writes a pending request', (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.enterText(find.byKey(const Key('field-current_xp')), '50');
    await tester.enterText(
        find.byKey(const Key('field-reason')), 'Posprzątałem garaż');
    await tester.pump();
    await tester.tap(find.byKey(const Key('submit-request')));
    await tester.pumpAndSettle();

    final docs = await db.collection('change_requests').get();
    expect(docs.docs, hasLength(1));
    final data = docs.docs.single.data();
    expect(data['status'], 'pending');
    expect(data['requesterUid'], 'u1');
    expect(data['characterName'], 'Bohater 0');
    expect(data['reason'], 'Posprzątałem garaż');
    expect(data['changes'], {'current_xp': 50});
  });

  testWidgets('a pending request can be cancelled with confirmation',
      (tester) async {
    final db = await seed();
    final request = await db.collection('change_requests').add({
      'characterId': 'whatever',
      'characterName': 'Bohater 0',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'changes': {'current_xp': 50},
    });
    await pumpScreen(tester, db);

    expect(find.byKey(Key('cancel-request-${request.id}')), findsOneWidget);
    await tester.tap(find.byKey(Key('cancel-request-${request.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('confirm-cancel-${request.id}')));
    await tester.pumpAndSettle();

    final data =
        (await db.collection('change_requests').doc(request.id).get())
            .data()!;
    expect(data['status'], 'cancelled');
    expect(find.text('Anulowana'), findsOneWidget);
    expect(find.text('Prośba anulowana'), findsOneWidget);
  });

  testWidgets('backing out of the cancel confirmation changes nothing',
      (tester) async {
    final db = await seed();
    final request = await db.collection('change_requests').add({
      'characterId': 'whatever',
      'characterName': 'Bohater 0',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'changes': {'current_xp': 50},
    });
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('cancel-request-${request.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NIE'));
    await tester.pumpAndSettle();

    final data =
        (await db.collection('change_requests').doc(request.id).get())
            .data()!;
    expect(data['status'], 'pending');
  });

  // Regression: parchmentFaint blends to ~3.95:1 against bgDark at this
  // fontSize (9) -- below WCAG AA's 4.5:1 floor for text this small.
  // parchmentMuted (already used for the character name on the same row)
  // clears 6:1.
  testWidgets('the status label uses a colour that passes contrast',
      (tester) async {
    final db = await seed();
    final request = await db.collection('change_requests').add({
      'characterId': 'whatever',
      'characterName': 'Bohater 0',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'changes': {'current_xp': 50},
    });
    await pumpScreen(tester, db);

    final statusText = tester.widget<Text>(find.descendant(
      of: find.byKey(Key('my-request-${request.id}')),
      matching: find.text('Oczekuje'),
    ));
    expect(statusText.style?.color, parchmentMuted);
  });

  testWidgets('tapping a request shows what was asked for', (tester) async {
    final db = await seed();
    final request = await db.collection('change_requests').add({
      'characterId': 'whatever',
      'characterName': 'Bohater 0',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'reason': 'Posprzątałem garaż',
      'createdAt': Timestamp.fromDate(DateTime(2026, 3, 4, 9, 5)),
      'changes': {
        'current_xp': 50,
        'gold': -10,
        'traits': [
          {'name': 'Siła', 'value': '12'},
        ],
      },
    });
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('my-request-${request.id}')));
    await tester.pumpAndSettle();

    expect(find.text('XP: +50'), findsOneWidget);
    expect(find.text('Złoto: -10'), findsOneWidget);
    expect(find.text('Siła: 12'), findsOneWidget);
    expect(find.text('Posprzątałem garaż'), findsOneWidget);
    expect(find.textContaining('2026-03-04 09:05'), findsOneWidget);

    await tester.tap(find.text('ZAMKNIJ'));
    await tester.pumpAndSettle();

    expect(find.text('XP: +50'), findsNothing);
  });

  testWidgets('a decided request\'s details show what was applied',
      (tester) async {
    final db = await seed();
    final request = await db.collection('change_requests').add({
      'characterId': 'whatever',
      'characterName': 'Bohater 0',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'accepted',
      'changes': {'current_xp': 50},
      'appliedChanges': {'current_xp': 20},
      'decidedBy': 'admin1',
      'decidedAt': Timestamp.fromDate(DateTime(2026, 3, 5, 10, 0)),
    });
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('my-request-${request.id}')));
    await tester.pumpAndSettle();

    // The original ask is still shown alongside what actually landed.
    expect(find.text('XP: +50'), findsOneWidget);
    expect(find.text('XP: +20'), findsOneWidget);
    expect(find.textContaining('2026-03-05 10:00'), findsOneWidget);
  });

  testWidgets('tapping the cancel icon does not open the details dialog',
      (tester) async {
    final db = await seed();
    final request = await db.collection('change_requests').add({
      'characterId': 'whatever',
      'characterName': 'Bohater 0',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'changes': {'current_xp': 50},
    });
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('cancel-request-${request.id}')));
    await tester.pumpAndSettle();

    expect(find.text('ANULOWAĆ PROŚBĘ?'), findsOneWidget);
    expect(find.text('XP: +50'), findsNothing);
  });
}
