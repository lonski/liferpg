import 'package:shared_preferences/shared_preferences.dart';

/// Which badges a viewer has opened, per uid and on-device only (like hidden
/// characters): it drives the card's NOWA chip, and is never written to
/// Firestore. A `null` load means "no baseline yet".
class SeenAchievementsRepository {
  SeenAchievementsRepository(this._prefs);

  final SharedPreferences _prefs;

  String _key(String uid) => 'seen_achievements_$uid';

  Set<String>? load(String uid) => _prefs.getStringList(_key(uid))?.toSet();

  Future<void> save(String uid, Set<String> ids) =>
      _prefs.setStringList(_key(uid), ids.toList());
}
