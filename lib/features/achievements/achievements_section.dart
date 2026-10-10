import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/achievement.dart';
import '../../models/character.dart';
import '../../providers/seen_achievements_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import 'achievement_badge.dart';
import 'achievement_detail_screen.dart';
import 'achievements_screen.dart';
import 'award_achievement_screen.dart';

TextStyle _link(BuildContext context) => TextStyle(
  fontFamily: context.rpg.fontDisplay,
  fontSize: 11,
  letterSpacing: 2,
);

/// The "Odznaki" block on a character card: the four newest badges (NOWA on
/// ones this viewer hasn't opened yet) and a link to the gallery, or -- for
/// an admin, on a character with none yet -- a way to award the first.
class AchievementsSection extends ConsumerWidget {
  const AchievementsSection({
    super.key,
    required this.character,
    required this.isAdmin,
  });

  final Character character;
  final bool isAdmin;

  /// Players and readOnlyOthers only see the section once it has something
  /// in it; an admin always does, so the first badge has an entry point.
  static bool visibleFor(Character c, {required bool isAdmin}) =>
      isAdmin || c.achievements.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = character.achievements;
    // Null until this device has a baseline: then nothing reads as new.
    final seen = ref.watch(seenAchievementsProvider);
    void push(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LabelledDivider(
          label: all.isEmpty ? 'Odznaki' : 'Odznaki · ${all.length}',
        ),
        const SizedBox(height: 8),
        if (all.isEmpty) ...[
          Text(
            'Brak odznak',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: context.rpg.fontBody,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: context.rpg.crimson,
            ),
          ),
          TextButton(
            key: const Key('achievements-award'),
            onPressed: () => push(AwardAchievementScreen(character: character)),
            style: TextButton.styleFrom(foregroundColor: context.rpg.crimson),
            child: Text('Przyznaj odznakę'.toUpperCase(), style: _link(context)),
          ),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in all.take(4))
                Expanded(
                  child: _Tile(
                    achievement: a,
                    isNew: seen != null && !seen.contains(a.id),
                    onTap: () => push(AchievementDetailScreen(
                      characterId: character.id,
                      achievementId: a.id,
                    )),
                  ),
                ),
              for (var i = all.length; i < 4; i++)
                const Expanded(child: SizedBox()),
            ],
          ),
          TextButton(
            key: const Key('achievements-all'),
            onPressed: () => push(AchievementsScreen(characterId: character.id)),
            style: TextButton.styleFrom(foregroundColor: context.rpg.crimson),
            child: Text('Wszystkie odznaki ›'.toUpperCase(), style: _link(context)),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.achievement,
    required this.isNew,
    required this.onTap,
  });

  final Achievement achievement;
  final bool isNew;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        key: Key('achievement-tile-${achievement.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AchievementBadge.of(achievement, size: 50),
                  // Kurczaki: the egg sits in a little straw nest.
                  if (context.rpg.decor.badgeNest(context, 56) case final nest?)
                    Positioned(left: -3, right: -3, bottom: -9, child: nest),
                  if (isNew)
                    Positioned(
                      top: -4,
                      right: -10,
                      child: Container(
                        decoration: BoxDecoration(
                          color: context.rpg.gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        child: Text(
                          'Nowa'.toUpperCase(),
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: context.rpg.fontDisplay,
                            fontSize: 8,
                            letterSpacing: 1,
                            color: context.rpg.inkHeading,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: context.rpg.decor.eggBadges ? 10 : 2),
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: context.rpg.fontBody,
                  fontSize: 10,
                  fontStyle: FontStyle.italic,
                  height: 1.15,
                  color: context.rpg.crimson,
                ),
              ),
            ],
          ),
        ),
      );
}
