import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/change_request.dart' show ChangeRequestStatus;
import '../models/quest.dart';

/// Thrown when `take`/`withdraw` re-read the quest and it is no longer
/// `open` -- someone else took it, or it was withdrawn, since the caller's
/// copy was fetched. Mirrors `ChangeRequestNoLongerPending`.
class QuestNotOpen implements Exception {
  const QuestNotOpen();

  @override
  String toString() => 'To zadanie nie jest już dostępne';
}

/// Thrown when `abandon`/`markComplete` re-read the quest and it is no
/// longer `assigned` -- it was already abandoned, completed, or the caller
/// is stale.
class QuestNotAssignedToCaller implements Exception {
  const QuestNotAssignedToCaller();

  @override
  String toString() => 'To zadanie nie jest już przypisane';
}

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

  Future<void> take(
    Quest quest, {
    required String characterId,
    required String characterName,
    required String email,
  }) async {
    final ref = _quests.doc(quest.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || QuestStatus.parse(data['status']) != QuestStatus.open) {
        throw const QuestNotOpen();
      }
      tx.update(ref, {
        'status': QuestStatus.assigned.wire,
        'assignedToCharacterId': characterId,
        'assignedToCharacterName': characterName,
        'assignedToEmail': email,
      });
    });
  }

  Future<void> abandon(Quest quest) async {
    final ref = _quests.doc(quest.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || QuestStatus.parse(data['status']) != QuestStatus.assigned) {
        throw const QuestNotAssignedToCaller();
      }
      tx.update(ref, {
        'status': QuestStatus.open.wire,
        'assignedToCharacterId': FieldValue.delete(),
        'assignedToCharacterName': FieldValue.delete(),
        'assignedToEmail': FieldValue.delete(),
      });
    });
  }

  Future<void> withdraw(Quest quest) async {
    final ref = _quests.doc(quest.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || QuestStatus.parse(data['status']) != QuestStatus.open) {
        throw const QuestNotOpen();
      }
      tx.update(ref, {'status': QuestStatus.cancelled.wire});
    });
  }

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('change_requests');

  /// Raises the change request an admin will review, and flips the quest to
  /// `pending_review` in the same transaction -- either both writes land or
  /// neither does. The request's `reason` is deliberately left unset: the
  /// link to its quest is carried by `questId`/`questTitle`, rendered as its
  /// own line by the admin screens, not smuggled into free text.
  Future<void> markComplete(
    Quest quest, {
    required String requesterUid,
    required String requesterEmail,
  }) async {
    final questRef = _quests.doc(quest.id);
    final requestRef = _requests.doc();
    await _db.runTransaction((tx) async {
      final snap = await tx.get(questRef);
      final data = snap.data();
      if (data == null || QuestStatus.parse(data['status']) != QuestStatus.assigned) {
        throw const QuestNotAssignedToCaller();
      }
      tx.set(requestRef, {
        'characterId': data['assignedToCharacterId'],
        'characterName': data['assignedToCharacterName'],
        'requesterUid': requesterUid,
        'requesterEmail': requesterEmail,
        'status': ChangeRequestStatus.pending.wire,
        'changes': quest.reward.toMap(),
        'questId': quest.id,
        'questTitle': quest.title,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(questRef, {
        'status': QuestStatus.pendingReview.wire,
        'changeRequestId': requestRef.id,
      });
    });
  }
}
