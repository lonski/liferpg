import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` lives in flutter_riverpod's misc.dart, not its main barrel.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/character/character_card.dart';
import 'package:liferpg/data/character_repository.dart';
import 'package:liferpg/features/home/home_screen.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/providers/character_providers.dart';

Future<FakeFirebaseFirestore> seed({
  bool admin = false,
  bool readOnlyOthers = false,
}) async {
  final db = FakeFirebaseFirestore();
  await db.collection('users').doc('u1').set({
    'uid': 'u1',
    'name': 'Ala',
    'email': 'ala@example.com',
    'admin': admin,
    'readOnlyOthers': readOnlyOthers,
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

Future<void> pumpHome(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  List<Override> extraOverrides = const [],
}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
      ...extraOverrides,
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

  // T1: the edit affordance is gated on canEdit (admin only), NOT on
  // canSeeAllCharacters -- swapping the two would hand readOnlyOthers users a
  // pencil on every card while leaving every other test green.
  testWidgets('a readOnlyOthers user sees characters but no edit affordance',
      (tester) async {
    await pumpHome(tester, await seed(readOnlyOthers: true));
    expect(find.byType(CharacterCard), findsOneWidget);
    expect(find.byKey(const Key('edit-character')), findsNothing);
  });

  testWidgets('an admin gets the edit affordance', (tester) async {
    await pumpHome(tester, await seed(admin: true));
    expect(find.byType(CharacterCard), findsOneWidget);
    expect(find.byKey(const Key('edit-character')), findsOneWidget);
  });

  // T2: the offline indicator. Overriding charactersProvider with a fixed
  // feed is the only way to control snapshot metadata, which the repository
  // reads straight off Firestore.
  Override feedOverride({required bool offline}) =>
      charactersProvider.overrideWith(
        (ref) => Stream.value(CharacterFeed(
          characters: const [
            Character(
              id: 'c1',
              name: 'Grommash',
              email: 'ala@example.com',
              level: 3,
              currentXp: 40,
              nextLevelXp: 100,
              favour: 0,
              traits: [],
            ),
          ],
          isFromCache: offline,
          hasPendingWrites: false,
        )),
      );

  testWidgets('shows the offline indicator when the feed is offline',
      (tester) async {
    await pumpHome(tester, await seed(),
        extraOverrides: [feedOverride(offline: true)]);
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
  });

  testWidgets('hides the offline indicator when the feed is live',
      (tester) async {
    await pumpHome(tester, await seed(),
        extraOverrides: [feedOverride(offline: false)]);
    expect(find.byIcon(Icons.cloud_off), findsNothing);
  });
}
