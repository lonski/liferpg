import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/quest_notifications.dart';

void main() {
  test('first-ever check seeds the baseline silently', () {
    final diff = diffNewIds<int>(
      items: [1, 2, 3],
      idOf: (i) => '$i',
      previouslyNotified: null,
    );
    expect(diff.toNotify, isEmpty);
    expect(diff.notifiedIds, {'1', '2', '3'});
  });

  test('only newly-appearing ids are notified', () {
    final diff = diffNewIds<int>(
      items: [1, 2, 3],
      idOf: (i) => '$i',
      previouslyNotified: {'1'},
    );
    expect(diff.toNotify, [2, 3]);
    expect(diff.notifiedIds, {'1', '2', '3'});
  });

  test('an id that leaves the set is dropped, so it notifies again if it returns', () {
    final diff = diffNewIds<int>(
      items: [1],
      idOf: (i) => '$i',
      previouslyNotified: {'1', '2'},
    );
    expect(diff.toNotify, isEmpty);
    expect(diff.notifiedIds, {'1'});
  });
}
