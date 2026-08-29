import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/features/login/login_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    expect(find.text('KRONIKA BOHATERÓW'), findsOneWidget);
    expect(find.text('ZALOGUJ PRZEZ GOOGLE'), findsOneWidget);
    expect(find.text('Wejdź do Kroniki'), findsOneWidget);
    expect(find.text('„Twoja legenda czeka...”'), findsOneWidget);
  });

  testWidgets('shows the running build version so it can be verified',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'LifeRPG',
      packageName: 'com.example.liferpg',
      version: '1.2.2',
      buildNumber: '6',
      buildSignature: '',
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
        firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('app-version')), findsOneWidget);
    expect(find.text('v1.2.2+6'), findsOneWidget);
  });
}
