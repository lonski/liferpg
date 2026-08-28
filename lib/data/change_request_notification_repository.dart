import 'package:shared_preferences/shared_preferences.dart';

/// On-device bookkeeping for `change_request_notifications.dart`'s diffing:
/// which pending requests an admin has already been notified about, and the
/// last-known status of each of the signed-in user's own requests. Local-only
/// and per-uid, same reasoning as `HiddenCharactersRepository` -- this is
/// this device's memory of what it already told this user, not shared state.
///
/// A load method returns `null` when nothing was ever saved for that uid, so
/// callers can tell "no baseline yet" (seed silently) apart from "baseline is
/// an empty set/map" (nothing new).
class ChangeRequestNotificationRepository {
  ChangeRequestNotificationRepository(this._prefs);

  final SharedPreferences _prefs;

  String _pendingKey(String uid) => 'notified_pending_requests_$uid';
  String _statusKey(String uid) => 'known_request_statuses_$uid';

  Set<String>? loadNotifiedPendingIds(String uid) =>
      _prefs.getStringList(_pendingKey(uid))?.toSet();

  Future<void> saveNotifiedPendingIds(String uid, Set<String> ids) =>
      _prefs.setStringList(_pendingKey(uid), ids.toList());

  Map<String, String>? loadKnownStatuses(String uid) {
    final raw = _prefs.getStringList(_statusKey(uid));
    if (raw == null) return null;
    return {
      for (final entry in raw)
        if (entry.indexOf(':') case final i when i >= 0)
          entry.substring(0, i): entry.substring(i + 1),
    };
  }

  Future<void> saveKnownStatuses(String uid, Map<String, String> statuses) =>
      _prefs.setStringList(
        _statusKey(uid),
        [for (final e in statuses.entries) '${e.key}:${e.value}'],
      );
}
