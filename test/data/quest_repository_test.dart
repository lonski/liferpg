// test/data/quest_repository_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/quest_repository.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/quest.dart';

Quest _openQuest({String title = 'Posprzątaj garaż'}) => Quest(
      id: '',
      title: title,
      posterUid: 'u1',
      posterEmail: 'ala@example.com',
      posterName: 'Ala',
      status: QuestStatus.open,
      reward: const ChangeSet(currentXp: 50),
    );

void main() {
  test('create writes an open quest with a server timestamp', () async {
    final db = FakeFirebaseFirestore();
    await QuestRepository(db).create(_openQuest());

    final docs = await db.collection('quests').get();
    expect(docs.docs, hasLength(1));
    final data = docs.docs.single.data();
    expect(data['status'], 'open');
    expect(data['title'], 'Posprzątaj garaż');
    expect(data['createdAt'], isNotNull);
  });

  test('watchOpen returns only open quests', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRepository(db);
    await repo.create(_openQuest());
    await db.collection('quests').add({
      'title': 'Ugotuj obiad',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'status': 'assigned',
      'reward': {'current_xp': 30},
    });

    final open = await repo.watchOpen().first;
    expect(open, hasLength(1));
    expect(open.single.title, 'Posprzątaj garaż');
  });

  test('watchAssignedTo filters by assignedToCharacterId', () async {
    final db = FakeFirebaseFirestore();
    await db.collection('quests').add({
      'title': 'Ugotuj obiad',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'assignedToCharacterId': 'c1',
      'assignedToCharacterName': 'Grommash',
      'assignedToEmail': 'grommash@example.com',
      'status': 'assigned',
      'reward': {'current_xp': 30},
    });
    await db.collection('quests').add({
      'title': 'Wynieś śmieci',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'assignedToCharacterId': 'c2',
      'status': 'assigned',
      'reward': {'current_xp': 15},
    });

    final mine = await QuestRepository(db).watchAssignedTo(['c1']).first;
    expect(mine, hasLength(1));
    expect(mine.single.title, 'Ugotuj obiad');
  });

  test('watchAssignedTo returns nothing for an empty character list', () async {
    final db = FakeFirebaseFirestore();
    final result = await QuestRepository(db).watchAssignedTo(const []).first;
    expect(result, isEmpty);
  });

  test('watchPostedBy filters by posterUid across all statuses', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRepository(db);
    await repo.create(_openQuest());
    await db.collection('quests').add({
      'title': 'Zrób pranie',
      'posterUid': 'u1',
      'posterEmail': 'ala@example.com',
      'posterName': 'Ala',
      'status': 'cancelled',
      'reward': {'current_xp': 5},
    });
    await db.collection('quests').add({
      'title': 'Nie moje',
      'posterUid': 'u2',
      'posterEmail': 'bob@example.com',
      'posterName': 'Bob',
      'status': 'open',
      'reward': {'current_xp': 5},
    });

    final mine = await repo.watchPostedBy('u1').first;
    expect(mine, hasLength(2));
  });

  test('watchLog returns only terminal statuses', () async {
    final db = FakeFirebaseFirestore();
    for (final status in ['open', 'assigned', 'pending_review']) {
      await db.collection('quests').add({
        'title': 'Niekończące się $status',
        'posterUid': 'u1',
        'posterEmail': 'ala@example.com',
        'posterName': 'Ala',
        'status': status,
        'reward': {'current_xp': 5},
      });
    }
    for (final status in ['completed', 'failed', 'cancelled']) {
      await db.collection('quests').add({
        'title': 'Zakończone $status',
        'posterUid': 'u1',
        'posterEmail': 'ala@example.com',
        'posterName': 'Ala',
        'status': status,
        'reward': {'current_xp': 5},
      });
    }

    final log = await QuestRepository(db).watchLog().first;
    expect(log, hasLength(3));
    expect(log.every((q) => q.title.startsWith('Zakończone')), isTrue);
  });

  test('take assigns an open quest and sets the taker fields', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRepository(db);
    await repo.create(_openQuest());
    final quest = (await repo.watchOpen().first).single;

    await repo.take(
      quest,
      characterId: 'c1',
      characterName: 'Grommash',
      email: 'ala@example.com',
    );

    final doc = await db.collection('quests').doc(quest.id).get();
    expect(doc.data()!['status'], 'assigned');
    expect(doc.data()!['assignedToCharacterId'], 'c1');
  });

  test('take throws QuestNotOpen on a quest already taken', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRepository(db);
    await repo.create(_openQuest());
    final quest = (await repo.watchOpen().first).single;
    await repo.take(quest, characterId: 'c1', characterName: 'Grommash', email: 'a@example.com');

    expect(
      () => repo.take(quest, characterId: 'c2', characterName: 'Bob', email: 'b@example.com'),
      throwsA(isA<QuestNotOpen>()),
    );
  });

  test('abandon returns an assigned quest to open and clears the taker', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRepository(db);
    await repo.create(_openQuest());
    var quest = (await repo.watchOpen().first).single;
    await repo.take(quest, characterId: 'c1', characterName: 'Grommash', email: 'a@example.com');
    quest = (await repo.watchAssignedTo(['c1']).first).single;

    await repo.abandon(quest);

    final doc = await db.collection('quests').doc(quest.id).get();
    expect(doc.data()!['status'], 'open');
    expect(doc.data()!.containsKey('assignedToCharacterId'), isFalse);
  });

  test('abandon throws QuestNotAssignedToCaller on a quest not currently assigned', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRepository(db);
    await repo.create(_openQuest());
    final quest = (await repo.watchOpen().first).single;

    expect(() => repo.abandon(quest), throwsA(isA<QuestNotAssignedToCaller>()));
  });

  test('withdraw cancels an open quest', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRepository(db);
    await repo.create(_openQuest());
    final quest = (await repo.watchOpen().first).single;

    await repo.withdraw(quest);

    final doc = await db.collection('quests').doc(quest.id).get();
    expect(doc.data()!['status'], 'cancelled');
  });

  test('withdraw throws QuestNotOpen on a quest already taken', () async {
    final db = FakeFirebaseFirestore();
    final repo = QuestRepository(db);
    await repo.create(_openQuest());
    final quest = (await repo.watchOpen().first).single;
    await repo.take(quest, characterId: 'c1', characterName: 'Grommash', email: 'a@example.com');

    expect(() => repo.withdraw(quest), throwsA(isA<QuestNotOpen>()));
  });
}
