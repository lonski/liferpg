import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class UserRepository {
  UserRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<AppUser>> watchUsers() => _db
      .collection('users')
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());

  Future<void> updateUserFlags(String uid, Map<String, Object?> flags) =>
      _db.collection('users').doc(uid).update(flags);
}
