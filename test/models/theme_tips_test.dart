import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/quest.dart';
import 'package:liferpg/models/theme_tips.dart';

Quest _quest(
  String title, {
  ChangeSet reward = const ChangeSet(currentXp: 10),
  QuestStatus status = QuestStatus.open,
  bool isDaily = false,
}) =>
    Quest(
      id: title,
      title: title,
      posterUid: 'u1',
      posterEmail: 'ala@example.com',
      posterName: 'Ala',
      status: status,
      reward: reward,
      isDaily: isDaily,
    );

void main() {
  test('an open quest tips off its XP', () {
    expect(
      questTips(open: [_quest('Zmywarka')], assigned: const []),
      ['Psst! Za „Zmywarka” jest aż 10 XP!'],
    );
  });

  test('a trait-only reward names the trait, keeping a sign it already has', () {
    expect(
      questTips(open: [
        _quest('Czytanie', reward: const ChangeSet(traits: [TraitChange(name: 'Mądrość', value: '2')])),
        _quest('Rower', reward: const ChangeSet(traits: [TraitChange(name: 'Siła', value: '+1')])),
      ], assigned: const []),
      ['Psst! Za „Czytanie” jest aż +2 Mądrość!', 'Psst! Za „Rower” jest aż +1 Siła!'],
    );
  });

  test('a quest worth nothing gives no tip', () {
    expect(questTips(open: [_quest('Nic', reward: const ChangeSet())], assigned: const []), isEmpty);
  });

  test('a daily quest on the board and one still due today', () {
    expect(
      questTips(
        open: [_quest('Kury', isDaily: true)],
        assigned: [
          _quest('Pościel łóżko', isDaily: true, status: QuestStatus.assigned),
          // An ordinary assigned quest isn't a chore of the day.
          _quest('Garaż', status: QuestStatus.assigned),
        ],
      ),
      ['Codziennie: „Kury” to 10 XP!', 'Dziś jeszcze „Pościel łóżko” — 10 XP!'],
    );
  });

  test('a long title is shortened to fit the bubble', () {
    final tip = questTips(
      open: [_quest('Posprzątaj cały garaż razem z piwnicą i strychem')],
      assigned: const [],
    ).single;
    expect(tip, contains('…”'));
    expect(tip.length, lessThan(60));
  });
}
