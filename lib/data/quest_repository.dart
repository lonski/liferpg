import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/quest.dart';

class QuestRepository {
  QuestRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _quests => _db.collection('quests');

  /// `createdAt` is written server-side rather than from the device clock,
  /// matching `ChangeRequestRepository.create`.
  Future<void> create(Quest quest) => _quests.add({
        ...quest.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

  Stream<List<Quest>> watchOpen() =>
      _watch(_quests.where('status', isEqualTo: QuestStatus.open.wire));

  /// The "Moje: przypisane do mnie" section and the assigned-to-me
  /// notification both watch this across *every* status the caller cares
  /// about (they filter client-side), since a taker may own more than one
  /// character. `whereIn` with an empty list throws in Firestore, so an
  /// empty roster short-circuits to an empty stream rather than querying.
  Stream<List<Quest>> watchAssignedTo(List<String> characterIds) {
    if (characterIds.isEmpty) return Stream.value(const []);
    return _watch(_quests.where('assignedToCharacterId', whereIn: characterIds));
  }

  /// Every status for quests this uid posted -- the "Moje: wystawione przeze
  /// mnie" section filters to `open` client-side, and the "quest taken"
  /// notification filters to `assigned` client-side.
  Stream<List<Quest>> watchPostedBy(String uid) =>
      _watch(_quests.where('posterUid', isEqualTo: uid));

  /// The global outcome feed -- every terminal status, visible to everyone.
  Stream<List<Quest>> watchLog() => _watch(_quests.where('status', whereIn: [
        QuestStatus.completed.wire,
        QuestStatus.failed.wire,
        QuestStatus.cancelled.wire,
      ]));

  Stream<List<Quest>> _watch(Query<Map<String, dynamic>> query) =>
      query.snapshots().map((snap) {
        final quests = snap.docs
            .map((d) {
              try {
                return Quest.fromMap(d.id, d.data());
              } catch (e) {
                debugPrint('Skipping malformed quest ${d.id}: $e');
                return null;
              }
            })
            .whereType<Quest>()
            .toList();
        // Sorted client-side rather than with orderBy, same reasoning as
        // ChangeRequestRepository: a quest whose server timestamp has not
        // landed yet must not be dropped from the list.
        quests.sort((a, b) {
          final at = a.createdAt;
          final bt = b.createdAt;
          if (at == null && bt == null) return 0;
          if (at == null) return -1;
          if (bt == null) return 1;
          return bt.compareTo(at);
        });
        return quests;
      });
}
