import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/seen_achievements_repository.dart';
import '../data/shared_preferences_provider.dart';
import 'auth_providers.dart';
import 'character_providers.dart';

final seenAchievementsRepositoryProvider = Provider<SeenAchievementsRepository>(
  (ref) => SeenAchievementsRepository(ref.watch(sharedPreferencesProvider)),
);

/// Badge ids the signed-in viewer has opened; a visible badge not in it
/// wears the NOWA chip. `null` until a baseline exists -- and while null
/// nothing reads as new, so a badge never flashes NOWA just because this
/// device hasn't caught up yet.
class SeenAchievements extends Notifier<Set<String>?> {
  @override
  Set<String>? build() {
    final user = ref.watch(appUserProvider).value;
    if (user == null) return null;
    final repo = ref.watch(seenAchievementsRepositoryProvider);
    final stored = repo.load(user.uid);
    if (stored != null) return stored;
    // First run for this uid on this device: every badge that already exists
    // counts as seen, so an update doesn't light up the whole history. Only
    // from a settled server snapshot -- a cache-only or reloading feed may be
    // missing badges, or belong to the previous user.
    final characters = ref.watch(charactersProvider);
    final feed = characters.value;
    if (characters.isLoading || feed == null || feed.isFromCache) return null;
    final all = {
      for (final c in feed.characters)
        for (final a in c.achievements) a.id,
    };
    repo.save(user.uid, all);
    return all;
  }

  /// No-op before the baseline exists: the badge will be in the feed the
  /// baseline seeds from, so it ends up seen anyway.
  void markSeen(String achievementId) {
    final current = state;
    final user = ref.read(appUserProvider).value;
    if (current == null || user == null || current.contains(achievementId)) {
      return;
    }
    final next = {...current, achievementId};
    ref.read(seenAchievementsRepositoryProvider).save(user.uid, next);
    state = next;
  }
}

final seenAchievementsProvider =
    NotifierProvider<SeenAchievements, Set<String>?>(SeenAchievements.new);
