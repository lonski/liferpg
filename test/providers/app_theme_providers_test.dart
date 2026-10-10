import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/providers/app_theme_providers.dart';
import 'package:liferpg/theme/rpg_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container(Map<String, Object> stored) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('defaults to Kronika on a fresh install', () async {
    final container = await _container({});
    expect(container.read(appThemeProvider), AppThemeId.kronika);
  });

  test('reads back the stored choice', () async {
    final container = await _container({'app_theme': 'kurczaki'});
    expect(container.read(appThemeProvider), AppThemeId.kurczaki);
  });

  test('an unknown stored name falls back to Kronika', () async {
    final container = await _container({'app_theme': 'smoki'});
    expect(container.read(appThemeProvider), AppThemeId.kronika);
  });

  test('select applies the theme and remembers it on the device', () async {
    final container = await _container({});
    container.read(appThemeProvider.notifier).select(AppThemeId.kurczaki);

    expect(container.read(appThemeProvider), AppThemeId.kurczaki);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme'), 'kurczaki');
  });

  test('every theme id maps to its own theme', () {
    for (final id in AppThemeId.values) {
      expect(id.theme.id, id);
    }
  });
}
