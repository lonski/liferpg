import 'quest.dart';

/// Tips a theme's mascots drop into their speech bubbles, besides their own
/// noises: real rewards from the board and the player's daily chores
/// ("Psst! Za „Zmywarka” jest aż 10 XP!") plus a few evergreen hints.
const List<String> kGeneralTips = [
  'Zajrzyj na TABLICĘ — czekają zadania!',
  'Zadania codzienne wracają każdego dnia!',
  'Dzień bez elektroniki? Odbierz go na karcie!',
  'Prośbę o zmianę wyślesz okrągłym przyciskiem!',
  'Odznaki zdobywa się za wyjątkowe wyczyny!',
  'Wygląd zmienisz ikoną palety u góry!',
];

/// [title] cut to fit a two-line bubble.
String _short(String title) {
  final t = title.trim();
  return t.length <= 26 ? t : '${t.substring(0, 25).trimRight()}…';
}

String? _rewardPhrase(Quest q) {
  final xp = q.reward.currentXp;
  if (xp != null && xp > 0) return '$xp XP';
  final trait = q.reward.traits.where((t) => t.name.trim().isNotEmpty).firstOrNull;
  if (trait != null) {
    final v = trait.value.trim();
    // Values are free text and may already carry their sign ("+1").
    return '${v.startsWith('+') || v.startsWith('-') ? v : '+$v'} ${trait.name}';
  }
  return null;
}

/// One tip per quest worth something: what's up for grabs on the [open]
/// board, and the player's [assigned] daily chores still due today.
List<String> questTips({required List<Quest> open, required List<Quest> assigned}) => [
      for (final q in open)
        if (_rewardPhrase(q) case final reward?)
          q.isDaily
              ? 'Codziennie: „${_short(q.title)}” to $reward!'
              : 'Psst! Za „${_short(q.title)}” jest aż $reward!',
      for (final q in assigned)
        if (q.isDaily && q.status == QuestStatus.assigned && q.isDueToday)
          if (_rewardPhrase(q) case final reward?)
            'Dziś jeszcze „${_short(q.title)}” — $reward!',
    ];
