import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/firebase_providers.dart';
import 'package:liferpg/models/app_user.dart';
import 'package:liferpg/providers/auth_providers.dart';

void main() {
  test('appUserProvider is null when nobody is signed in', () async {
    final container = ProviderContainer(overrides: [
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
    ]);
    addTearDown(container.dispose);
    // Riverpod 3 pauses a StreamProvider's subscription when it has no
    // listener, so a bare `read(...future)` would hang forever; keep it
    // unpaused with a no-op listener first.
    container.listen(appUserProvider, (_, _) {});

    final user = await container.read(appUserProvider.future);
    expect(user, isNull);
  });

  test('appUserProvider streams the signed-in user document', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('users').doc('u1').set({
      'uid': 'u1',
      'name': 'Ala',
      'email': 'ala@example.com',
      'admin': true,
      'readOnlyOthers': false,
    });
    final container = ProviderContainer(overrides: [
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'u1', email: 'ala@example.com'),
      )),
      firestoreProvider.overrideWithValue(db),
    ]);
    addTearDown(container.dispose);
    container.listen(appUserProvider, (_, _) {});

    final user = await container.read(appUserProvider.future);
    expect(user, isA<AppUser>());
    expect(user!.admin, isTrue);
    expect(user.email, 'ala@example.com');
  });
}
