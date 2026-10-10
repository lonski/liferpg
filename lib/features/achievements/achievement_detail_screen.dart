import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../models/character.dart';
import '../../providers/achievement_providers.dart';
import '../../providers/auth_providers.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/dialogs.dart';
import '../../theme/ornaments.dart';
import 'achievement_badge.dart';
import 'achievement_widgets.dart';
import 'award_achievement_screen.dart';

const TextStyle _metaLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 10,
  letterSpacing: 2,
  color: crimson,
);

const TextStyle _metaValue = TextStyle(
  fontFamily: fontBody,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: inkHeading,
);

class AchievementDetailScreen extends ConsumerWidget {
  const AchievementDetailScreen({
    super.key,
    required this.characterId,
    required this.achievementId,
  });

  final String characterId;
  final String achievementId;

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    Character character,
    Achievement achievement,
  ) async {
    final parts = rewardParts(achievement.reward.negated());
    final ok = await showConfirmDialog(
      context,
      title: 'Usunąć odznakę?',
      message: parts.isEmpty
          ? 'Odznaka nie miała nagrody.'
          : 'Cofnięte zostanie: ${parts.join(', ')}',
      cancelLabel: 'Anuluj',
      confirmLabel: 'Usuń',
      confirmKey: const Key('achievement-revoke-confirm'),
    );
    if (!ok || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(achievementRepositoryProvider)
          .revoke(character.id, achievement.id);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Odznaka usunięta')));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Nie udało się: $error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loading = ref.watch(charactersProvider).value == null;
    final character = ref.watch(characterByIdProvider(characterId));
    final achievement = character?.achievements
        .where((a) => a.id == achievementId)
        .firstOrNull;
    final isAdmin = ref.watch(appUserProvider).value?.admin ?? false;

    return Scaffold(
      backgroundColor: bgDark,
      appBar: achievementAppBar('Odznaka', actions: [
        if (isAdmin && character != null && achievement != null) ...[
          IconButton(
            key: const Key('achievement-edit'),
            tooltip: 'Edytuj',
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => AwardAchievementScreen(
                character: character,
                editing: achievement,
              ),
            )),
          ),
          IconButton(
            key: const Key('achievement-revoke'),
            tooltip: 'Usuń',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _revoke(context, ref, character, achievement),
          ),
        ],
      ]),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : achievement == null
              ? const Center(
                  child: Text(
                    'Ta odznaka już nie istnieje',
                    style: TextStyle(fontFamily: fontBody, color: parchmentLight),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: BadgeGlow(
                        child: AchievementBadge.of(achievement, size: 150),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ParchmentFrame(
                      band: 'Odznaka ${tierAdjective(achievement.tier)}',
                      child: _Body(achievement: achievement),
                    ),
                  ],
                ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          a.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: fontDisplay,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: inkHeading,
          ),
        ),
        if (a.event != null)
          Text(
            a.event!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: fontBody,
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: crimson,
            ),
          ),
        if (a.reason != null) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: crimsonBgFaint,
              border: Border.all(color: crimsonBorderFaint),
              borderRadius: BorderRadius.circular(3),
            ),
            padding: const EdgeInsets.all(10),
            child: Text(
              '„${a.reason}”',
              style: const TextStyle(
                fontFamily: fontBody,
                fontSize: 14,
                height: 1.35,
                color: inkHeading,
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Przyznano'.toUpperCase(), style: _metaLabel),
                  Text(formatPolishDate(a.date), style: _metaValue),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Przyznał'.toUpperCase(), style: _metaLabel),
                  Text(a.awardedByName, style: _metaValue),
                ],
              ),
            ),
          ],
        ),
        if (rewardParts(a.reward).isNotEmpty) ...[
          const SizedBox(height: 14),
          const LabelledDivider(label: 'Nagroda'),
          const SizedBox(height: 10),
          RewardChips(reward: a.reward),
        ],
      ],
    );
  }
}
