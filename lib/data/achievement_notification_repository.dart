import 'package:shared_preferences/shared_preferences.dart';

/// On-device, per-uid baselines for badge announcements, same shape as
/// QuestNotificationRepository: a `null` load means "no baseline yet", so
/// the caller seeds silently instead of announcing badges that already
/// existed. Two sets: tray notifications sent, and "Nowa odznaka" dialogs
/// actually dismissed -- a badge leaves the dialog queue only when its
/// dialog closes, so a dialog is never lost to the app being killed first.
class AchievementNotificationRepository {
  AchievementNotificationRepository(this._prefs);

  final SharedPreferences _prefs;

  String _notifiedKey(String uid) => 'notified_achievements_$uid';
  String _celebratedKey(String uid) => 'celebrated_achievements_$uid';

  Set<String>? loadNotifiedIds(String uid) =>
      _prefs.getStringList(_notifiedKey(uid))?.toSet();
  Future<void> saveNotifiedIds(String uid, Set<String> ids) =>
      _prefs.setStringList(_notifiedKey(uid), ids.toList());

  Set<String>? loadCelebratedIds(String uid) =>
      _prefs.getStringList(_celebratedKey(uid))?.toSet();
  Future<void> saveCelebratedIds(String uid, Set<String> ids) =>
      _prefs.setStringList(_celebratedKey(uid), ids.toList());
}
