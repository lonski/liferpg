import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/change_request_notification_repository.dart';
import '../data/change_request_notification_service.dart';
import '../data/change_request_notifications.dart';
import '../data/shared_preferences_provider.dart';
import '../models/change_request.dart';
import 'auth_providers.dart';
import 'change_request_providers.dart';

/// Overridden in `main()` with a real system-tray-backed implementation.
final changeRequestNotificationServiceProvider =
    Provider<ChangeRequestNotificationService>((ref) {
  throw UnimplementedError(
    'changeRequestNotificationServiceProvider must be overridden in main() '
    'with a real ChangeRequestNotificationService.',
  );
});

final changeRequestNotificationRepositoryProvider =
    Provider<ChangeRequestNotificationRepository>(
  (ref) =>
      ChangeRequestNotificationRepository(ref.watch(sharedPreferencesProvider)),
);

/// Watched once (from `AuthGate`, while a user is signed in) to keep it alive
/// for the session. Reacts to the same streams the admin queue and "my
/// requests" screen already watch, so it introduces no new Firestore
/// listeners -- just a system-tray notification for events those screens
/// would otherwise only show if the user happened to have them open.
final changeRequestNotificationsProvider = Provider<void>((ref) {
  // Fires once per app process: this provider is watched (not read) from
  // AuthGate for as long as a user is signed in, and -- not being
  // .autoDispose -- stays alive and un-rebuilt across a sign-out/sign-in.
  ref.read(changeRequestNotificationServiceProvider).requestPermission();

  ref.listen(pendingChangeRequestsProvider, (previous, next) {
    final pending = next.value;
    final user = ref.read(appUserProvider).value;
    if (pending == null || user == null) return;

    final repo = ref.read(changeRequestNotificationRepositoryProvider);
    final diff = diffPendingRequests(
      pending: pending,
      previouslyNotified: repo.loadNotifiedPendingIds(user.uid),
    );
    repo.saveNotifiedPendingIds(user.uid, diff.notifiedIds);

    final service = ref.read(changeRequestNotificationServiceProvider);
    for (final request in diff.toNotify) {
      service.show(
        id: 'pending_${request.id}',
        title: 'Nowa prośba o zmianę',
        body: request.characterName,
        payload: 'admin_queue',
      );
    }
  });

  ref.listen(myChangeRequestsProvider, (previous, next) {
    final requests = next.value;
    final user = ref.read(appUserProvider).value;
    if (requests == null || user == null) return;

    final repo = ref.read(changeRequestNotificationRepositoryProvider);
    final diff = diffOwnRequests(
      requests: requests,
      previouslyKnown: repo.loadKnownStatuses(user.uid),
    );
    repo.saveKnownStatuses(user.uid, diff.statuses);

    final service = ref.read(changeRequestNotificationServiceProvider);
    for (final request in diff.toNotify) {
      final verb = request.status == ChangeRequestStatus.accepted
          ? 'zaakceptowana'
          : 'odrzucona';
      service.show(
        id: 'decision_${request.id}',
        title: 'Twoja prośba została $verb',
        body: request.characterName,
        payload: 'my_requests',
      );
    }
  });
});
