import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/requests/new_change_request_screen.dart';

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
}
