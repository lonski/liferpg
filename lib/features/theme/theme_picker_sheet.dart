import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_theme_providers.dart';
import '../../providers/theme_chatter_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

/// Opens the "Wygląd" sheet: one tile per [AppThemeId], each previewed in
/// its own theme. Choosing one applies it immediately (and remembers it on
/// this device) and closes the sheet.
Future<void> showThemePicker(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      // Two rows of tiles outgrow the default 9/16-of-the-screen cap.
      isScrollControlled: true,
      backgroundColor: context.rpg.parchmentLight,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: context.rpg.crimson, width: 3),
      ),
      builder: (_) => const ThemePickerSheet(),
    );

class ThemePickerSheet extends ConsumerWidget {
  const ThemePickerSheet({super.key});

  static String nameOf(AppThemeId id) => switch (id) {
        AppThemeId.kronika => 'Kronika',
        AppThemeId.kurczaki => 'Kurczaki',
        AppThemeId.lagotto => 'Lagotto',
      };

  static String blurbOf(AppThemeId id) => switch (id) {
        AppThemeId.kronika => 'karmazyn i pergamin',
        AppThemeId.kurczaki => 'słoma, jajka, grzebień',
        AppThemeId.lagotto => 'loki, trufle, dębowy las',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.rpg;
    final selected = ref.watch(appThemeProvider);
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OrnamentedLabel(
                'Wygląd',
                style: TextStyle(
                  fontFamily: t.fontDisplay,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                  color: t.crimson,
                ),
              ),
              Text(
                'Zapamiętany na tym urządzeniu',
                style: TextStyle(
                  fontFamily: t.fontBody,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: t.traitNameInk,
                ),
              ),
              const SizedBox(height: 14),
              // Two tiles a row: three abreast leaves each preview too narrow
              // for its band label on a phone.
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = (constraints.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final id in AppThemeId.values)
                        SizedBox(
                          width: width,
                          child: _ThemeTile(
                            id: id,
                            selected: id == selected,
                            onTap: () {
                              ref.read(appThemeProvider.notifier).select(id);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              const _SoundsSwitch(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mutes the mascots' noises (on by default), remembered on this device.
class _SoundsSwitch extends ConsumerWidget {
  const _SoundsSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.rpg;
    final on = ref.watch(themeSoundsEnabledProvider);
    return MergeSemantics(
      child: Row(
        children: [
          Icon(on ? Icons.volume_up : Icons.volume_off, color: t.crimson),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dźwięki',
                  style: TextStyle(
                    fontFamily: t.fontDisplay,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: t.inkHeading,
                  ),
                ),
                Text(
                  'Odgłosy, gdy stukniesz zwierzaka',
                  style: TextStyle(fontFamily: t.fontBody, fontSize: 11, color: t.traitNameInk),
                ),
              ],
            ),
          ),
          Switch(
            key: const Key('theme-sounds'),
            value: on,
            onChanged: ref.read(themeSoundsEnabledProvider.notifier).set,
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({required this.id, required this.selected, required this.onTap});

  final AppThemeId id;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outer = context.rpg;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? outer.crimson : outer.crimsonBorderFaint,
            width: selected ? 3 : 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('theme-option-${id.name}'),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The preview is drawn by the theme it previews.
              Theme(
                data: buildAppTheme(id.theme),
                child: const _Preview(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ThemePickerSheet.nameOf(id),
                            style: TextStyle(
                              fontFamily: id.theme.fontDisplay,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: id.theme.inkHeading,
                            ),
                          ),
                          Text(
                            ThemePickerSheet.blurbOf(id),
                            style: TextStyle(
                              fontFamily: outer.fontBody,
                              fontSize: 11,
                              color: outer.traitNameInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? outer.crimson : null,
                        border: selected
                            ? null
                            : Border.all(color: outer.crimsonBorderStrong, width: 2),
                      ),
                      child: selected
                          ? Icon(Icons.check, size: 14, color: outer.parchmentLight)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A miniature character card on the theme's own scaffold.
class _Preview extends StatelessWidget {
  const _Preview();

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    Widget chip(String name, String value) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(
            border: Border.all(color: t.crimsonBorderStrong),
            borderRadius: BorderRadius.circular(t.cardRadius > 8 ? 999 : 6),
          ),
          child: Text(
            '$name $value',
            style: TextStyle(fontFamily: t.fontBody, fontSize: 8, color: t.crimson),
          ),
        );
    return ExcludeSemantics(
      child: ColoredBox(
        color: t.bgDark,
        child: ThemeBackdrop(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: t.crimson, width: 2),
                borderRadius: BorderRadius.circular(t.cardRadius > 8 ? 12 : 4),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(gradient: t.bandGradient),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Center(
                      child: t.decor.ornamentedLabel(
                        context,
                        'KARTA POSTACI',
                        TextStyle(
                          fontFamily: t.fontDisplay,
                          fontSize: 7,
                          letterSpacing: 2,
                          color: t.bandLabelColor,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(gradient: t.cardGradient),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        Text(
                          'Zosia',
                          style: TextStyle(
                            fontFamily: t.fontDisplay,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: t.inkHeading,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const OrnamentDivider(width: 60),
                        const SizedBox(height: 6),
                        Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: t.crimsonFaint,
                            border: Border.all(color: t.crimsonBorder),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: 0.68,
                            child: DecoratedBox(
                              decoration: BoxDecoration(gradient: t.xpGradient),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          children: [chip('Siła', '4'), chip('Odwaga', '3')],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
