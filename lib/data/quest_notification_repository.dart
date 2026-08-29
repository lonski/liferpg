import 'package:shared_preferences/shared_preferences.dart';

/// On-device, per-uid baselines for the three quest notification events,
/// same shape and same reasoning as ChangeRequestNotificationRepository: a
/// `null` load means "no baseline yet for this uid", so the caller seeds
/// silently instead of flooding notifications for quests that already
/// existed before this device ever checked.
class QuestNotificationRepository {
  QuestNotificationRepository(this._prefs);

  final SharedPreferences _prefs;

  String _openKey(String uid) => 'notified_open_quests_$uid';
  String _assignedKey(String uid) => 'notified_assigned_quests_$uid';
  String _takenKey(String uid) => 'notified_taken_quests_$uid';

  Set<String>? loadNotifiedOpenIds(String uid) =>
      _prefs.getStringList(_openKey(uid))?.toSet();
  Future<void> saveNotifiedOpenIds(String uid, Set<String> ids) =>
      _prefs.setStringList(_openKey(uid), ids.toList());

  Set<String>? loadNotifiedAssignedIds(String uid) =>
      _prefs.getStringList(_assignedKey(uid))?.toSet();
  Future<void> saveNotifiedAssignedIds(String uid, Set<String> ids) =>
      _prefs.setStringList(_assignedKey(uid), ids.toList());

  Set<String>? loadNotifiedTakenIds(String uid) =>
      _prefs.getStringList(_takenKey(uid))?.toSet();
  Future<void> saveNotifiedTakenIds(String uid, Set<String> ids) =>
      _prefs.setStringList(_takenKey(uid), ids.toList());
}
