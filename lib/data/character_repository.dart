import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/character.dart';

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
  CharacterRepository(this._db);

  final FirebaseFirestore _db;

  /// Admins and readOnlyOthers users watch the whole collection; everyone else
  /// watches only the characters carrying their own email.
  Stream<CharacterFeed> watchCharacters(AppUser user) {
    final collection = _db.collection('characters');
    final Query<Map<String, dynamic>> query = user.canSeeAllCharacters
        ? collection
        : collection.where('email', isEqualTo: user.email);

    return query.snapshots(includeMetadataChanges: true).map(
          (snap) => CharacterFeed(
            characters:
                snap.docs.map((d) => Character.fromMap(d.id, d.data())).toList(),
            isFromCache: snap.metadata.isFromCache,
            hasPendingWrites: snap.metadata.hasPendingWrites,
          ),
        );
  }

  Future<void> updateCharacter(Character character) =>
      _db.collection('characters').doc(character.id).update(character.toMap());
}
