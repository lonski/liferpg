import 'package:flutter/widgets.dart';

/// What a theme's mascots may draw on when tapped -- tips to drop into a
/// speech bubble and a way to make a sound -- handed down from the app shell
/// so the theme layer needs no providers. Absent (a bare test app), the
/// mascots stay silent and stick to their own noises.
class ThemeChatter extends InheritedWidget {
  const ThemeChatter({
    super.key,
    required this.tips,
    required this.playSound,
    required super.child,
  });

  final List<String> tips;

  /// Plays an asset under `assets/`; null while sounds are switched off.
  final void Function(String asset)? playSound;

  /// Read at tap time: a mascot needn't rebuild when the tips change.
  static ThemeChatter? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ThemeChatter>();

  @override
  bool updateShouldNotify(ThemeChatter old) =>
      tips != old.tips || playSound != old.playSound;
}
