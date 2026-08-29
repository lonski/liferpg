import 'package:flutter/material.dart';

import '../../models/change_request.dart';
import '../../models/quest.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

String _rewardLine(ChangeSet reward) {
  final parts = <String>[
    if (reward.currentXp != null) '+${reward.currentXp} XP',
    for (final t in reward.traits) '${t.name} ${t.value}',
  ];
  return parts.join(' · ');
}

/// The ornamental card shared by the Tablica/Moje/Dziennik tabs. It only
/// renders the frame, title, reward pills, and whatever the caller hands it
/// -- each tab decides its own caption line, actions, and status badge, so
/// this file never needs to know about the take/abandon/withdraw/complete
/// verbs or the outcome-colour rules.
class QuestCard extends StatelessWidget {
  const QuestCard({
    super.key,
    required this.quest,
    this.posterOrHolderLine,
    this.actions = const [],
    this.statusBadge,
  });

  final Quest quest;
  final String? posterOrHolderLine;
  final List<Widget> actions;
  final Widget? statusBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: crimson, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: cardShadowColor, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TopBand(label: '✦ ${_bandLabel(quest.status)} ✦'),
          Container(
            decoration: const BoxDecoration(gradient: cardGradient),
            padding: const EdgeInsets.all(14),
            width: double.infinity,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: crimsonBorder),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  padding: const EdgeInsets.all(10),
                  width: double.infinity,
                  child: Column(
                    children: [
                      Text(
                        quest.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: fontDisplay,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: inkHeading,
                        ),
                      ),
                      if (posterOrHolderLine != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          posterOrHolderLine!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 11,
                            color: traitNameInk,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        _rewardLine(quest.reward),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: inkHeading),
                      ),
                      if (statusBadge != null) ...[
                        const SizedBox(height: 8),
                        statusBadge!,
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: actions,
                        ),
                      ],
                    ],
                  ),
                ),
                const Positioned(top: 0, left: 0, child: CornerOrnament()),
                const Positioned(top: 0, right: 0, child: CornerOrnament(mirrored: true)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _bandLabel(QuestStatus status) => switch (status) {
        QuestStatus.open => 'Na tablicy',
        QuestStatus.assigned => 'W trakcie',
        QuestStatus.pendingReview => 'W trakcie',
        QuestStatus.completed => 'Ukończone',
        QuestStatus.failed => 'Nieudane',
        QuestStatus.cancelled => 'Wycofane',
      };
}
