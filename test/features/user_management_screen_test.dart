import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/users/user_management_screen.dart';

Future<FakeFirebaseFirestore> seed() async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': true,
    'readOnlyOthers': false,
  });
  await db.collection('users').doc('u2').set({
    'uid': 'u2',
    'name': 'Bob',
    'email': 'bob@example.com',
    'admin': false,
    'readOnlyOthers': false,
  });
  return db;
}

Future<void> pumpScreen(WidgetTester tester, FakeFirebaseFirestore db) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
    ],
    child: const MaterialApp(home: UserManagementScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every user with their email', (tester) async {
    await pumpScreen(tester, await seed());
    expect(find.text('Ala'), findsOneWidget);
    expect(find.text('bob@example.com'), findsOneWidget);
  });

  testWidgets('toggling the switch writes readOnlyOthers', (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(const Key('readonly-u2')));
    await tester.pumpAndSettle();

    final snap = await db.collection('users').doc('u2').get();
    expect(snap.data()!['readOnlyOthers'], isTrue);
  });

  testWidgets('the switch is disabled for admin rows', (tester) async {
    await pumpScreen(tester, await seed());
    final adminSwitch =
        tester.widget<Switch>(find.byKey(const Key('readonly-u1')));
    expect(adminSwitch.onChanged, isNull);
  });

  testWidgets('toggling the admin switch writes admin', (tester) async {
    final db = await seed();
    await pumpScreen(tester, db);

    await tester.tap(find.byKey(const Key('admin-u2')));
    await tester.pumpAndSettle();

    final snap = await db.collection('users').doc('u2').get();
    expect(snap.data()!['admin'], isTrue);
  });

  testWidgets('shows an empty state when there are no users', (tester) async {
    final db = FakeFirebaseFirestore();
    await pumpScreen(tester, db);
    expect(find.text('Brak użytkowników'), findsOneWidget);
  });

  testWidgets('falls back to a placeholder when a user has no name',
      (tester) async {
    final db = await seed();
    await db.collection('users').doc('u2').update({'name': ''});
    await pumpScreen(tester, db);
    expect(find.text('Bez nazwy'), findsOneWidget);
  });

  // I8: the two labelled switches used to sit in ListTile.trailing, roughly
  // 290dp of fixed-width content on a 360dp phone. The suite's default
  // 800x600 surface hid it; at a real phone size the RenderFlex overflow
  // throws and fails this test.
  testWidgets('a user row fits a phone-sized screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await pumpScreen(tester, await seed());

    expect(find.byKey(const Key('admin-u2')), findsOneWidget);
    expect(find.byKey(const Key('readonly-u2')), findsOneWidget);
    expect(find.text('bob@example.com'), findsOneWidget);
  });
}
