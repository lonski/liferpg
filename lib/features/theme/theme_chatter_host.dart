import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_chatter_providers.dart';
import '../../theme/chatter.dart';

/// Feeds [ThemeChatter] from the providers -- tips from the quest streams,
/// sounds unless switched off -- above the Navigator (MaterialApp.builder),
/// so every screen's mascots, and their bubbles in the Overlay, see it.
class ThemeChatterHost extends ConsumerWidget {
  const ThemeChatterHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(themeSoundPlayerProvider);
    return ThemeChatter(
      tips: ref.watch(themeTipsProvider),
      playSound: ref.watch(themeSoundsEnabledProvider) ? player.play : null,
      child: child,
    );
  }
}
