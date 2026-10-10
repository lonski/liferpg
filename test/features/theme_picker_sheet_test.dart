import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liferpg/data/shared_preferences_provider.dart';
import 'package:liferpg/features/theme/theme_picker_sheet.dart';
import 'package:liferpg/providers/app_theme_providers.dart';
import 'package:liferpg/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app shell as LifeRpgApp builds it -- the theme follows
/// appThemeProvider -- around a page with a button opening the sheet.
class _Shell extends ConsumerWidget {
  const _Shell();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        theme: buildAppTheme(ref.watch(appThemeProvider).theme),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.rpg.id.name, key: const Key('active-theme')),
                  TextButton(
                    key: const Key('open'),
                    onPressed: () => showThemePicker(context),
                    child: const Text('Wygląd'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

Future<SharedPreferences> _pump(WidgetTester tester, {Map<String, Object> stored = const {}}) async {
  SharedPreferences.setMockInitialValues(stored);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const _Shell(),
  ));
  await tester.pumpAndSettle();
  return prefs;
}

String _activeTheme(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('active-theme'))).data!;

void main() {
  testWidgets('offers every theme, marking the active one', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    expect(find.text('Kronika'), findsOneWidget);
    expect(find.text('Kurczaki'), findsOneWidget);
    expect(find.byKey(const Key('theme-option-kronika')), findsOneWidget);
    expect(find.byKey(const Key('theme-option-kurczaki')), findsOneWidget);
    // Only the active tile carries the check mark.
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('choosing Kurczaki re-themes the app, closes the sheet and '
      'remembers the choice', (tester) async {
    final prefs = await _pump(tester);
    expect(_activeTheme(tester), 'kronika');

    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('theme-option-kurczaki')));
    await tester.pumpAndSettle();

    expect(_activeTheme(tester), 'kurczaki');
    expect(find.byType(ThemePickerSheet), findsNothing);
    expect(prefs.getString('app_theme'), 'kurczaki');
  });

  testWidgets('a remembered choice applies from the first frame', (tester) async {
    await _pump(tester, stored: {'app_theme': 'kurczaki'});
    expect(_activeTheme(tester), 'kurczaki');
  });
}
