import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../models/character.dart';
import '../../providers/achievement_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';
import 'achievement_badge.dart';
import 'achievement_detail_screen.dart';
import 'achievement_widgets.dart';
import 'award_achievement_screen.dart';

/// Every badge of one character, newest first.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key, required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(charactersProvider).value == null;
    final character = ref.watch(characterByIdProvider(characterId));
    final isAdmin = ref.watch(appUserProvider).value?.admin ?? false;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: achievementAppBar(
        character == null ? 'Odznaki' : 'Odznaki · ${character.name}',
        actions: [
          if (isAdmin && character != null)
            IconButton(
              key: const Key('achievement-award'),
              tooltip: 'Przyznaj odznakę',
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AwardAchievementScreen(character: character),
                ),
              ),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : character == null
              ? const Center(
                  child: Text(
                    'Postać już nie istnieje',
                    style: TextStyle(fontFamily: fontBody, color: parchmentLight),
                  ),
                )
              : _Gallery(character: character),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.character});

  final Character character;

  @override
  Widget build(BuildContext context) {
    final all = character.achievements;
    final counts = {
      for (final t in AchievementTier.values)
        t: all.where((a) => a.tier == t).length,
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            color: crimsonDeep,
            border: Border.all(color: goldBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(
                '${all.length}',
                style: const TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 26,
                  color: badgeGoldLight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  badgeCountLabel(all.length),
                  style: const TextStyle(
                    fontFamily: fontBody,
                    fontStyle: FontStyle.italic,
                    color: parchmentMuted,
                  ),
                ),
              ),
              for (final t in AchievementTier.values)
                if (counts[t]! > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 10),
                    child: Tooltip(
                      message: tierLabel(t),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AchievementBadge(
                            tier: t,
                            emblem: AchievementEmblem.star,
                            size: 16,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${counts[t]}',
                            style: const TextStyle(
                              fontFamily: fontBody,
                              fontWeight: FontWeight.w700,
                              color: parchmentLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (all.isEmpty)
          const Center(
            child: Text(
              'Brak odznak',
              style: TextStyle(
                fontFamily: fontBody,
                fontStyle: FontStyle.italic,
                color: parchmentMuted,
              ),
            ),
          ),
        // A Wrap of fixed-width tiles rather than a GridView: tiles grow to
        // their content, so long titles at large text scales never overflow
        // a fixed aspect ratio.
        LayoutBuilder(
          builder: (context, constraints) {
            final width = (constraints.maxWidth - 20) / 3;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final a in all)
                  SizedBox(
                    width: width,
                    child: _Tile(characterId: character.id, achievement: a),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.characterId, required this.achievement});

  final String characterId;
  final Achievement achievement;

  @override
  Widget build(BuildContext context) => Material(
        key: Key('gallery-tile-${achievement.id}'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: crimsonBorderStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(gradient: cardGradient),
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AchievementDetailScreen(
                characterId: characterId,
                achievementId: achievement.id,
              ),
            )),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
              child: Column(
                children: [
                  AchievementBadge.of(achievement, size: 64),
                  const SizedBox(height: 4),
                  Text(
                    achievement.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 12,
                      height: 1.15,
                      color: inkHeading,
                    ),
                  ),
                  Text(
                    formatShortPolishDate(achievement.date),
                    style: const TextStyle(
                      fontFamily: fontBody,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: crimson,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
