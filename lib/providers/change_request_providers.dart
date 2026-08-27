import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/change_request_repository.dart';
import '../data/firebase_providers.dart';
import '../models/change_request.dart';
import 'auth_providers.dart';

final changeRequestRepositoryProvider = Provider<ChangeRequestRepository>(
  (ref) => ChangeRequestRepository(ref.watch(firestoreProvider)),
);

/// The admin queue. Empty for everyone else — the security rule would reject
/// the unconstrained query anyway, so issuing it would surface as a
/// PERMISSION_DENIED error rather than an empty list.
final pendingChangeRequestsProvider =
    StreamProvider<List<ChangeRequest>>((ref) async* {
  // Awaiting the resolved user rather than peeking at `.value`: reading
  // `.value` while appUserProvider is still loading is indistinguishable from
  // "signed out", which would race an empty queue out before the real user
  // ever resolves. Same reasoning as charactersProvider.
  final user = await ref.watch(appUserProvider.future);
  if (user == null || !user.admin) {
    yield const <ChangeRequest>[];
    return;
  }
  yield* ref.watch(changeRequestRepositoryProvider).watchPending();
});

/// The admin queue filtered by status. `pendingChangeRequestsProvider` is the
/// pending case, kept separate because the home screen's badge watches it.
final changeRequestsByStatusProvider = StreamProvider.family<
    List<ChangeRequest>, ChangeRequestStatus>((ref, status) async* {
  final user = await ref.watch(appUserProvider.future);
  if (user == null || !user.admin) {
    yield const <ChangeRequest>[];
    return;
  }
  yield* ref.watch(changeRequestRepositoryProvider).watchByStatus(status);
});

/// The signed-in user's own requests, with their outcomes.
final myChangeRequestsProvider =
    StreamProvider<List<ChangeRequest>>((ref) async* {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) {
    yield const <ChangeRequest>[];
    return;
  }
  yield* ref
      .watch(changeRequestRepositoryProvider)
      .watchForRequester(user.uid);
});
