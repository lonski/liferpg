import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/requests/change_request_form.dart';
import 'package:liferpg/features/requests/change_requests_screen.dart';
import 'package:liferpg/theme/app_theme.dart';

late String characterId;
late String requestId;

Future<FakeFirebaseFirestore> seed({bool admin = true}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('a1').set({
    'uid': 'a1',
    'name': 'Admin',
    'email': 'admin@example.com',
    'admin': admin,
    'readOnlyOthers': false,
  });
  final character = await db.collection('characters').add({
    'name': 'Grommash',
    'email': 'ala@example.com',
    'level': 3,
    'current_xp': 40,
    'next_level_xp': 100,
    'gold': 100,
    'favour': 0,
    'traits': <dynamic>[],
  });
  characterId = character.id;
  final request = await db.collection('change_requests').add({
    'characterId': characterId,
    'characterName': 'Grommash',
    'requesterUid': 'u1',
    'requesterEmail': 'ala@example.com',
    'status': 'pending',
    'reason': 'Posprzątałem garaż',
    'changes': {'current_xp': 50},
  });
  requestId = request.id;
  return db;
}

Future<void> pumpScreen(WidgetTester tester, FakeFirebaseFirestore db) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'a1', email: 'admin@example.com'),
      )),
    ],
    child: const MaterialApp(home: ChangeRequestsScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists a pending request with its reason', (tester) async {
    await pumpScreen(tester, await seed());
    expect(find.byKey(Key('request-$requestId')), findsOneWidget);
    expect(find.text('Grommash'), findsOneWidget);
    expect(find.text('Posprzątałem garaż'), findsOneWidget);
  });

  testWidgets('renders the request timestamp when createdAt is known',
      (tester) async {
    final db = await seed();
    await db.collection('change_requests').doc(requestId).update({
      'createdAt': Timestamp.fromDate(DateTime(2026, 3, 4, 9, 5)),
    });
    await pumpScreen(tester, db);

    expect(find.text('2026-03-04 09:05'), findsOneWidget);
  });

  testWidgets('renders without throwing when createdAt is null',
      (tester) async {
    // seed() never sets createdAt, so the fake document's field is simply
    // absent -- the same "server timestamp still pending" state the real
    // repository models as a null createdAt.
    await pumpScreen(tester, await seed());

    expect(find.byKey(Key('request-$requestId')), findsOneWidget);
  });

  testWidgets('accepting applies the change and clears the queue',
      (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('accept-$requestId')));
    await tester.pumpAndSettle();

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 90);
    final request =
        (await db.collection('change_requests').doc(requestId).get()).data()!;
    expect(request['status'], 'accepted');
    expect(request['decidedBy'], 'a1');
    expect(find.byKey(Key('request-$requestId')), findsNothing);
  });

  testWidgets('rejecting marks the request without touching the character',
      (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('reject-$requestId')));
    await tester.pumpAndSettle();

    final request =
        (await db.collection('change_requests').doc(requestId).get()).data()!;
    expect(request['status'], 'rejected');
    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 40);
  });

  testWidgets('editing before accepting applies the edited value',
      (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(Key('edit-$requestId')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('field-current_xp')), '20');
    await tester.pump();
    await tester.tap(find.byKey(const Key('confirm-edit')));
    await tester.pumpAndSettle();

    final character =
        (await db.collection('characters').doc(characterId).get()).data()!;
    expect(character['current_xp'], 60);
    final request =
        (await db.collection('change_requests').doc(requestId).get()).data()!;
    expect(request['changes'], {'current_xp': 50});
    expect(request['appliedChanges'], {'current_xp': 20});
  });

  // buildAppTheme() is a LIGHT ThemeData (bodyColor inkDark, onSurface
  // inkDark), so a Material surface painted bgDark inherits near-black text.
  // ChangeRequestForm is a parchment-card widget — crimson labels, dark ink —
  // and on a dark dialog every one of its colours was invisible. Pin the
  // surface it renders on.
  testWidgets('the edit dialog renders the form on a parchment surface',
      (tester) async {
    await pumpScreen(tester, await seed());

    await tester.tap(find.byKey(Key('edit-$requestId')));
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, parchment);
    expect(find.byType(ChangeRequestForm), findsOneWidget);
  });

  // The filter row is built from Containers rather than Material's FilterChip,
  // whose light-scheme surface read as a foreign widget on the dark scaffold.
  // These pin the behaviour that styling has to keep working.
  testWidgets('switching the filter shows requests of that status',
      (tester) async {
    final db = await seed();
    final decided = await db.collection('change_requests').add({
      'characterId': characterId,
      'characterName': 'Thrall',
      'requesterUid': 'u2',
      'requesterEmail': 'bob@example.com',
      'status': 'rejected',
      'changes': {'gold': 5},
    });
    await pumpScreen(tester, db);

    // The pending tab is the default: the rejected request is not on it.
    expect(find.byKey(Key('request-$requestId')), findsOneWidget);
    expect(find.byKey(Key('request-${decided.id}')), findsNothing);

    await tester.tap(find.byKey(const Key('filter-rejected')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('request-${decided.id}')), findsOneWidget);
    expect(find.byKey(Key('request-$requestId')), findsNothing);
  });

  testWidgets('a decided request offers no accept/reject/edit actions',
      (tester) async {
    final db = await seed();
    final decided = await db.collection('change_requests').add({
      'characterId': characterId,
      'characterName': 'Thrall',
      'requesterUid': 'u2',
      'requesterEmail': 'bob@example.com',
      'status': 'rejected',
      'changes': {'gold': 5},
    });
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(const Key('filter-rejected')));
    await tester.pumpAndSettle();

    expect(find.byKey(Key('request-${decided.id}')), findsOneWidget);
    expect(find.byKey(Key('accept-${decided.id}')), findsNothing);
    expect(find.byKey(Key('reject-${decided.id}')), findsNothing);
    expect(find.byKey(Key('edit-${decided.id}')), findsNothing);
  });
}
