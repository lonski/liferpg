import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/achievement_notification_repository.dart';
import '../data/character_repository.dart';
import '../data/quest_notifications.dart';
import '../data/shared_preferences_provider.dart';
import '../models/achievement.dart';
import '../models/achievement_formatting.dart';
import '../models/app_user.dart';
import '../models/character.dart';
import 'auth_providers.dart';
import 'change_request_notification_providers.dart';
import 'character_providers.dart';

typedef OwnedAchievement = ({Character character, Achievement achievement});

final achievementNotificationRepositoryProvider =
    Provider<AchievementNotificationRepository>(
  (ref) =>
      AchievementNotificationRepository(ref.watch(sharedPreferencesProvider)),
);

/// Badges on the signed-in user's own characters (by email, like
/// HomeScreen's `ownsACharacter`) -- an admin awarding someone else's
/// character is never told about it; awarding their own, they are.
List<OwnedAchievement> ownAchievements(CharacterFeed feed, AppUser user) {
  final email = user.email.toLowerCase();
  return [
    for (final c in feed.characters)
      if (c.email.toLowerCase() == email)
        for (final a in c.achievements) (character: c, achievement: a),
  ];
}

/// Watched once from AuthGate, alongside the quest / change-request ones.
/// Rides the roster stream the home screen already holds -- no new listener.
final achievementNotificationsProvider = Provider<void>((ref) {
  ref.listen(charactersProvider, (previous, next) {
    // While the roster reloads (right after a sign-in, say) `.value` is still
    // the previous feed -- possibly the empty signed-out one -- not a
    // snapshot of this user's characters.
    if (next.isLoading) return;
    final feed = next.value;
    final user = ref.read(appUserProvider).value;
    if (feed == null || user == null) return;
    final repo = ref.read(achievementNotificationRepositoryProvider);
    final previously = repo.loadNotifiedIds(user.uid);
    // With no baseline, a cache-only snapshot may be empty or stale: seeding
    // from it would announce every existing badge once the server answers.
    if (previously == null && feed.isFromCache) return;
    final diff = diffNewIds(
      items: ownAchievements(feed, user),
      idOf: (OwnedAchievement o) => o.achievement.id,
      previouslyNotified: previously,
    );
    // A cache snapshot can lack badges the server still has; don't forget
    // them on its account.
    repo.saveNotifiedIds(
      user.uid,
      feed.isFromCache ? {...?previously, ...diff.notifiedIds} : diff.notifiedIds,
    );
    final service = ref.read(changeRequestNotificationServiceProvider);
    for (final o in diff.toNotify) {
      final parts = rewardParts(o.achievement.reward);
      service.show(
        id: 'achievement_${o.achievement.id}',
        title: 'Nowa odznaka: ${o.achievement.title}',
        body: parts.isEmpty
            ? o.character.name
            : '${o.character.name} · ${parts.join(', ')}',
        payload: 'achievement',
      );
    }
  });
});

/// Own badges whose "Nowa odznaka" dialog hasn't been dismissed yet,
/// oldest first. Same baseline rules as the notifications above.
class CelebrationQueue extends Notifier<List<OwnedAchievement>> {
  @override
  List<OwnedAchievement> build() {
    final characters = ref.watch(charactersProvider);
    final user = ref.watch(appUserProvider).value;
    // Same reloading guard as the notifications listener: a stale feed
    // must never seed or prune this user's baseline.
    if (characters.isLoading) return const [];
    final feed = characters.value;
    if (feed == null || user == null) return const [];
    final repo = ref.watch(achievementNotificationRepositoryProvider);
    final own = ownAchievements(feed, user);
    final currentIds = {for (final o in own) o.achievement.id};
    final celebrated = repo.loadCelebratedIds(user.uid);
    if (celebrated == null) {
      if (!feed.isFromCache) repo.saveCelebratedIds(user.uid, currentIds);
      return const [];
    }
    // Forget revoked badges, but only on a server snapshot -- a partial
    // cache must not make an old badge look new later.
    if (!feed.isFromCache) {
      final kept = celebrated.intersection(currentIds);
      if (kept.length != celebrated.length) {
        repo.saveCelebratedIds(user.uid, kept);
      }
    }
    return own.where((o) => !celebrated.contains(o.achievement.id)).toList()
      ..sort((a, b) => a.achievement.awardedAt.compareTo(b.achievement.awardedAt));
  }

  void dismiss(String achievementId) {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    final repo = ref.read(achievementNotificationRepositoryProvider);
    repo.saveCelebratedIds(
      user.uid,
      {...?repo.loadCelebratedIds(user.uid), achievementId},
    );
    state = [
      for (final o in state)
        if (o.achievement.id != achievementId) o,
    ];
  }
}

final celebrationQueueProvider =
    NotifierProvider<CelebrationQueue, List<OwnedAchievement>>(
  CelebrationQueue.new,
);
