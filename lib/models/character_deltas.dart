import 'dart:math' as math;

import 'change_request.dart';

int _xpField(Object? v) {
  if (v is num) return v.toInt();
  if (v is String) return num.tryParse(v.trim())?.toInt() ?? 0;
  return 0;
}

/// The character's `xp_earned` (see Character.xpEarned), falling back to
/// `current_xp` before the first XP write records it.
int earnedXpOf(Map<String, dynamic> character) {
  final v = character['xp_earned'];
  return v is num ? v.toInt() : _xpField(character['current_xp']);
}

/// The `current_xp` + `xp_earned` pair for setting XP to [xp]: only a rise
/// adds to `xp_earned`, so lowering XP (a level-up) never takes boss
/// energy away.
Map<String, int> xpUpdate(Map<String, dynamic> character, int xp) => {
  'current_xp': xp,
  'xp_earned':
      earnedXpOf(character) +
      math.max(0, xp - _xpField(character['current_xp'])),
};

/// The character fields to write for the XP / gold / trait part of
/// [changes], given the character's current data. Only fields the change
/// actually touches appear, so an XP-only change cannot invent `gold: 0`.
/// Shared by change-request accept and achievement award / revoke; nothing
/// here clamps, so a negative delta may take a value below zero. An XP
/// change also writes `xp_earned` (see [xpUpdate]).
Map<String, dynamic> applyCharacterDeltas(
  Map<String, dynamic> character,
  ChangeSet changes,
) {
  // A field that is absent on the character counts as 0, so `+10 gold`
  // against a character with no `gold` key materialises `gold: 10`.
  num current(String key) {
    final v = character[key];
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim()) ?? 0;
    return 0;
  }

  final updates = <String, dynamic>{
    if (changes.currentXp != null)
      ...xpUpdate(
        character,
        (current('current_xp') + changes.currentXp!).toInt(),
      ),
    if (changes.gold != null) 'gold': current('gold') + changes.gold!,
  };

  if (changes.traits.isNotEmpty) {
    final raw = character['traits'];
    final traits = <Map<String, dynamic>>[
      if (raw is List)
        for (final t in raw.whereType<Map>())
          {
            'name': t['name'] is String ? t['name'] as String : '',
            'value': t['value'] is String ? t['value'] as String : '',
          },
    ];
    for (final change in changes.traits) {
      final index = traits.indexWhere((t) => t['name'] == change.name);
      if (index >= 0) {
        // A trait change is a numeric delta added to the character's
        // current value, mirroring current_xp/gold above -- not a
        // replacement. A value that doesn't parse (an old free-form trait,
        // say) is tolerantly treated as 0, per the same coercion `current`
        // applies to current_xp/gold.
        final currentValue =
            num.tryParse((traits[index]['value'] as String).trim()) ?? 0;
        final delta = num.tryParse(change.value.trim()) ?? 0;
        final next = currentValue + delta;
        traits[index] = {
          'name': change.name,
          'value': next % 1 == 0 ? next.toInt().toString() : '$next',
        };
      } else {
        // No current value to add to, so the change's value becomes the
        // trait's starting value verbatim.
        traits.add(change.toMap());
      }
    }
    updates['traits'] = traits;
  }

  return updates;
}
