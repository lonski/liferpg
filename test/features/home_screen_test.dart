import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/character/character_card.dart';
import 'package:liferpg/features/home/home_screen.dart';

Future<FakeFirebaseFirestore> seed({bool admin = false}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': admin,
    'readOnlyOthers': false,
  });
  await db.collection('characters').add({
    'name': 'Grommash',
    'email': 'ala@example.com',
    'level': 3,
    'current_xp': 40,
    'next_level_xp': 100,
    'favour': 0,
    'traits': <dynamic>[],
  });
  return db;
}

Future<void> pumpHome(WidgetTester tester, FakeFirebaseFirestore db) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
    ],
    child: const MaterialApp(home: HomeScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists the characters the user may see', (tester) async {
    await pumpHome(tester, await seed());
    expect(find.byType(CharacterCard), findsOneWidget);
    expect(find.text('Grommash'), findsOneWidget);
  });

  testWidgets('shows the admin action only for admins', (tester) async {
    await pumpHome(tester, await seed());
    expect(find.byKey(const Key('open-user-management')), findsNothing);

    await pumpHome(tester, await seed(admin: true));
    expect(find.byKey(const Key('open-user-management')), findsOneWidget);
  });

  testWidgets('always offers logout', (tester) async {
    await pumpHome(tester, await seed());
    expect(find.byKey(const Key('logout')), findsOneWidget);
  });
}
