import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/quest_deep_link.dart';

void main() {
  test('questDeepLink builds a liferpg://quest/<id> link', () {
    expect(questDeepLink('abc123'), 'liferpg://quest/abc123');
  });

  test('questIdFromDeepLink extracts the id from a matching link', () {
    expect(questIdFromDeepLink(Uri.parse('liferpg://quest/abc123')), 'abc123');
  });

  test('questIdFromDeepLink rejects a different scheme', () {
    expect(questIdFromDeepLink(Uri.parse('https://quest/abc123')), isNull);
  });

  test('questIdFromDeepLink rejects a different host', () {
    expect(questIdFromDeepLink(Uri.parse('liferpg://character/abc123')), isNull);
  });

  test('questIdFromDeepLink rejects a link with no id segment', () {
    expect(questIdFromDeepLink(Uri.parse('liferpg://quest/')), isNull);
    expect(questIdFromDeepLink(Uri.parse('liferpg://quest')), isNull);
  });
}
