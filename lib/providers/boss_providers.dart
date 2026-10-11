import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/boss_repository.dart';
import '../data/firebase_providers.dart';
import '../models/boss.dart';
import 'achievement_providers.dart';
import 'auth_providers.dart';

final bossRepositoryProvider = Provider<BossRepository>(
  (ref) => BossRepository(ref.watch(firestoreProvider)),
);

/// Live and beaten bosses; empty while signed out.
final liveBossesProvider = StreamProvider<List<Boss>>((ref) async* {
  final user = await ref.watch(appUserProvider.future);
  if (user == null) {
    yield const [];
    return;
  }
  yield* ref.watch(bossRepositoryProvider).watchLive();
});

/// The arenas under one character's card.
final bossesForCharacterProvider = Provider.family<List<Boss>, String>((
  ref,
  characterId,
) {
  final bosses = ref.watch(liveBossesProvider).value ?? const <Boss>[];
  final character = ref.watch(characterByIdProvider(characterId));
  if (character == null) return const [];
  return bossesFor(bosses, character);
});
