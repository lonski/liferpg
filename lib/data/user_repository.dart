import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_user.dart';
import 'firebase_providers.dart';

/// Lives here, beside the repository it builds, rather than in
/// providers/user_providers.dart: auth_providers.dart needs it too, and
/// user_providers.dart already imports auth_providers.dart -- keeping the
/// provider in the data layer avoids that import cycle entirely.
/// user_providers.dart re-exports it, so existing importers are unaffected.
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(ref.watch(firestoreProvider)),
);

class UserRepository {
  UserRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<AppUser>> watchUsers() => _db.collection('users').snapshots().map(
        (snap) => snap.docs
            .map((d) {
              try {
                return AppUser.fromMap(d.id, d.data());
              } catch (e) {
                debugPrint('Skipping malformed user ${d.id}: $e');
                return null;
              }
            })
            .whereType<AppUser>()
            .toList(),
      );

  /// The single users/{uid} document, live. A missing document yields null.
  Stream<AppUser?> watchUser(String uid) =>
      _db.collection('users').doc(uid).snapshots().map((doc) {
        if (!doc.exists) return null;
        try {
          return AppUser.fromMap(doc.id, doc.data()!);
        } catch (e) {
          debugPrint('Skipping malformed user ${doc.id}: $e');
          return null;
        }
      });

  Future<void> updateUserFlags(String uid, Map<String, Object?> flags) =>
      _db.collection('users').doc(uid).update(flags);
}
