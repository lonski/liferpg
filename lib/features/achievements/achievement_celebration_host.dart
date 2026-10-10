import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/achievement_notification_providers.dart';
import 'achievement_share.dart';
import 'new_achievement_dialog.dart';

/// Wraps the signed-in home: whenever the celebration queue has a badge,
/// shows its "Nowa odznaka" dialog, one at a time, marking each dismissed
/// only once its dialog closes.
class AchievementCelebrationHost extends ConsumerStatefulWidget {
  const AchievementCelebrationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AchievementCelebrationHost> createState() =>
      _AchievementCelebrationHostState();
}

class _AchievementCelebrationHostState
    extends ConsumerState<AchievementCelebrationHost> {
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNext());
  }

  Future<void> _showNext() async {
    if (_showing || !mounted) return;
    final queue = ref.read(celebrationQueueProvider);
    if (queue.isEmpty) return;
    _showing = true;
    final item = queue.first;
    await showNewAchievementDialog(
      context,
      character: item.character,
      achievement: item.achievement,
      onShare: () =>
          shareAchievement(context, ref, item.character, item.achievement),
    );
    if (!mounted) return;
    ref.read(celebrationQueueProvider.notifier).dismiss(item.achievement.id);
    _showing = false;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNext());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(celebrationQueueProvider, (_, _) => _showNext());
    return widget.child;
  }
}
