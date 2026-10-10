import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/achievement.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/electronics_days.dart';

void main() {
  final awardedAt = DateTime(2026, 9, 12, 18);

  Map<String, dynamic> full() => {
        'id': 'a1',
        'title': 'II miejsce',
        'event': 'Wojewódzki Konkurs Recytatorski',
        'reason': 'Bez kartki.',
        'date': '2026-09-12',
        'emblem': 'place',
        'place': 2,
        'tier': 'silver',
        'reward': {
          'current_xp': 150,
          'gold': 50,
          'traits': [
            {'name': 'Recytacja', 'value': '1'}
          ],
          'electronics_days': 2,
        },
        'awardedBy': 'admin',
        'awardedByName': 'Tata',
        'awardedAt': Timestamp.fromDate(awardedAt),
      };

  test('parses a full entry and round-trips through toMap', () {
    final a = Achievement.tryParse(full())!;
    expect(a.id, 'a1');
    expect(a.title, 'II miejsce');
    expect(a.event, 'Wojewódzki Konkurs Recytatorski');
    expect(a.date, parseDay('2026-09-12'));
    expect(a.emblem, AchievementEmblem.place);
    expect(a.place, 2);
    expect(a.tier, AchievementTier.silver);
    expect(a.reward.currentXp, 150);
    expect(a.reward.gold, 50);
    expect(a.reward.trait, const TraitChange(name: 'Recytacja', value: '1'));
    expect(a.reward.electronicsDays, 2);
    expect(a.awardedAt, awardedAt);
    expect(Achievement.tryParse(a.toMap())!.toMap(), a.toMap());
  });

  test('drops entries without an id or a title', () {
    expect(Achievement.tryParse({...full(), 'id': null}), isNull);
    expect(Achievement.tryParse({...full(), 'title': '  '}), isNull);
    expect(Achievement.tryParse('not a map'), isNull);
  });

  test('tolerates legacy and unknown values', () {
    final a = Achievement.tryParse({
      ...full(),
      'emblem': 'dragon',
      'tier': 'platinum',
      'place': 7,
      'date': 'yesterday',
      'reward': {'current_xp': '20', 'gold': 'lots', 'electronics_days': 1.0},
    })!;
    expect(a.emblem, AchievementEmblem.star);
    expect(a.tier, AchievementTier.gold);
    expect(a.place, isNull);
    expect(a.date, dayOf(awardedAt));
    expect(a.reward.currentXp, 20);
    expect(a.reward.gold, isNull);
    expect(a.reward.electronicsDays, 1);
  });

  test('a place emblem without a valid place shows a trophy', () {
    final a = Achievement.tryParse({...full(), 'place': null})!;
    expect(a.emblem, AchievementEmblem.place);
    expect(a.shownEmblem, AchievementEmblem.trophy);
  });

  test('negated flips every part of the reward', () {
    final r = Achievement.tryParse(full())!.reward.negated();
    expect(r.currentXp, -150);
    expect(r.gold, -50);
    expect(r.trait, const TraitChange(name: 'Recytacja', value: '-1'));
    expect(r.electronicsDays, -2);
  });

  test('reward toMap omits absent parts and toChangeSet carries xp/gold/trait', () {
    const r = AchievementReward(currentXp: 10);
    expect(r.toMap(), {'current_xp': 10});
    expect(const AchievementReward().isEmpty, isTrue);
    final cs = const AchievementReward(
      gold: 5,
      trait: TraitChange(name: 'Odwaga', value: '1'),
      electronicsDays: 3,
    ).toChangeSet();
    expect(cs.gold, 5);
    expect(cs.traits, [const TraitChange(name: 'Odwaga', value: '1')]);
    expect(cs.electronicsClaim, isNull);
  });

  test('withDetails keeps reward and award stamp', () {
    final a = Achievement.tryParse(full())!;
    final edited = a.withDetails(AchievementDetails(
      title: 'I miejsce',
      date: a.date,
      emblem: AchievementEmblem.place,
      place: 1,
      tier: AchievementTier.gold,
    ));
    expect(edited.title, 'I miejsce');
    expect(edited.event, isNull);
    expect(edited.tier, AchievementTier.gold);
    expect(edited.reward.toMap(), a.reward.toMap());
    expect(edited.awardedAt, a.awardedAt);
  });

  test('newestFirst sorts by date, then by awardedAt', () {
    Achievement at(String id, String date, DateTime awarded) =>
        Achievement.tryParse({
          ...full(),
          'id': id,
          'date': date,
          'awardedAt': Timestamp.fromDate(awarded),
        })!;
    final list = [
      at('old', '2026-01-01', DateTime(2026, 1, 1)),
      at('sameDayEarly', '2026-05-05', DateTime(2026, 5, 5, 8)),
      at('sameDayLate', '2026-05-05', DateTime(2026, 5, 5, 20)),
    ]..sort(Achievement.newestFirst);
    expect(list.map((a) => a.id), ['sameDayLate', 'sameDayEarly', 'old']);
  });


  test('AchievementTier.forPlace', () {
    expect(AchievementTier.forPlace(1), AchievementTier.gold);
    expect(AchievementTier.forPlace(2), AchievementTier.silver);
    expect(AchievementTier.forPlace(3), AchievementTier.bronze);
  });
}
