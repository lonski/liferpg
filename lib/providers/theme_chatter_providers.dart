import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/shared_preferences_provider.dart';
import '../data/theme_sound_player.dart';
import '../models/quest.dart';
import '../models/theme_tips.dart';
import 'quest_providers.dart';

final themeSoundPlayerProvider =
    Provider<ThemeSoundPlayer>((ref) => AudioplayersThemeSoundPlayer());

/// Whether a theme's mascots make sounds. Per device, like the theme itself
/// (SharedPreferences `theme_sounds`); on unless switched off.
class ThemeSoundsEnabled extends Notifier<bool> {
  static const _key = 'theme_sounds';

  @override
  bool build() => ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;

  void set(bool enabled) {
    if (enabled == state) return;
    state = enabled;
    ref
        .read(sharedPreferencesProvider)
        .setBool(_key, enabled)
        .catchError((Object error) {
      debugPrint('Failed to persist theme sounds: $error');
      return false;
    });
  }
}

final themeSoundsEnabledProvider =
    NotifierProvider<ThemeSoundsEnabled, bool>(ThemeSoundsEnabled.new);

/// What the mascots may tip the player off about: live rewards on the board
/// and today's chores first, then the evergreen hints. Signed out, the quest
/// streams are empty, so only the evergreen hints remain.
final themeTipsProvider = Provider<List<String>>((ref) {
  final open = ref.watch(openQuestsProvider).value ?? const <Quest>[];
  final assigned = ref.watch(myAssignedQuestsProvider).value ?? const <Quest>[];
  return [...questTips(open: open, assigned: assigned), ...kGeneralTips];
});
