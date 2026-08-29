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
  });
}
