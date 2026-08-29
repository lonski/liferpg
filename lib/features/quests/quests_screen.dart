import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/character.dart';
import '../../models/quest.dart';
import '../../providers/auth_providers.dart';
import '../../providers/character_providers.dart';
import '../../providers/quest_notification_providers.dart';
import '../../providers/quest_providers.dart';
import '../../theme/app_theme.dart';
import 'new_quest_screen.dart';
import 'quest_card.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 3, vsync: this);

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

  /// Seeds the quest-notification baseline with a quest this device just
  /// took, so the "Przydzielono Ci zadanie" listener never sees it as newly
  /// appearing and self-notifies the taker about their own action. Only
  /// merges in when a baseline already exists (`null` means the
  /// notification listener hasn't done its first pass yet, which in
  /// practice only happens in the brief window right after app start --
  /// skipping in that narrow case is safer than writing a partial baseline
  /// that would make the next real seeding pass misfire on unrelated
  /// already-assigned quests).
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

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keeps charactersProvider's stream subscribed for the lifetime of this
    // screen -- _take() reads its .value via ref.read(), and a StreamProvider
    // nobody ref.watch()es never subscribes to its underlying stream, so
    // .value would stay permanently null (see CLAUDE.md's Riverpod 3 gotcha).
    ref.watch(charactersProvider);
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
          'Zadania',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 14,
            letterSpacing: 3,
            color: parchmentLight,
          ),
        ),
        actions: [
          IconButton(
            key: const Key('open-new-quest'),
            tooltip: 'Nowy quest',
            icon: const Icon(Icons.add),
            color: parchmentMuted,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const NewQuestScreen()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: parchmentLight,
          unselectedLabelColor: parchmentMuted,
          indicatorColor: gold,
          tabs: const [
            Tab(key: Key('quests-tab-board'), text: 'TABLICA'),
            Tab(key: Key('quests-tab-mine'), text: 'MOJE'),
            Tab(key: Key('quests-tab-log'), text: 'DZIENNIK'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BoardTab(onTake: _take),
          _MineTab(onAbandon: _abandon, onComplete: _complete, onWithdraw: _withdraw),
          const _LogTab(),
        ],
      ),
    );
  }
}

class _BoardTab extends ConsumerWidget {
  const _BoardTab({required this.onTake});

  final Future<void> Function(Quest quest) onTake;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(openQuestsProvider);
    return open.when(
      loading: () => const Center(child: CircularProgressIndicator(color: gold)),
      error: (e, _) => Center(
        child: Text('Nie udało się wczytać zadań: $e',
            style: const TextStyle(color: parchmentMuted)),
      ),
      data: (quests) => quests.isEmpty
          ? const Center(
              child: Text('Brak otwartych zadań',
                  style: TextStyle(color: parchmentMuted)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final quest in quests)
                  QuestCard(
                    key: Key('quest-${quest.id}'),
                    quest: quest,
                    posterOrHolderLine: 'Wystawione przez: ${quest.posterName}',
                    actions: [
                      TextButton(
                        key: Key('take-quest-${quest.id}'),
                        onPressed: () => onTake(quest),
                        child: const Text('Podejmij'),
                      ),
                    ],
                  ),
              ],
            ),
    );
  }
}

class _MineTab extends ConsumerWidget {
  const _MineTab({
    required this.onAbandon,
    required this.onComplete,
    required this.onWithdraw,
  });

  final Future<void> Function(Quest quest) onAbandon;
  final Future<void> Function(Quest quest) onComplete;
  final Future<void> Function(Quest quest) onWithdraw;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = ref.watch(myAssignedQuestsProvider).value ?? const <Quest>[];
    final posted = ref.watch(myPostedQuestsProvider).value ?? const <Quest>[];
    final active = assigned
        .where((q) => q.status == QuestStatus.assigned || q.status == QuestStatus.pendingReview)
        .toList();
    final myOpen = posted.where((q) => q.status == QuestStatus.open).toList();

    if (active.isEmpty && myOpen.isEmpty) {
      return const Center(
        child: Text('Brak własnych zadań', style: TextStyle(color: parchmentMuted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (active.isNotEmpty) ...[
          const _SectionLabel('✦ PRZYPISANE DO MNIE ✦'),
          for (final quest in active)
            QuestCard(
              key: Key('quest-${quest.id}'),
              quest: quest,
              posterOrHolderLine: 'Wystawione przez: ${quest.posterName}',
              statusBadge: quest.status == QuestStatus.pendingReview
                  ? const Text('OCZEKUJE NA AKCEPTACJĘ',
                      style: TextStyle(fontSize: 10, color: crimson))
                  : null,
              actions: quest.status == QuestStatus.assigned
                  ? [
                      TextButton(
                        key: Key('complete-quest-${quest.id}'),
                        onPressed: () => onComplete(quest),
                        child: const Text('Ukończ'),
                      ),
                      TextButton(
                        key: Key('abandon-quest-${quest.id}'),
                        onPressed: () => onAbandon(quest),
                        child: const Text('Porzuć'),
                      ),
                    ]
                  : const [],
            ),
        ],
        if (myOpen.isNotEmpty) ...[
          const _SectionLabel('✦ WYSTAWIONE PRZEZE MNIE ✦'),
          for (final quest in myOpen)
            QuestCard(
              key: Key('quest-${quest.id}'),
              quest: quest,
              posterOrHolderLine: 'Otwarte — nikt nie podjął',
              actions: [
                TextButton(
                  key: Key('withdraw-quest-${quest.id}'),
                  onPressed: () => onWithdraw(quest),
                  child: const Text('Wycofaj'),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: fontDisplay,
            fontSize: 10,
            letterSpacing: 2,
            color: parchmentMuted,
          ),
        ),
      );
}

class _LogTab extends ConsumerWidget {
  const _LogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final log = ref.watch(questLogProvider);
    return log.when(
      loading: () => const Center(child: CircularProgressIndicator(color: gold)),
      error: (e, _) => Center(
        child: Text('Nie udało się wczytać dziennika: $e',
            style: const TextStyle(color: parchmentMuted)),
      ),
      data: (quests) => quests.isEmpty
          ? const Center(
              child: Text('Dziennik jest pusty', style: TextStyle(color: parchmentMuted)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final quest in quests)
                  QuestCard(
                    key: Key('quest-${quest.id}'),
                    quest: quest,
                    posterOrHolderLine:
                        '${quest.posterName} · ${quest.assignedToCharacterName ?? "—"}',
                    statusBadge: _outcomeBadge(quest.status),
                  ),
              ],
            ),
    );
  }

  Widget? _outcomeBadge(QuestStatus status) {
    // The one place this app's palette departs from pure crimson/gold —
    // muted moss-green / muted brick-red so a scan of the log reads status
    // at a glance, per the design spec.
    return switch (status) {
      QuestStatus.completed => const Text(
          'ZAAKCEPTOWANE',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 10,
            letterSpacing: 1,
            color: Color(0xFF3C6E3C),
          ),
        ),
      QuestStatus.failed => const Text(
          'ODRZUCONE',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 10,
            letterSpacing: 1,
            color: Color(0xFF8C3228),
          ),
        ),
      QuestStatus.cancelled => const Text(
          'WYCOFANE',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 10,
            letterSpacing: 1,
            color: parchmentMuted,
          ),
        ),
      _ => null,
    };
  }
}
