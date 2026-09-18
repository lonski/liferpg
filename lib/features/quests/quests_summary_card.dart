import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/quest.dart';
import '../../providers/quest_providers.dart';
import '../../theme/app_theme.dart';
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

    return InkWell(
      key: const Key('quests-summary-card'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const QuestsScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: hasAssigned ? crimson : goldBorderFaint,
            width: hasAssigned ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(color: cardShadowColor, blurRadius: 18, offset: Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: const BoxDecoration(gradient: bandGradient),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasAssigned ? crimsonBright : crimsonBorderStrong,
                      border: Border.all(
                        color: hasAssigned ? gold : goldBorderFaint,
                        width: hasAssigned ? 2 : 1.5,
                      ),
                      boxShadow: hasAssigned
                          ? const [BoxShadow(color: goldGlyph, blurRadius: 8)]
                          : null,
                    ),
                    child: hasAssigned
                        ? Text(
                            '$assignedCount',
                            style: const TextStyle(
                              fontFamily: fontDisplay,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: parchmentLight,
                            ),
                          )
                        : const Icon(Icons.check, size: 16, color: parchmentSoft),
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
                            fontFamily: fontDisplay,
                            fontWeight: FontWeight.w700,
                            fontSize: hasAssigned ? 12.5 : 12,
                            letterSpacing: 1,
                            color: hasAssigned ? parchmentLight : bandLabelColor,
                          ),
                        ),
                        Text(
                          hasAssigned ? 'Przypisane do Ciebie' : 'Wszystko zrobione',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 9,
                            color: hasAssigned ? parchmentSoft : parchmentFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: hasAssigned ? gold : goldGlyph,
                    size: 18,
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(gradient: cardGradient),
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
                  Container(width: 1, height: 22, color: crimsonBorderFaint),
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
        Icon(icon, size: 13, color: crimson),
        const SizedBox(width: 6),
        Text(
          '$value',
          style: const TextStyle(
            fontFamily: fontDisplay,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: inkHeading,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontStyle: FontStyle.italic,
            fontSize: 9.5,
            color: traitNameInk,
          ),
        ),
      ],
    );
  }
}
