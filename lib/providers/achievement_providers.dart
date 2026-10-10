import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/achievement_repository.dart';
import '../data/firebase_providers.dart';
import '../models/character.dart';
import 'character_providers.dart';
import 'clock_provider.dart';

final achievementRepositoryProvider = Provider<AchievementRepository>(
  (ref) => AchievementRepository(
    ref.watch(firestoreProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// One character off the live roster feed: null while the feed loads, or
/// once the character is gone (screens tell the two apart by also watching
/// charactersProvider).
final characterByIdProvider = Provider.family<Character?, String>((ref, id) {
  final feed = ref.watch(charactersProvider).value;
  return feed?.characters.where((c) => c.id == id).firstOrNull;
});
