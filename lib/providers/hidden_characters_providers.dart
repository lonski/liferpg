import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hidden_characters_repository.dart';
import '../data/shared_preferences_provider.dart';
import 'auth_providers.dart';

final hiddenCharactersRepositoryProvider =
    Provider<HiddenCharactersRepository>(
  (ref) => HiddenCharactersRepository(ref.watch(sharedPreferencesProvider)),
);

/// The signed-in admin's own on-device hide list, scoped to their uid so
/// switching accounts on the same device never leaks one admin's hidden set
/// into another's. See `HiddenCharactersRepository` for why this is
/// local-only rather than Firestore-backed.
class HiddenCharacterIds extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    // `.value` rather than `.future`: unlike a StreamProvider deciding what
    // to yield once, this Notifier simply rebuilds when appUserProvider
    // settles, so a transient null during sign-in resolves itself.
    final uid = ref.watch(appUserProvider).value?.uid;
    if (uid == null) return const <String>{};
    return ref.watch(hiddenCharactersRepositoryProvider).load(uid);
  }

  void hide(String characterId) => _mutate((ids) => ids..add(characterId));

  void unhide(String characterId) =>
      _mutate((ids) => ids..remove(characterId));

  void _mutate(Set<String> Function(Set<String> ids) update) {
    final uid = ref.read(appUserProvider).value?.uid;
    if (uid == null) return;
    final updated = update({...state});
    state = updated;
    // Not awaited -- callers are plain VoidCallbacks (a button's onPressed),
    // and shared_preferences' in-memory cache is already updated
    // synchronously by the time this returns, so state and a same-session
    // reload agree regardless of the disk write's outcome. Still logged
    // rather than dropped, so a real failure isn't invisible.
    ref
        .read(hiddenCharactersRepositoryProvider)
        .save(uid, updated)
        .catchError((Object error) =>
            debugPrint('Failed to persist hidden characters: $error'));
  }
}

final hiddenCharacterIdsProvider =
    NotifierProvider<HiddenCharacterIds, Set<String>>(HiddenCharacterIds.new);
