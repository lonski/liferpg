import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/quest_roster_entry.dart';

class QuestRosterRepository {
  QuestRosterRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _roster =>
      _db.collection('quest_roster');

  Stream<List<QuestRosterEntry>> watchRoster() => _roster.snapshots().map((snap) {
        final entries = snap.docs
            .map((d) {
              try {
                return QuestRosterEntry.fromMap(d.id, d.data());
              } catch (e) {
                debugPrint('Skipping malformed quest roster entry ${d.id}: $e');
                return null;
              }
            })
            .whereType<QuestRosterEntry>()
            .toList();
        entries.sort((a, b) => a.characterName.compareTo(b.characterName));
        return entries;
      });

  /// The doc id is always the character's own id -- a `set` here both adds a
  /// new entry and updates an existing one's denormalised name/email.
  Future<void> add({
    required String characterId,
    required String characterName,
    required String email,
  }) =>
      _roster.doc(characterId).set(
        QuestRosterEntry(
          characterId: characterId,
          characterName: characterName,
          email: email.toLowerCase(),
        ).toMap(),
      );

  Future<void> remove(String characterId) => _roster.doc(characterId).delete();
}
