import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/quest_roster_entry.dart';

void main() {
  test('toMap/fromMap round trip', () {
    const entry = QuestRosterEntry(
      characterId: 'c1',
      characterName: 'Grommash',
      email: 'grommash@example.com',
    );
    final map = entry.toMap();
    expect(map, {'characterName': 'Grommash', 'email': 'grommash@example.com'});

    final roundTripped = QuestRosterEntry.fromMap('c1', map);
    expect(roundTripped.characterId, 'c1');
    expect(roundTripped.characterName, 'Grommash');
    expect(roundTripped.email, 'grommash@example.com');
  });

  test('fromMap tolerates missing fields', () {
    final entry = QuestRosterEntry.fromMap('c2', const {});
    expect(entry.characterName, '');
    expect(entry.email, '');
  });
}
