import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/quest_deep_link.dart';

void main() {
  test('questDeepLink builds a https://liferpg.lonski.pl/quest/<id> link', () {
    expect(
      questDeepLink('abc123'),
      'https://liferpg.lonski.pl/quest/abc123',
    );
  });

  test('questIdFromDeepLink extracts the id from the https link shape', () {
    expect(
      questIdFromDeepLink(
        Uri.parse('https://liferpg.lonski.pl/quest/abc123'),
      ),
      'abc123',
    );
  });

  test(
      'questIdFromDeepLink still extracts the id from the legacy '
      'liferpg://quest/<id> shape', () {
    expect(questIdFromDeepLink(Uri.parse('liferpg://quest/abc123')), 'abc123');
  });

  test('questIdFromDeepLink rejects an https link on the wrong host', () {
    expect(
      questIdFromDeepLink(Uri.parse('https://example.com/quest/abc123')),
      isNull,
    );
  });

  test('questIdFromDeepLink rejects an http (non-https) link', () {
    expect(
      questIdFromDeepLink(Uri.parse('http://liferpg.lonski.pl/quest/abc123')),
      isNull,
    );
  });

  test(
      'questIdFromDeepLink rejects an https link whose first path segment '
      "isn't quest", () {
    expect(
      questIdFromDeepLink(
        Uri.parse('https://liferpg.lonski.pl/character/abc123'),
      ),
      isNull,
    );
  });

  test('questIdFromDeepLink rejects an https link with no id segment', () {
    expect(
      questIdFromDeepLink(Uri.parse('https://liferpg.lonski.pl/quest/')),
      isNull,
    );
    expect(
      questIdFromDeepLink(Uri.parse('https://liferpg.lonski.pl/quest')),
      isNull,
    );
  });

  test('questIdFromDeepLink rejects the legacy shape on the wrong host', () {
    expect(
      questIdFromDeepLink(Uri.parse('liferpg://character/abc123')),
      isNull,
    );
  });

  test('questIdFromDeepLink rejects the legacy shape with no id segment', () {
    expect(questIdFromDeepLink(Uri.parse('liferpg://quest/')), isNull);
    expect(questIdFromDeepLink(Uri.parse('liferpg://quest')), isNull);
  });
}
