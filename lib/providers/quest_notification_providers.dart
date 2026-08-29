import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quest_notification_repository.dart';
import '../data/quest_notifications.dart';
import '../data/shared_preferences_provider.dart';
import '../models/quest.dart';
import 'auth_providers.dart';
import 'change_request_notification_providers.dart';
import 'quest_providers.dart';

final questNotificationRepositoryProvider = Provider<QuestNotificationRepository>(
  (ref) => QuestNotificationRepository(ref.watch(sharedPreferencesProvider)),
);

/// Watched once (from AuthGate, alongside changeRequestNotificationsProvider)
/// to keep it alive for the session. Reuses
/// changeRequestNotificationServiceProvider -- it is already a thin,
/// message-agnostic "post a system-tray notification" seam, so quests don't
/// need a service of their own.
final questNotificationsProvider = Provider<void>((ref) {
  ref.listen(openQuestsProvider, (previous, next) {
    final open = next.value;
    final user = ref.read(appUserProvider).value;
    if (open == null || user == null) return;
    // Never notify a poster about their own posting.
    final fromOthers = open.where((q) => q.posterUid != user.uid).toList();

    final repo = ref.read(questNotificationRepositoryProvider);
    final diff = diffNewIds(
      items: fromOthers,
      idOf: (Quest q) => q.id,
      previouslyNotified: repo.loadNotifiedOpenIds(user.uid),
    );
    repo.saveNotifiedOpenIds(user.uid, diff.notifiedIds);

    final service = ref.read(changeRequestNotificationServiceProvider);
    for (final quest in diff.toNotify) {
      service.show(
        id: 'quest_open_${quest.id}',
        title: 'Nowe zadanie na tablicy',
        body: quest.title,
        payload: 'quest_board',
      );
    }
  });

  ref.listen(myAssignedQuestsProvider, (previous, next) {
    final assigned =
        next.value?.where((q) => q.status == QuestStatus.assigned).toList();
    final user = ref.read(appUserProvider).value;
    if (assigned == null || user == null) return;

    final repo = ref.read(questNotificationRepositoryProvider);
    final diff = diffNewIds(
      items: assigned,
      idOf: (Quest q) => q.id,
      previouslyNotified: repo.loadNotifiedAssignedIds(user.uid),
    );
    repo.saveNotifiedAssignedIds(user.uid, diff.notifiedIds);

    final service = ref.read(changeRequestNotificationServiceProvider);
    for (final quest in diff.toNotify) {
      service.show(
        id: 'quest_assigned_${quest.id}',
        title: 'Przydzielono Ci zadanie',
        body: quest.title,
        payload: 'my_quests',
      );
    }
  });

  ref.listen(myPostedQuestsProvider, (previous, next) {
    final taken =
        next.value?.where((q) => q.status == QuestStatus.assigned).toList();
    final user = ref.read(appUserProvider).value;
    if (taken == null || user == null) return;

    final repo = ref.read(questNotificationRepositoryProvider);
    final diff = diffNewIds(
      items: taken,
      idOf: (Quest q) => q.id,
      previouslyNotified: repo.loadNotifiedTakenIds(user.uid),
    );
    repo.saveNotifiedTakenIds(user.uid, diff.notifiedIds);

    final service = ref.read(changeRequestNotificationServiceProvider);
    for (final quest in diff.toNotify) {
      service.show(
        id: 'quest_taken_${quest.id}',
        title: 'Ktoś podjął Twoje zadanie',
        body: quest.title,
        payload: 'my_quests',
      );
    }
  });
});
