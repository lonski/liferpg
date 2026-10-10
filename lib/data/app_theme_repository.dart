import 'package:shared_preferences/shared_preferences.dart';

import '../theme/rpg_theme.dart';

/// The look chosen on this device. Deliberately device-wide and local-only
/// (never per account, never Firestore): it has to apply on the login
/// screen, before anyone is signed in, and it is a personal preference
/// rather than anything about a character.
class AppThemeRepository {
  AppThemeRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'app_theme';

  AppThemeId load() => AppThemeId.fromName(_prefs.getString(_key));

  Future<void> save(AppThemeId id) => _prefs.setString(_key, id.name);
}
