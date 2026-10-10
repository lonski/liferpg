import 'change_request.dart';

/// The character fields to write for the XP / gold / trait part of
/// [changes], given the character's current data. Only fields the change
/// actually touches appear, so an XP-only change cannot invent `gold: 0`.
/// Shared by change-request accept and achievement award / revoke; nothing
/// here clamps, so a negative delta may take a value below zero.
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
      'current_xp': (current('current_xp') + changes.currentXp!).toInt(),
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
