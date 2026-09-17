import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/quest_providers.dart';
import '../../theme/app_theme.dart';
import 'quest_card.dart';

/// The target of a shared quest's `liferpg://quest/<id>` link -- a
/// read-only render of the same [QuestCard] used on the board/mine/log tabs,
/// reachable only via that link (see `main.dart`'s deep-link wiring).
class QuestDetailScreen extends ConsumerWidget {
  const QuestDetailScreen({super.key, required this.questId});

  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quest = ref.watch(questByIdProvider(questId));
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: parchmentMuted),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: appBarGradient,
            border: Border(bottom: BorderSide(color: goldBorderFaint)),
          ),
        ),
        title: const Text(
          'Zadanie',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 14,
            letterSpacing: 3,
            color: parchmentLight,
          ),
        ),
      ),
      body: quest.when(
        loading: () => const Center(child: CircularProgressIndicator(color: gold)),
        error: (e, _) => Center(
          child: Text('Nie udało się wczytać zadania: $e',
              style: const TextStyle(color: parchmentMuted)),
        ),
        data: (quest) => quest == null
            ? const Center(
                child: Text('Nie znaleziono zadania',
                    style: TextStyle(color: parchmentMuted)),
              )
            : Padding(
                padding: const EdgeInsets.all(16),
                child: QuestCard(
                  key: Key('quest-${quest.id}'),
                  quest: quest,
                  posterOrHolderLine: quest.assignedToCharacterName != null
                      ? '${quest.posterName} · ${quest.assignedToCharacterName}'
                      : 'Wystawione przez: ${quest.posterName}',
                ),
              ),
      ),
    );
  }
}
