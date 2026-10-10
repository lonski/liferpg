import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/models/change_request.dart';
import 'package:liferpg/models/character_deltas.dart';

void main() {
  test('only touched fields appear', () {
    expect(applyCharacterDeltas({'gold': 10}, const ChangeSet(currentXp: 5)),
        {'current_xp': 5});
  });

  test('xp is whole, gold keeps fractions, legacy strings coerce', () {
    final u = applyCharacterDeltas(
      {'current_xp': '40', 'gold': 'n/a'},
      const ChangeSet(currentXp: 10.7, gold: 2.5),
    );
    expect(u['current_xp'], 50);
    expect(u['gold'], 2.5);
  });

  test('may go negative', () {
    final u = applyCharacterDeltas({'current_xp': 10, 'gold': 10},
        const ChangeSet(currentXp: -150, gold: -50));
    expect(u, {'current_xp': -140, 'gold': -40});
  });

  test('traits add by name, append new names verbatim, keep zero', () {
    final u = applyCharacterDeltas({
      'traits': [
        {'name': 'Recytacja', 'value': '1'},
        {'name': 'Siła', 'value': '18'},
      ],
    }, const ChangeSet(traits: [
      TraitChange(name: 'Recytacja', value: '-1'),
    ]));
    expect(u['traits'], [
      {'name': 'Recytacja', 'value': '0'},
      {'name': 'Siła', 'value': '18'},
    ]);
    final appended = applyCharacterDeltas({},
        const ChangeSet(traits: [TraitChange(name: 'Odwaga', value: '-1')]));
    expect(appended['traits'], [
      {'name': 'Odwaga', 'value': '-1'}
    ]);
  });
}
