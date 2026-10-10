import 'package:flutter/material.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../models/character.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import 'achievement_badge.dart';
import 'achievement_widgets.dart';

/// The image shared for a badge: action-free, fixed-width (see
/// captureWidgetImage), with the character, medal, story and reward.
class AchievementShareCard extends StatelessWidget {
  const AchievementShareCard({
    super.key,
    required this.character,
    required this.achievement,
  });

  final Character character;
  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final who = [character.name, if (character.clazz != null) character.clazz!]
        .join(' · ');
    return ParchmentFrame(
      band: 'Odznaka',
      gilded: true,
      footerLabel: 'LifeRPG',
      child: Column(
        children: [
          Text(
            who.toUpperCase(),
            style: TextStyle(
              fontFamily: context.rpg.fontDisplay,
              fontSize: 11,
              letterSpacing: 3,
              color: context.rpg.crimson,
            ),
          ),
          const SizedBox(height: 8),
          BadgeGlow(child: AchievementBadge.of(a, size: 128)),
          const SizedBox(height: 8),
          Text(
            a.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: context.rpg.fontDisplay,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: context.rpg.inkHeading,
            ),
          ),
          if (a.event != null)
            Text(
              a.event!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: context.rpg.fontBody,
                fontSize: 15,
                fontStyle: FontStyle.italic,
                color: context.rpg.crimson,
              ),
            ),
          if (a.reason != null) ...[
            const SizedBox(height: 8),
            Text(
              '„${a.reason}”',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: context.rpg.fontBody,
                fontSize: 14,
                height: 1.35,
                color: context.rpg.inkHeading,
              ),
            ),
          ],
          const SizedBox(height: 10),
          const OrnamentDivider(),
          const SizedBox(height: 10),
          RewardChips(reward: a.reward),
          const SizedBox(height: 10),
          Text(
            formatPolishDate(a.date),
            style: TextStyle(
              fontFamily: context.rpg.fontBody,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: context.rpg.crimson,
            ),
          ),
        ],
      ),
    );
  }
}
