import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/character.dart';
import '../../models/quest.dart';
import '../../providers/auth_providers.dart';
import '../../providers/character_providers.dart';
import '../../providers/quest_notification_providers.dart';
import '../../providers/quest_providers.dart';
import '../../theme/app_theme.dart';
import 'quest_card.dart';

/// The target of a shared quest's `https://liferpg.lonski.pl/quest/<id>`
/// link -- the same [QuestCard] used on the board/mine/log tabs, offering
/// whichever of those tabs' actions apply to this quest's status and the
/// signed-in viewer's own characters (see `main.dart`'s deep-link wiring).
class QuestDetailScreen extends ConsumerStatefulWidget {
  const QuestDetailScreen({super.key, required this.questId});

  final String questId;

  @override
  ConsumerState<QuestDetailScreen> createState() => _QuestDetailScreenState();
}

class _QuestDetailScreenState extends ConsumerState<QuestDetailScreen> {
  List<Character> _ownCharacters() {
    final user = ref.read(appUserProvider).value;
    final feed = ref.read(charactersProvider).value;
    if (user == null || feed == null) return const [];
    final email = user.email.toLowerCase();
    return [
      for (final c in feed.characters)
        if (c.email.toLowerCase() == email) c,
    ];
  }

  Future<Character?> _pickCharacter(List<Character> characters) async {
    if (characters.length == 1) return characters.first;
    return showDialog<Character>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: parchment,
        title: const Text('Wybierz postać'),
        children: [
          for (final c in characters)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(c),
              child: Text(c.name),
            ),
        ],
      ),
    );
  }

  Future<void> _take(Quest quest) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    final characters = _ownCharacters();
    if (characters.isEmpty) return;
    final character = await _pickCharacter(characters);
    if (character == null) return;
    try {
      await ref.read(questRepositoryProvider).take(
            quest,
            characterId: character.id,
            characterName: character.name,
            email: user.email,
          );
      await _markSelfAssignedSeen(quest.id, user.uid);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  /// Same self-notification suppression as `QuestsScreen._markSelfAssignedSeen`
  /// -- a quest taken from this screen must not tell its taker "przydzielono
  /// Ci zadanie" about their own action either.
  Future<void> _markSelfAssignedSeen(String questId, String uid) async {
    final repo = ref.read(questNotificationRepositoryProvider);
    final baseline = repo.loadNotifiedAssignedIds(uid);
    if (baseline == null) return;
    await repo.saveNotifiedAssignedIds(uid, {...baseline, questId});
  }

  Future<void> _abandon(Quest quest) async {
    try {
      await ref.read(questRepositoryProvider).abandon(quest);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _complete(Quest quest) async {
    final user = ref.read(appUserProvider).value;
    if (user == null) return;
    try {
      await ref.read(questRepositoryProvider).markComplete(
            quest,
            requesterUid: user.uid,
            requesterEmail: user.email,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _withdraw(Quest quest) async {
    try {
      await ref.read(questRepositoryProvider).withdraw(quest);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  List<Widget> _actionsFor(Quest quest, String? uid, List<String> ownCharacterIds) {
    switch (quest.status) {
      case QuestStatus.open:
        return [
          if (ownCharacterIds.isNotEmpty)
            TextButton(
              key: Key('take-quest-${quest.id}'),
              onPressed: () => _take(quest),
              child: const Text('Podejmij'),
            ),
          if (uid != null && quest.posterUid == uid)
            TextButton(
              key: Key('withdraw-quest-${quest.id}'),
              onPressed: () => _withdraw(quest),
              child: const Text('Wycofaj'),
            ),
        ];
      case QuestStatus.assigned:
        if (!ownCharacterIds.contains(quest.assignedToCharacterId)) return const [];
        return [
          TextButton(
            key: Key('complete-quest-${quest.id}'),
            onPressed: () => _complete(quest),
            child: const Text('Ukończ'),
          ),
          TextButton(
            key: Key('abandon-quest-${quest.id}'),
            onPressed: () => _abandon(quest),
            child: const Text('Porzuć'),
          ),
        ];
      case QuestStatus.pendingReview:
      case QuestStatus.completed:
      case QuestStatus.failed:
      case QuestStatus.cancelled:
        return const [];
    }
  }

  Widget? _statusBadge(Quest quest) {
    switch (quest.status) {
      case QuestStatus.pendingReview:
        return const Text('OCZEKUJE NA AKCEPTACJĘ',
            style: TextStyle(fontSize: 10, color: crimson));
      case QuestStatus.completed:
        return const Text(
          'ZAAKCEPTOWANE',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 10,
            letterSpacing: 1,
            color: Color(0xFF3C6E3C),
          ),
        );
      case QuestStatus.failed:
        return const Text(
          'ODRZUCONE',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 10,
            letterSpacing: 1,
            color: Color(0xFF8C3228),
          ),
        );
      case QuestStatus.cancelled:
        return const Text(
          'WYCOFANE',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 10,
            letterSpacing: 1,
            color: parchmentMuted,
          ),
        );
      case QuestStatus.open:
      case QuestStatus.assigned:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keeps charactersProvider's stream subscribed for the lifetime of this
    // screen -- _take() reads its .value via ref.read(), and a StreamProvider
    // nobody ref.watch()es never subscribes to its underlying stream, so
    // .value would stay permanently null (see CLAUDE.md's Riverpod 3 gotcha).
    ref.watch(charactersProvider);
    final uid = ref.watch(appUserProvider).value?.uid;
    final ownCharacterIds = ref.watch(myOwnCharacterIdsProvider);
    final quest = ref.watch(questByIdProvider(widget.questId));
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
                  statusBadge: _statusBadge(quest),
                  actions: _actionsFor(quest, uid, ownCharacterIds),
                ),
              ),
      ),
    );
  }
}
