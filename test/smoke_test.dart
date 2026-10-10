import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/features/login/login_screen.dart';
import 'package:liferpg/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('signed-out users land on the login screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
      child: const LifeRpgApp(),
    ));
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
