import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// The OAuth 2.0 *web* client id from the Firebase console
/// (Authentication → Sign-in method → Google → Web SDK configuration).
/// Google Sign-In needs it to mint an ID token that Firebase will accept.
const String kGoogleServerClientId =
    String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signInWithGoogle() async {
    await GoogleSignIn.instance.initialize(serverClientId: kGoogleServerClientId);
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-id-token',
        message: 'Google nie zwrócił tokenu tożsamości.',
      );
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    if (user != null) await ensureUserDocument(user);
  }

  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  /// Creates users/{uid} on first login. Both privilege flags are written as
  /// false; the Firestore rules reject any other value on create, and only an
  /// admin may change them afterwards.
  Future<void> ensureUserDocument(User user) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'uid': user.uid,
      'name': user.displayName ?? '',
      'email': user.email ?? '',
      'authProvider': 'google',
      'admin': false,
      'readOnlyOthers': false,
    });
  }
}
