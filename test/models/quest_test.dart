import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/quest.dart';

void main() {
  group('QuestStatus', () {
    test('wire round-trips pending_review', () {
      expect(QuestStatus.pendingReview.wire, 'pending_review');
      expect(QuestStatus.parse('pending_review'), QuestStatus.pendingReview);
    });

    test('parse defaults unrecognised values to open', () {
      expect(QuestStatus.parse('nonsense'), QuestStatus.open);
      expect(QuestStatus.parse(null), QuestStatus.open);
    });
  });

  group('Quest', () {
    test('toMap/fromMap round trip for an open board quest', () {
      const quest = Quest(
        id: 'q1',
        title: 'Posprzątaj garaż',
        description: 'Naprawdę duży bałagan',
        posterUid: 'u1',
        posterEmail: 'ala@example.com',
        posterName: 'Ala',
        status: QuestStatus.open,
        reward: ChangeSet(currentXp: 50, traits: [TraitChange(name: 'Porządek', value: '+1')]),
      );

      final map = quest.toMap();
      expect(map['status'], 'open');
      expect(map.containsKey('assignedToCharacterId'), isFalse);
      expect(map['reward'], {
        'current_xp': 50,
        'traits': [
          {'name': 'Porządek', 'value': '+1'},
        ],
      });

      final roundTripped = Quest.fromMap('q1', map);
      expect(roundTripped.title, quest.title);
      expect(roundTripped.reward.currentXp, 50);
      expect(roundTripped.assignedToCharacterId, isNull);
    });

    test('toMap/fromMap round trip for a directly-assigned quest', () {
      const quest = Quest(
        id: 'q2',
        title: 'Ugotuj obiad',
        posterUid: 'u1',
        posterEmail: 'ala@example.com',
        posterName: 'Ala',
        assignedToCharacterId: 'c1',
        assignedToCharacterName: 'Grommash',
        assignedToEmail: 'grommash@example.com',
        status: QuestStatus.assigned,
        reward: ChangeSet(currentXp: 30),
        changeRequestId: null,
      );

      final map = quest.toMap();
      final roundTripped = Quest.fromMap('q2', map);
      expect(roundTripped.assignedToCharacterId, 'c1');
      expect(roundTripped.status, QuestStatus.assigned);
    });

    test('fromMap tolerates a missing reward map', () {
      final quest = Quest.fromMap('q3', {
        'title': 'Wynieś śmieci',
        'posterUid': 'u1',
        'posterEmail': 'ala@example.com',
        'posterName': 'Ala',
        'status': 'open',
      });
      expect(quest.reward.isEmpty, isTrue);
    });

    test('toMap/fromMap round trip for a daily quest', () {
      const quest = Quest(
        id: 'q4',
        title: 'Wyprowadzić psa',
        posterUid: 'admin1',
        posterEmail: 'admin@example.com',
        posterName: 'Admin',
        assignedToCharacterId: 'c1',
        assignedToCharacterName: 'Grommash',
        assignedToEmail: 'grommash@example.com',
        status: QuestStatus.assigned,
        reward: ChangeSet(currentXp: 10),
        isDaily: true,
        lastCompletedDate: '2026-09-17',
      );

      final map = quest.toMap();
      expect(map['isDaily'], true);
      expect(map['lastCompletedDate'], '2026-09-17');

      final roundTripped = Quest.fromMap('q4', map);
      expect(roundTripped.isDaily, isTrue);
      expect(roundTripped.lastCompletedDate, '2026-09-17');
    });

    test('isDaily defaults to false and is omitted from the map', () {
      const quest = Quest(
        id: 'q5',
        title: 'Posprzątaj garaż',
        posterUid: 'u1',
        posterEmail: 'ala@example.com',
        posterName: 'Ala',
        status: QuestStatus.open,
        reward: ChangeSet(currentXp: 50),
      );

      expect(quest.isDaily, isFalse);
      expect(quest.toMap().containsKey('isDaily'), isFalse);
    });
  });

  group('Quest.isDueToday', () {
    test('false for a non-daily quest regardless of lastCompletedDate', () {
      const quest = Quest(
        id: 'q6',
        title: 'Posprzątaj garaż',
        posterUid: 'u1',
        posterEmail: 'ala@example.com',
        posterName: 'Ala',
        status: QuestStatus.open,
        reward: ChangeSet(currentXp: 50),
      );
      expect(quest.isDueToday, isFalse);
    });

    test('true for a daily quest never completed', () {
      const quest = Quest(
        id: 'q7',
        title: 'Wyprowadzić psa',
        posterUid: 'admin1',
        posterEmail: 'admin@example.com',
        posterName: 'Admin',
        status: QuestStatus.assigned,
        reward: ChangeSet(currentXp: 10),
        isDaily: true,
      );
      expect(quest.isDueToday, isTrue);
    });

    test('false for a daily quest already completed today', () {
      final quest = Quest(
        id: 'q8',
        title: 'Wyprowadzić psa',
        posterUid: 'admin1',
        posterEmail: 'admin@example.com',
        posterName: 'Admin',
        status: QuestStatus.assigned,
        reward: const ChangeSet(currentXp: 10),
        isDaily: true,
        lastCompletedDate: dailyQuestStamp(),
      );
      expect(quest.isDueToday, isFalse);
    });

    test('true for a daily quest completed on an earlier day', () {
      const quest = Quest(
        id: 'q9',
        title: 'Wyprowadzić psa',
        posterUid: 'admin1',
        posterEmail: 'admin@example.com',
        posterName: 'Admin',
        status: QuestStatus.assigned,
        reward: ChangeSet(currentXp: 10),
        isDaily: true,
        lastCompletedDate: '2000-01-01',
      );
      expect(quest.isDueToday, isTrue);
    });
  });

  group('dailyQuestStamp', () {
    test('formats as yyyy-MM-dd with zero-padding', () {
      expect(dailyQuestStamp(DateTime(2026, 3, 5)), '2026-03-05');
    });
  });
}
