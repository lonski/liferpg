import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/login/login_screen.dart';

void main() {
  testWidgets('shows the chronicle branding and the Polish sign-in copy',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ));

    expect(find.text('LifeRPG'), findsOneWidget);
    expect(find.text('Kronika Bohaterów'), findsOneWidget);
    expect(find.text('Zaloguj przez Google'), findsOneWidget);
    expect(find.text('Wejdź do Kroniki'), findsOneWidget);
    expect(find.text('„Twoja legenda czeka...”'), findsOneWidget);
  });
}
