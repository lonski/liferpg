import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/models/quest.dart';
import 'package:liferpg/models/theme_tips.dart';
import 'package:liferpg/providers/quest_providers.dart';
import 'package:liferpg/providers/theme_chatter_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: [
    sharedPreferencesProvider.overrideWithValue(prefs),
    openQuestsProvider.overrideWith((ref) => Stream.value(const <Quest>[])),
    myAssignedQuestsProvider.overrideWith((ref) => Stream.value(const <Quest>[])),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('sounds are on by default and the switch is remembered', () async {
    final container = await _container({});
    expect(container.read(themeSoundsEnabledProvider), isTrue);

    container.read(themeSoundsEnabledProvider.notifier).set(false);
    expect(container.read(themeSoundsEnabledProvider), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('theme_sounds'), isFalse);
  });

  test('a stored "off" is read back', () async {
    final container = await _container({'theme_sounds': false});
    expect(container.read(themeSoundsEnabledProvider), isFalse);
  });

  test('without quests the tips are the evergreen hints', () async {
    final container = await _container({});
    expect(container.read(themeTipsProvider), kGeneralTips);
  });
}
