import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/quest_roster_repository.dart';

void main() {
  test('add writes a roster entry keyed by characterId', () async {
    final db = FakeFirebaseFirestore();
    await QuestRosterRepository(db).add(
      characterId: 'c1',
      characterName: 'Grommash',
      email: 'Grommash@Example.com',
    );

    final doc = await db.collection('quest_roster').doc('c1').get();
    expect(doc.data()!['characterName'], 'Grommash');
    // Lowercased at write time so the create-rule email cross-check on
    // /quests (which compares lowercased strings) can match it directly.
    expect(doc.data()!['email'], 'grommash@example.com');
  });

  test('remove deletes the entry', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRosterRepository(db);
    await repo.add(characterId: 'c1', characterName: 'Grommash', email: 'g@example.com');

    await repo.remove('c1');

    final doc = await db.collection('quest_roster').doc('c1').get();
    expect(doc.exists, isFalse);
  });

  test('watchRoster returns entries sorted by character name', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRosterRepository(db);
    await repo.add(characterId: 'c1', characterName: 'Zorak', email: 'z@example.com');
    await repo.add(characterId: 'c2', characterName: 'Ala', email: 'a@example.com');

    final roster = await repo.watchRoster().first;
    expect(roster.map((e) => e.characterName), ['Ala', 'Zorak']);
  });
}
