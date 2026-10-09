import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/features/requests/change_request_formatting.dart';
import 'package:liferpg/models/change_request.dart';

void main() {
  test('an electronics claim renders as one line', () {
    expect(
      changeSetLines(const ChangeSet(electronicsClaim: '2026-10-22')),
      ['Dzień z elektroniką: 2026-10-22'],
    );
  });

  test('ordinary deltas still render', () {
    expect(changeSetLines(const ChangeSet(currentXp: 50, gold: -10)),
        ['XP: +50', 'Złoto: -10']);
  });
}
