import 'achievement.dart';

const _monthsGenitive = [
  'stycznia',
  'lutego',
  'marca',
  'kwietnia',
  'maja',
  'czerwca',
  'lipca',
  'sierpnia',
  'września',
  'października',
  'listopada',
  'grudnia',
];

const _monthsShort = [
  'sty',
  'lut',
  'mar',
  'kwi',
  'maj',
  'cze',
  'lip',
  'sie',
  'wrz',
  'paź',
  'lis',
  'gru',
];

DateTime _utc(int day) => DateTime.fromMillisecondsSinceEpoch(
  day * Duration.millisecondsPerDay,
  isUtc: true,
);

/// `12 września 2026`.
String formatPolishDate(int day) {
  final d = _utc(day);
  return '${d.day} ${_monthsGenitive[d.month - 1]} ${d.year}';
}

/// `12 wrz 2026`, for the gallery's tight tiles.
String formatShortPolishDate(int day) {
  final d = _utc(day);
  return '${d.day} ${_monthsShort[d.month - 1]} ${d.year}';
}

String romanPlace(int place) =>
    place >= 1 && place <= 3 ? const ['I', 'II', 'III'][place - 1] : '$place';

String tierLabel(AchievementTier tier) => switch (tier) {
  AchievementTier.gold => 'Złoto',
  AchievementTier.silver => 'Srebro',
  AchievementTier.bronze => 'Brąz',
  AchievementTier.ruby => 'Rubin',
};

/// Agrees with "odznaka": `Odznaka srebrna`.
String tierAdjective(AchievementTier tier) => switch (tier) {
  AchievementTier.gold => 'złota',
  AchievementTier.silver => 'srebrna',
  AchievementTier.bronze => 'brązowa',
  AchievementTier.ruby => 'rubinowa',
};

String _signed(num v) {
  final abs = v.abs();
  final text = abs % 1 == 0 ? abs.toInt().toString() : '$abs';
  return v < 0 ? '−$text' : '+$text';
}

/// `['+150 XP', '+50 zł', 'Recytacja +1', '+2 dni elektroniki']` -- zero
/// parts are left out. Shared by chips, the summary line, the revoke
/// confirmation and the notification body.
List<String> rewardParts(AchievementReward r) {
  final traitDelta = r.trait == null
      ? 0
      : (num.tryParse(r.trait!.value.trim()) ?? 0);
  final days = r.electronicsDays ?? 0;
  return [
    if ((r.currentXp ?? 0) != 0) '${_signed(r.currentXp!)} XP',
    if ((r.gold ?? 0) != 0) '${_signed(r.gold!)} zł',
    if (traitDelta != 0) '${r.trait!.name} ${_signed(traitDelta)}',
    if (days != 0)
      '${_signed(days)} ${days.abs() == 1 ? 'dzień' : 'dni'} elektroniki',
  ];
}

/// The gallery header's noun phrase, agreeing with [count]:
/// `1 zdobyta odznaka`, `2 zdobyte odznaki`, `5 zdobytych odznak`.
String badgeCountLabel(int count) {
  if (count == 1) return 'zdobyta odznaka';
  final lastDigit = count % 10;
  final lastTwo = count % 100;
  if (lastDigit >= 2 && lastDigit <= 4 && (lastTwo < 12 || lastTwo > 14)) {
    return 'zdobyte odznaki';
  }
  return 'zdobytych odznak';
}
