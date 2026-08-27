import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/change_request.dart';

/// Thrown when a transaction finds the request already accepted or rejected:
/// a double-tap, or a decision taken on another device while this list was
/// stale. Callers surface it as a message rather than re-applying the deltas.
class ChangeRequestNoLongerPending implements Exception {
  const ChangeRequestNoLongerPending();

  @override
  String toString() => 'Ta prośba została już rozpatrzona';
}

class ChangeRequestRepository {
  ChangeRequestRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('change_requests');

  /// `createdAt` is written server-side rather than from the device clock, so
  /// a device with a skewed clock cannot jump the queue.
  Future<void> create(ChangeRequest request) => _requests.add({
        ...request.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

  /// The admin queue. The composite index on (status, createdAt) that this
  /// needs is declared in `firestore.indexes.json`.
  Stream<List<ChangeRequest>> watchPending() => _watch(
        _requests.where('status', isEqualTo: ChangeRequestStatus.pending.wire),
      );

  /// A requester's own history. The `requesterUid` constraint is not just a
  /// filter: the security rule only grants a non-admin read access to their
  /// own requests, so an unconstrained query would be rejected outright.
  Stream<List<ChangeRequest>> watchForRequester(String uid) =>
      _watch(_requests.where('requesterUid', isEqualTo: uid));

  Stream<List<ChangeRequest>> _watch(Query<Map<String, dynamic>> query) =>
      query.snapshots().map((snap) {
        final requests = snap.docs
            .map((d) {
              try {
                return ChangeRequest.fromMap(d.id, d.data());
              } catch (e) {
                debugPrint('Skipping malformed change request ${d.id}: $e');
                return null;
              }
            })
            .whereType<ChangeRequest>()
            .toList();
        // Sorted client-side rather than with orderBy so that a request whose
        // server timestamp has not landed yet (createdAt still null on the
        // local write) is not dropped from the list.
        requests.sort((a, b) {
          final at = a.createdAt;
          final bt = b.createdAt;
          if (at == null && bt == null) return 0;
          if (at == null) return -1; // freshest: still being written
          if (bt == null) return 1;
          return bt.compareTo(at);
        });
        return requests;
      });

  /// Applies [overrides] if the admin edited the request before accepting,
  /// otherwise the request as posted. The character write and the status flip
  /// share one transaction, so either both land or neither does, and the
  /// re-read of the request makes a double-tap a no-op rather than a double
  /// application.
  Future<void> accept(
    ChangeRequest request, {
    ChangeSet? overrides,
    required String adminUid,
  }) async {
    final applied = overrides ?? request.changes;
    final requestRef = _requests.doc(request.id);
    final characterRef = _db.collection('characters').doc(request.characterId);

    await _db.runTransaction((tx) async {
      final requestSnap = await tx.get(requestRef);
      final requestData = requestSnap.data();
      if (requestData == null ||
          ChangeRequestStatus.parse(requestData['status']) !=
              ChangeRequestStatus.pending) {
        throw const ChangeRequestNoLongerPending();
      }

      final characterSnap = await tx.get(characterRef);
      final character = characterSnap.data();
      if (character == null) {
        throw StateError('Character ${request.characterId} no longer exists');
      }

      tx.update(characterRef, _applyTo(character, applied));
      tx.update(requestRef, {
        'status': ChangeRequestStatus.accepted.wire,
        'appliedChanges': applied.toMap(),
        'decidedBy': adminUid,
        'decidedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> reject(
    ChangeRequest request, {
    required String adminUid,
  }) async {
    final requestRef = _requests.doc(request.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(requestRef);
      final data = snap.data();
      if (data == null ||
          ChangeRequestStatus.parse(data['status']) !=
              ChangeRequestStatus.pending) {
        throw const ChangeRequestNoLongerPending();
      }
      tx.update(requestRef, {
        'status': ChangeRequestStatus.rejected.wire,
        'decidedBy': adminUid,
        'decidedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// The character fields to write, given its current data. Only the fields
  /// the request actually touches appear, so accepting an XP-only request
  /// cannot invent a `gold: 0` row on a character that never had one.
  Map<String, dynamic> _applyTo(
    Map<String, dynamic> character,
    ChangeSet changes,
  ) {
    // A field that is absent on the character counts as 0, so `+10 gold`
    // against a character with no `gold` key materialises `gold: 10`.
    num current(String key) {
      final v = character[key];
      if (v is num) return v;
      if (v is String) return num.tryParse(v.trim()) ?? 0;
      return 0;
    }

    final updates = <String, dynamic>{
      if (changes.currentXp != null)
        'current_xp': (current('current_xp') + changes.currentXp!).toInt(),
      if (changes.gold != null) 'gold': current('gold') + changes.gold!,
      if (changes.goldUsd != null)
        'gold_usd': current('gold_usd') + changes.goldUsd!,
    };

    if (changes.traits.isNotEmpty) {
      final raw = character['traits'];
      final traits = <Map<String, dynamic>>[
        if (raw is List)
          for (final t in raw.whereType<Map>())
            {
              'name': t['name'] is String ? t['name'] as String : '',
              'value': t['value'] is String ? t['value'] as String : '',
            },
      ];
      for (final change in changes.traits) {
        final index = traits.indexWhere((t) => t['name'] == change.name);
        if (index >= 0) {
          traits[index] = change.toMap();
        } else {
          traits.add(change.toMap());
        }
      }
      updates['traits'] = traits;
    }

    return updates;
  }
}
