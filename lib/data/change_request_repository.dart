import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/change_request.dart';

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
}
