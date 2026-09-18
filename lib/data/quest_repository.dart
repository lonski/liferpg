import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/change_request.dart' show ChangeRequestStatus, ChangeSet;
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

/// Thrown when `markComplete` re-reads a daily quest and its
/// `lastCompletedDate` already matches today -- the UI already hides the
/// Ukończ action once `Quest.isDueToday` is false, but this re-checks
/// against a fresh server read rather than trusting client-side state (e.g.
/// a second device, or a screen that didn't refresh yet).
class QuestAlreadyCompletedToday implements Exception {
  const QuestAlreadyCompletedToday();

  @override
  String toString() => 'To zadanie zostało już dziś zrobione';
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

  /// A single quest by id, for the share-link detail screen. `null` covers
  /// both "no such document" and a malformed one -- the caller renders the
  /// same not-found state either way.
  Stream<Quest?> watchById(String id) => _quests.doc(id).snapshots().map((snap) {
        final data = snap.data();
        if (data == null) return null;
        try {
          return Quest.fromMap(snap.id, data);
        } catch (e) {
          debugPrint('Malformed quest $id: $e');
          return null;
        }
      });

  Stream<List<Quest>> watchOpen() =>
      _watch(_quests.where('status', isEqualTo: QuestStatus.open.wire));

  /// Every daily quest, any status -- the CODZIENNE tab's admin-only
  /// management section, so an admin can see (and edit/deactivate) every
  /// recurring chore regardless of who holds it. Reading `/quests` is
  /// unconstrained for any signed-in user (see firestore.rules), same as the
  /// board and log, so this needs no admin-only rule of its own; the
  /// management UI itself is what's admin-gated.
  Stream<List<Quest>> watchAllDaily() =>
      _watch(_quests.where('isDaily', isEqualTo: true));

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

  /// The poster's own title/description/reward edit -- re-reads the quest to
  /// confirm it is still `open` (nobody took it out from under the poster
  /// while they were editing) before writing, same staleness guard as
  /// `take`/`withdraw`. `assignedTo*`/`status`/poster fields are untouched:
  /// the update rule only grants these three keys.
  Future<void> edit(
    Quest quest, {
    required String title,
    String? description,
    required ChangeSet reward,
  }) async {
    final ref = _quests.doc(quest.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data();
      if (data == null || QuestStatus.parse(data['status']) != QuestStatus.open) {
        throw const QuestNotOpen();
      }
      tx.update(ref, {
        'title': title,
        'description': description ?? FieldValue.delete(),
        'reward': reward.toMap(),
      });
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
      if (quest.isDaily && data['lastCompletedDate'] == dailyQuestStamp()) {
        throw const QuestAlreadyCompletedToday();
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
        // Stamped here, at the moment the holder reports it, rather than
        // when an admin later accepts/rejects -- so the "already done today"
        // button state is immediate and doesn't depend on review latency.
        if (quest.isDaily) 'lastCompletedDate': dailyQuestStamp(),
      });
    });
  }

  /// The admin's edit of a daily quest's title/description/reward. Unlike
  /// [edit] (the poster's own edit of a still-`open` quest), this has no
  /// status guard: a daily quest is never `open`, and only an admin can call
  /// this in the first place (firestore.rules' blanket `isAdmin()` clause),
  /// so there's no race to protect against with a transaction.
  Future<void> editDaily(
    Quest quest, {
    required String title,
    String? description,
    required ChangeSet reward,
  }) =>
      _quests.doc(quest.id).update({
        'title': title,
        'description': description ?? FieldValue.delete(),
        'reward': reward.toMap(),
      });

  /// Admin deactivation of a daily quest -- ends its recurring assignment
  /// for good, the same terminal `cancelled` status an ordinary withdrawn
  /// quest gets (so it surfaces in DZIENNIK like any other retired quest).
  Future<void> cancelDaily(Quest quest) =>
      _quests.doc(quest.id).update({'status': QuestStatus.cancelled.wire});
}
