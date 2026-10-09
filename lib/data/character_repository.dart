import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../models/character.dart';
import '../models/electronics_days.dart';

/// Thrown when an electronics write re-reads the character mid-transaction
/// and it has vanished.
class CharacterNotFound implements Exception {
  const CharacterNotFound();

  @override
  String toString() => 'Postać już nie istnieje';
}

/// A snapshot of the roster plus the sync metadata the AppBar needs in order
/// to say whether what you are looking at came off the device or the server.
class CharacterFeed {
  const CharacterFeed({
    required this.characters,
    required this.isFromCache,
    required this.hasPendingWrites,
  });

  final List<Character> characters;
  final bool isFromCache;
  final bool hasPendingWrites;

  bool get isOffline => isFromCache || hasPendingWrites;
}

class CharacterRepository {
  CharacterRepository(this._db, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final FirebaseFirestore _db;
  final DateTime Function() _clock;

  /// Admins and readOnlyOthers users watch the whole collection; everyone else
  /// watches only the characters carrying their own email.
  Stream<CharacterFeed> watchCharacters(AppUser user) {
    final collection = _db.collection('characters');
    final Query<Map<String, dynamic>> query = user.canSeeAllCharacters
        ? collection
        : collection.where('email', isEqualTo: user.email);

    return query.snapshots(includeMetadataChanges: true).map(
          (snap) => CharacterFeed(
            characters: snap.docs
                .map((d) {
                  try {
                    return Character.fromMap(d.id, d.data());
                  } catch (e) {
                    debugPrint('Skipping malformed character ${d.id}: $e');
                    return null;
                  }
                })
                .whereType<Character>()
                .toList(),
            isFromCache: snap.metadata.isFromCache,
            hasPendingWrites: snap.metadata.hasPendingWrites,
          ),
        );
  }

  Future<void> updateCharacter(Character character) =>
      _db.collection('characters').doc(character.id).update(character.toMap());

  /// An admin spending today's electronics day directly, no request needed.
  Future<void> claimElectronicsDay(String characterId) =>
      _updateElectronics(characterId, (e, today) => e.applyClaim(today, today));

  /// An admin's hand-set value (including a +1 bonus day).
  Future<void> setElectronicsDays(String characterId, int value) =>
      _updateElectronics(characterId, (e, today) => e.withValue(value, today));

  /// Read-modify-write in a transaction so a concurrent accept can't be lost.
  Future<void> _updateElectronics(
    String characterId,
    ElectronicsDays Function(ElectronicsDays current, int today) change,
  ) async {
    final ref = _db.collection('characters').doc(characterId);
    final today = dayOf(_clock());
    await _db.runTransaction((tx) async {
      final data = (await tx.get(ref)).data();
      if (data == null) throw const CharacterNotFound();
      final next = change(ElectronicsDays.fromMap(data['electronics']), today);
      tx.update(ref, {'electronics': next.toMap()});
    });
  }
}
