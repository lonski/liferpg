import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_theme_repository.dart';
import '../data/shared_preferences_provider.dart';
import '../theme/rpg_theme.dart';

final appThemeRepositoryProvider = Provider<AppThemeRepository>(
  (ref) => AppThemeRepository(ref.watch(sharedPreferencesProvider)),
);

/// The selected look; see [AppThemeRepository] for why it is per device.
class AppThemeSelection extends Notifier<AppThemeId> {
  @override
  AppThemeId build() => ref.watch(appThemeRepositoryProvider).load();

  void select(AppThemeId id) {
    if (id == state) return;
    state = id;
    // Not awaited -- callers are plain taps, and shared_preferences' in-memory
    // cache is already updated synchronously, so a same-session reload
    // agrees with `state` regardless of the disk write's outcome.
    ref
        .read(appThemeRepositoryProvider)
        .save(id)
        .catchError((Object error) => debugPrint('Failed to persist theme: $error'));
  }
}

final appThemeProvider =
    NotifierProvider<AppThemeSelection, AppThemeId>(AppThemeSelection.new);
