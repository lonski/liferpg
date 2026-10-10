import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quest.dart';
import '../../providers/quest_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import 'quests_screen.dart';

/// The always-visible entry point into Zadania from the home screen: a
/// compact banner, above the character list, showing how many quests are
/// assigned to the signed-in user's own characters, plus lighter counts for
/// the open board and anything awaiting an admin's review. This is the only
/// way to reach [QuestsScreen] now -- the FAB is change-request-only.
class QuestsSummaryCard extends ConsumerWidget {
  const QuestsSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned =
        ref.watch(myAssignedQuestsProvider).value ?? const <Quest>[];
    final open = ref.watch(openQuestsProvider).value ?? const <Quest>[];

    final assignedCount =
        assigned.where((q) => q.status == QuestStatus.assigned).length;
    final pendingReviewCount =
        assigned.where((q) => q.status == QuestStatus.pendingReview).length;
    final openCount = open.length;
    final hasAssigned = assignedCount > 0;

    final countEgg =
        hasAssigned ? context.rpg.decor.countEgg(context, assignedCount) : null;
    return Perched(
      spot: PerchSpot.questsSummary,
      child: InkWell(
      key: const Key('quests-summary-card'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const QuestsScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.rpg.cardRadius),
          boxShadow: context.rpg.cardShadows(blur: 18, offset: const Offset(0, 4)),
        ),
        foregroundDecoration: BoxDecoration(
          border: Border.all(
            color: hasAssigned ? context.rpg.crimson : context.rpg.goldBorderFaint,
            width: hasAssigned ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(context.rpg.cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stitched(
              child: Container(
                decoration: BoxDecoration(gradient: context.rpg.bandGradient),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    if (countEgg != null)
                      countEgg
                    else
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hasAssigned ? context.rpg.crimsonBright : context.rpg.crimsonBorderStrong,
                        border: Border.all(
                          color: hasAssigned ? context.rpg.gold : context.rpg.goldBorderFaint,
                          width: hasAssigned ? 2 : 1.5,
                        ),
                        boxShadow: hasAssigned
                            ? [BoxShadow(color: context.rpg.goldGlyph, blurRadius: 8)]
                            : null,
                      ),
                      child: hasAssigned
                          ? Text(
                              '$assignedCount',
                              style: TextStyle(
                                fontFamily: context.rpg.fontDisplay,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                                color: context.rpg.parchmentLight,
                              ),
                            )
                          : Icon(Icons.check, size: 16, color: context.rpg.parchmentSoft),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hasAssigned
                                ? 'ZADANIA DO WYKONANIA'
                                : 'BRAK PRZYPISANYCH ZADAŃ',
                            style: TextStyle(
                              fontFamily: context.rpg.fontDisplay,
                              fontWeight: FontWeight.w700,
                              fontSize: hasAssigned ? 12.5 : 12,
                              letterSpacing: 1,
                              color: hasAssigned ? context.rpg.parchmentLight : context.rpg.bandLabelColor,
                            ),
                          ),
                          Text(
                            hasAssigned ? 'Przypisane do Ciebie' : 'Wszystko zrobione',
                            style: TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 9,
                              color: hasAssigned ? context.rpg.parchmentSoft : context.rpg.parchmentFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      color: hasAssigned ? context.rpg.gold : context.rpg.goldGlyph,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(gradient: context.rpg.cardGradient),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Expanded(
                    child: _Stat(
                      icon: Icons.flag_outlined,
                      value: openCount,
                      label: 'na tablicy',
                    ),
                  ),
                  Container(width: 1, height: 22, color: context.rpg.crimsonBorderFaint),
                  Expanded(
                    child: _Stat(
                      icon: Icons.hourglass_bottom,
                      value: pendingReviewCount,
                      label: 'oczekuje',
                    ),
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

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 13, color: context.rpg.crimson),
        const SizedBox(width: 6),
        Text(
          '$value',
          style: TextStyle(
            fontFamily: context.rpg.fontDisplay,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: context.rpg.inkHeading,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontStyle: FontStyle.italic,
            fontSize: 9.5,
            color: context.rpg.traitNameInk,
          ),
        ),
      ],
    );
  }
}
