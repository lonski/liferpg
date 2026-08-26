import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:liferpg/data/auth_repository.dart';

/// No plugin implementation registers itself under `flutter test` (that only
/// happens via generated plugin registration in a real app or an integration
/// test), so `GoogleSignIn.instance.signOut()` would otherwise hit the
/// platform interface's placeholder and throw UnimplementedError. This stub
/// stands in for the platform channel so `AuthRepository.signOut()` — which
/// legitimately calls through to Google Sign-In as well as FirebaseAuth — can
/// be exercised without a device.
class _FakeGoogleSignInPlatform extends GoogleSignInPlatform {
  @override
  Future<void> init(InitParameters params) async {}

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async =>
      null;

  @override
  bool supportsAuthenticate() => true;

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) {
    throw UnimplementedError();
  }

  @override
  bool authorizationRequiresUserInteraction() => false;

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async =>
      null;

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async =>
      null;

  @override
  Future<void> signOut(SignOutParams params) async {}

  @override
  Future<void> disconnect(DisconnectParams params) async {}
}

void main() {
  GoogleSignInPlatform.instance = _FakeGoogleSignInPlatform();

  test('ensureUserDocument creates a doc with both flags false', () async {
    final db = FakeFirebaseFirestore();
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'ala@example.com', displayName: 'Ala'),
    );
    final repo = AuthRepository(auth, db);

    await repo.ensureUserDocument(auth.currentUser!);

    final snap = await db.collection('users').doc('u1').get();
    expect(snap.exists, isTrue);
    expect(snap.data()!['email'], 'ala@example.com');
    expect(snap.data()!['name'], 'Ala');
    expect(snap.data()!['authProvider'], 'google');
    expect(snap.data()!['admin'], isFalse);
    expect(snap.data()!['readOnlyOthers'], isFalse);
  });

  test('ensureUserDocument never overwrites an existing doc', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1',
      'email': 'ala@example.com',
      'admin': true,
      'readOnlyOthers': false,
    });
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
    );

    await AuthRepository(auth, db).ensureUserDocument(auth.currentUser!);

    final snap = await db.collection('users').doc('u1').get();
    expect(snap.data()!['admin'], isTrue, reason: 'admin must survive re-login');
  });

  test('signOut clears the current user', () async {
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1'));
    await AuthRepository(auth, FakeFirebaseFirestore()).signOut();
    expect(auth.currentUser, isNull);
  });
}
