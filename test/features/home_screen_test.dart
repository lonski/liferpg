import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` lives in flutter_riverpod's misc.dart, not its main barrel.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/data/update_repository.dart';
import 'package:liferpg/features/character/character_card.dart';
import 'package:liferpg/data/character_repository.dart';
import 'package:liferpg/features/home/home_screen.dart';
import 'package:liferpg/features/requests/new_change_request_screen.dart';
import 'package:liferpg/features/update/update_dialog.dart';
import 'package:liferpg/models/character.dart';
import 'package:liferpg/models/update_info.dart';
import 'package:liferpg/providers/character_providers.dart';
import 'package:liferpg/providers/hidden_characters_providers.dart';
import 'package:liferpg/providers/update_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A deterministic stand-in for the real update check so tests don't
// implicitly rely on PackageInfo.fromPlatform() throwing in flutter_test
// (which is what currently keeps updateCheckProvider from firing a real
// HTTPS request in every test that doesn't override it directly).
Override _noUpdateRepositoryOverride() => updateRepositoryProvider.overrideWith(
      (ref) async => UpdateRepository(
        MockClient((_) async => http.Response('{}', 200)),
        '99.0.0',
      ),
    );

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
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
      sharedPreferencesProvider.overrideWithValue(
        await SharedPreferences.getInstance(),
      ),
      _noUpdateRepositoryOverride(),
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

  // Hiding is now triggered from EditCharacterScreen (see
  // edit_character_screen_test.dart), reachable only through the card's
  // edit icon -- itself already gated on canEdit (admin), covered by 'a
  // readOnlyOthers user sees characters but no edit affordance' and 'an
  // admin gets the edit affordance' above. These tests exercise the
  // roster-filtering side (hiddenCharacterIdsProvider -> HomeScreen) via
  // the provider directly, the same seam EditCharacterScreen's hide action
  // writes through.
  testWidgets('a character hidden via the provider disappears for an admin',
      (tester) async {
    final db = await seed(admin: true);
    final characterId =
        (await db.collection('characters').get()).docs.single.id;
    await pumpHome(tester, db);
    expect(find.byType(CharacterCard), findsOneWidget);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    container.read(hiddenCharacterIdsProvider.notifier).hide(characterId);
    await tester.pumpAndSettle();

    expect(find.byType(CharacterCard), findsNothing);
  });

  // Regression: hiding only ever filters an admin's own view, so a stale
  // hidden id left in prefs from before this account was demoted (this app
  // has a whole screen for flipping that flag) must never leave a
  // non-admin permanently unable to see -- and possibly unable to explain
  // why they can't see -- their own roster.
  testWidgets(
      'a stale hidden id does not affect a user who is no longer admin',
      (tester) async {
    final db = await seed();
    final characterId =
        (await db.collection('characters').get()).docs.single.id;
    SharedPreferences.setMockInitialValues({
      'hidden_characters_u1': [characterId],
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
          signedIn: true,
          mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
        )),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        _noUpdateRepositoryOverride(),
      ],
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(CharacterCard), findsOneWidget);
  });

  testWidgets('hiding one character does not affect a different character',
      (tester) async {
    final db = await seed(admin: true);
    final characterId =
        (await db.collection('characters').get()).docs.single.id;
    await pumpHome(tester, db);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    container.read(hiddenCharacterIdsProvider.notifier).hide(characterId);
    await tester.pumpAndSettle();

    // A second character owned by somebody else stays visible: hiding is
    // per-character, not a blanket "hide everything" toggle.
    await db.collection('characters').add({
      'name': 'Cudza postać',
      'email': 'ktos.inny@example.com',
      'level': 1,
      'current_xp': 0,
      'next_level_xp': 100,
      'favour': 0,
      'traits': <dynamic>[],
    });
    await tester.pumpAndSettle();

    expect(find.byType(CharacterCard), findsOneWidget);
    expect(find.text('Cudza postać'), findsOneWidget);
    expect(find.text('Grommash'), findsNothing);
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

  testWidgets('offers the change-request FAB when the user has a character',
      (tester) async {
    await pumpHome(tester, await seed());
    expect(find.byKey(const Key('new-change-request')), findsOneWidget);
  });

  testWidgets('hides the change-request FAB when the user owns no character',
      (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1',
      'name': 'Ala',
      'email': 'ala@example.com',
      'admin': false,
      'readOnlyOthers': false,
    });
    await pumpHome(tester, db);
    expect(find.byKey(const Key('new-change-request')), findsNothing);
  });

  testWidgets('shows the change-request queue action only for admins',
      (tester) async {
    await pumpHome(tester, await seed());
    expect(find.byKey(const Key('open-change-requests')), findsNothing);

    await pumpHome(tester, await seed(admin: true));
    expect(find.byKey(const Key('open-change-requests')), findsOneWidget);
  });

  testWidgets('the FAB opens the request screen', (tester) async {
    await pumpHome(tester, await seed());
    await tester.tap(find.byKey(const Key('new-change-request')));
    await tester.pumpAndSettle();
    expect(find.byType(NewChangeRequestScreen), findsOneWidget);
  });

  // Regression coverage for `ownsACharacter`: an admin sees the whole roster,
  // but the FAB is about posting a request against a character of their own,
  // so a non-empty roster must not be mistaken for ownership.
  testWidgets(
      'hides the FAB for an admin who owns no character even though the '
      'roster is non-empty', (tester) async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1',
      'name': 'Ala',
      'email': 'ala@example.com',
      'admin': true,
      'readOnlyOthers': false,
    });
    await db.collection('characters').add({
      'name': 'Cudza postać',
      'email': 'ktos.inny@example.com',
      'level': 1,
      'current_xp': 0,
      'next_level_xp': 100,
      'favour': 0,
      'traits': <dynamic>[],
    });
    await pumpHome(tester, db);
    expect(find.byType(CharacterCard), findsOneWidget);
    expect(find.byKey(const Key('new-change-request')), findsNothing);
  });

  testWidgets(
      'shows the FAB for an admin who owns a character alongside somebody '
      "else's", (tester) async {
    final db = await seed(admin: true);
    await db.collection('characters').add({
      'name': 'Cudza postać',
      'email': 'ktos.inny@example.com',
      'level': 1,
      'current_xp': 0,
      'next_level_xp': 100,
      'favour': 0,
      'traits': <dynamic>[],
    });
    await pumpHome(tester, db);
    expect(find.byType(CharacterCard), findsNWidgets(2));
    expect(find.byKey(const Key('new-change-request')), findsOneWidget);
  });

  testWidgets(
      'shows a pending-count badge for the admin action when requests are '
      'pending', (tester) async {
    final db = await seed(admin: true);
    await db.collection('change_requests').add({
      'characterId': 'c1',
      'characterName': 'Grommash',
      'requesterUid': 'u1',
      'requesterEmail': 'ala@example.com',
      'status': 'pending',
      'changes': {'current_xp': 10},
      'createdAt': Timestamp.now(),
    });
    await pumpHome(tester, db);

    final badge =
        tester.widget<Badge>(find.byKey(const Key('pending-requests-badge')));
    expect(badge.isLabelVisible, isTrue);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets(
      'hides the pending-count badge for the admin action when nothing is '
      'pending', (tester) async {
    await pumpHome(tester, await seed(admin: true));

    final badge =
        tester.widget<Badge>(find.byKey(const Key('pending-requests-badge')));
    expect(badge.isLabelVisible, isFalse);
  });

  testWidgets('shows the update dialog when a newer version is found',
      (tester) async {
    await pumpHome(
      tester,
      await seed(),
      extraOverrides: [
        updateCheckProvider.overrideWith(
          (ref) async => const UpdateInfo(
            version: '9.9.9',
            releaseNotes: '',
            apkUrl: 'https://example.com/app.apk',
          ),
        ),
      ],
    );

    expect(find.byType(UpdateDialog), findsOneWidget);
  });

  testWidgets('shows no update dialog when already up to date',
      (tester) async {
    await pumpHome(
      tester,
      await seed(),
      extraOverrides: [
        updateCheckProvider.overrideWith((ref) async => null),
      ],
    );

    expect(find.byType(UpdateDialog), findsNothing);
  });
}
