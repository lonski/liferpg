// Shared set-up for the illustrated-theme render tests.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/data/update_repository.dart';
import 'package:liferpg/providers/clock_provider.dart';
import 'package:liferpg/providers/update_providers.dart';
import 'package:liferpg/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/achievements_test_support.dart';

Future<FakeFirebaseFirestore> themeWorld() => seedWorld(achievements: [
      achievementMap(id: 'a1', title: 'I miejsce', tier: 'gold', place: 1),
      achievementMap(id: 'a2', title: 'Gwiazda', tier: 'ruby', emblem: 'star', place: null),
    ]);

/// Pumps [home] on a tall phone, signed in as Zosia, under [theme].
Future<void> pumpThemed(WidgetTester tester, Widget home, RpgTheme theme) async {
  tester.view.physicalSize = const Size(412, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(await themeWorld()),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'zosia', email: 'zosia@example.com'),
      )),
      clockProvider.overrideWithValue(() => testNow),
      sharedPreferencesProvider.overrideWithValue(prefs),
      updateRepositoryProvider.overrideWith((ref) async =>
          UpdateRepository(MockClient((_) async => http.Response('{}', 200)), '99.0.0')),
    ],
    child: MaterialApp(theme: buildAppTheme(theme), home: home),
  ));
  await tester.pumpAndSettle();
}
