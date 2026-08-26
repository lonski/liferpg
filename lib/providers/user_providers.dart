import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/firebase_providers.dart';
import '../data/user_repository.dart';
import '../models/app_user.dart';
import 'auth_providers.dart';

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(firestoreProvider)),
);

/// Non-admins get an empty list rather than a permission error: the Firestore
/// rules would reject the collection read anyway.
final usersProvider = StreamProvider<List<AppUser>>((ref) async* {
  // Await the resolved user rather than peeking at appUserProvider's transient
  // `.value`: while appUserProvider is still loading, `.value` is null and is
  // indistinguishable from "signed out", which would race an empty list out
  // before the real user resolves. (Established in Task 6; same shape.)
  final user = await ref.watch(appUserProvider.future);
  if (user == null || !user.admin) {
    yield const <AppUser>[];
    return;
  }
  yield* ref.watch(userRepositoryProvider).watchUsers();
});
