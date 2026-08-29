String? _asString(Object? v) => v is String ? v : null;

/// A thin, admin-curated public index of characters eligible for direct
/// quest assignment -- name/id/email only, never the character's stats. The
/// document id is always the character's own id.
class QuestRosterEntry {
  const QuestRosterEntry({
    required this.characterId,
    required this.characterName,
    required this.email,
  });

  final String characterId;
  final String characterName;
  final String email;

  factory QuestRosterEntry.fromMap(String id, Map<String, dynamic> data) =>
      QuestRosterEntry(
        characterId: id,
        characterName: _asString(data['characterName']) ?? '',
        email: _asString(data['email']) ?? '',
      );

  Map<String, dynamic> toMap() => {
        'characterName': characterName,
        'email': email,
      };
}
