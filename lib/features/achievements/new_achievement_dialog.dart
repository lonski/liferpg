import 'package:flutter/material.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../models/character.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import 'achievement_badge.dart';
import 'achievement_widgets.dart';

const TextStyle _button = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 12,
  letterSpacing: 2,
);

/// "Nowa odznaka": shown once per badge to its owner (see
/// AchievementCelebrationHost). Completes when closed by any means.
Future<void> showNewAchievementDialog(
  BuildContext context, {
  required Character character,
  required Achievement achievement,
  required VoidCallback onShare,
}) {
  final a = achievement;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: ParchmentFrame(
          band: 'Nowa odznaka',
          gilded: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BadgeGlow(child: AchievementBadge.of(a, size: 132)),
              const SizedBox(height: 8),
              Text(
                'Odznaka ${tierAdjective(a.tier)}'.toUpperCase(),
                style: const TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 10,
                  letterSpacing: 3,
                  color: crimson,
                ),
              ),
              Text(
                a.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: inkHeading,
                ),
              ),
              if (a.event != null)
                Text(
                  a.event!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: fontBody,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    color: crimson,
                  ),
                ),
              if (rewardParts(a.reward).isNotEmpty) ...[
                const SizedBox(height: 12),
                const LabelledDivider(label: 'Otrzymujesz'),
                const SizedBox(height: 8),
                RewardChips(reward: a.reward),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('new-achievement-share'),
                      onPressed: onShare,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: crimson,
                        side: const BorderSide(color: crimson),
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Text('Udostępnij'.toUpperCase(), style: _button),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const Key('new-achievement-close'),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: crimson,
                        foregroundColor: parchmentLight,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      child: Text('Wspaniale'.toUpperCase(), style: _button),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
