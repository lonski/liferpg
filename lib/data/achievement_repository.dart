import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/achievement.dart';
import '../models/character_deltas.dart';
import '../models/electronics_days.dart';

class AchievementCharacterGone implements Exception {
  const AchievementCharacterGone();

  @override
  String toString() => 'Postać już nie istnieje';
}

class AchievementGone implements Exception {
  const AchievementGone();

  @override
  String toString() => 'Ta odznaka już nie istnieje';
}

/// Award, edit and revoke all read-modify-write `characters/{id}` in one
/// transaction, on the admin's device (there are no Cloud Functions; the
/// character write rule is already admin-only). The badge list and the
/// reward land in the same update, so they can never disagree.
class AchievementRepository {
  AchievementRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  DocumentReference<Map<String, dynamic>> _ref(String characterId) =>
      _db.collection('characters').doc(characterId);

  /// Generated before the transaction, once per award form, so a retried
  /// transaction or a double tap carries the same id and is a no-op.
  String newId() => _db.collection('characters').doc().id;

  Future<void> award(String characterId, Achievement achievement) async {
    final ref = _ref(characterId);
    final today = dayOf(_clock());
    await _db.runTransaction((tx) async {
      final data = (await tx.get(ref)).data();
      if (data == null) throw const AchievementCharacterGone();
      final list = _entries(data);
      if (list.any((e) => e is Map && e['id'] == achievement.id)) return;
      tx.update(ref, {
        ..._rewardUpdates(data, achievement.reward, today),
        'achievements': [...list, achievement.toMap()],
      });
    });
  }

  /// Presentation only -- the reward and award stamp are carried over.
  Future<void> edit(
    String characterId,
    String achievementId,
    AchievementDetails details,
  ) async {
    final ref = _ref(characterId);
    await _db.runTransaction((tx) async {
      final data = (await tx.get(ref)).data();
      if (data == null) throw const AchievementCharacterGone();
      final list = _entries(data);
      final index = list.indexWhere((e) => e is Map && e['id'] == achievementId);
      final existing = index < 0 ? null : Achievement.tryParse(list[index]);
      if (existing == null) throw const AchievementGone();
      list[index] = existing.withDetails(details).toMap();
      tx.update(ref, {'achievements': list});
    });
  }

  /// Removes the badge and takes its reward back (XP / gold / trait may go
  /// negative; electronics days stop at 0). Already gone: a no-op, so a
  /// double tap cannot reverse twice.
  Future<void> revoke(String characterId, String achievementId) async {
    final ref = _ref(characterId);
    final today = dayOf(_clock());
    await _db.runTransaction((tx) async {
      final data = (await tx.get(ref)).data();
      if (data == null) throw const AchievementCharacterGone();
      final list = _entries(data);
      final index = list.indexWhere((e) => e is Map && e['id'] == achievementId);
      if (index < 0) return;
      final reward =
          Achievement.tryParse(list[index])?.reward ?? const AchievementReward();
      list.removeAt(index);
      tx.update(ref, {
        ..._rewardUpdates(data, reward.negated(), today),
        'achievements': list,
      });
    });
  }

  List<Object?> _entries(Map<String, dynamic> data) {
    final raw = data['achievements'];
    return raw is List ? List<Object?>.from(raw) : <Object?>[];
  }

  Map<String, dynamic> _rewardUpdates(
    Map<String, dynamic> character,
    AchievementReward reward,
    int today,
  ) =>
      {
        ...applyCharacterDeltas(character, reward.toChangeSet()),
        if (reward.electronicsDays != null)
          'electronics': ElectronicsDays.fromMap(character['electronics'])
              .addDays(reward.electronicsDays!, today)
              .toMap(),
      };
}
