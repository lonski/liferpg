import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/achievement.dart';
import 'package:liferpg/models/achievement_formatting.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/electronics_days.dart';

void main() {
  test('Polish dates', () {
    expect(formatPolishDate(parseDay('2026-09-12')!), '12 września 2026');
    expect(formatShortPolishDate(parseDay('2026-10-04')!), '4 paź 2026');
  });

  test('roman places and tier names', () {
    expect([1, 2, 3].map(romanPlace), ['I', 'II', 'III']);
    expect(tierLabel(AchievementTier.bronze), 'Brąz');
    expect(tierAdjective(AchievementTier.ruby), 'rubinowa');
  });

  test('rewardParts lists only non-zero parts with signs', () {
    expect(
      rewardParts(const AchievementReward(
        currentXp: 150,
        gold: 50,
        trait: TraitChange(name: 'Recytacja', value: '1'),
        electronicsDays: 2,
      )),
      ['+150 XP', '+50 zł', 'Recytacja +1', '+2 dni elektroniki'],
    );
    expect(
      rewardParts(const AchievementReward(gold: -7.5, electronicsDays: -1)),
      ['−7.5 zł', '−1 dzień elektroniki'],
    );
    expect(rewardParts(const AchievementReward(currentXp: 0)), isEmpty);
  });

  test('badgeCountLabel agrees with the count', () {
    expect(badgeCountLabel(0), 'zdobytych odznak');
    expect(badgeCountLabel(1), 'zdobyta odznaka');
    expect(badgeCountLabel(2), 'zdobyte odznaki');
    expect(badgeCountLabel(4), 'zdobyte odznaki');
    expect(badgeCountLabel(5), 'zdobytych odznak');
    expect(badgeCountLabel(12), 'zdobytych odznak');
    expect(badgeCountLabel(22), 'zdobyte odznaki');
  });
}
