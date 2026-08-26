import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/character_repository.dart';
import '../data/firebase_providers.dart';
import 'auth_providers.dart';

final characterRepositoryProvider = Provider<CharacterRepository>(
  (ref) => CharacterRepository(ref.watch(firestoreProvider)),
);

final charactersProvider = StreamProvider<CharacterFeed>((ref) async* {
  // Await the resolved user rather than peeking at appUserProvider's
  // transient `.value`: reading `.value` while appUserProvider is still
  // loading is indistinguishable from "signed out" and would race an empty
  // feed out before the real user (and their characters) ever resolves.
  final user = await ref.watch(appUserProvider.future);
  if (user == null) {
    yield const CharacterFeed(
      characters: [],
      isFromCache: false,
      hasPendingWrites: false,
    );
    return;
  }
  yield* ref.watch(characterRepositoryProvider).watchCharacters(user);
});

/// Distinct trait names already in use across the loaded roster. The edit
/// screen offers these as autocomplete suggestions, mirroring the web app's
/// existingTraitNames memo.
final traitNamesProvider = Provider<List<String>>((ref) {
  final feed = ref.watch(charactersProvider).value;
  if (feed == null) return const [];
  final names = <String>{
    for (final c in feed.characters)
      for (final t in c.traits) t.name,
  };
  return names.toList()..sort();
});
