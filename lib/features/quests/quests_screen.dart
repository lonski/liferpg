import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/character.dart';
import '../../models/quest.dart';
import '../../providers/auth_providers.dart';
import '../../providers/character_providers.dart';
import '../../providers/quest_notification_providers.dart';
import '../../providers/quest_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/dialogs.dart';
import 'new_quest_screen.dart';
import 'quest_card.dart';
import 'quest_share.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController =
      TabController(length: 4, vsync: this);

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
    final confirmed = await showConfirmDialog(
      context,
      title: 'Podjąć zadanie?',
      cancelLabel: 'Nie',
      confirmLabel: 'Tak, podejmij',
      confirmKey: Key('confirm-take-${quest.id}'),
    );
    if (!confirmed || !mounted) return;
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
    final confirmed = await showConfirmDialog(
      context,
      title: 'Porzucić zadanie?',
      cancelLabel: 'Nie',
      confirmLabel: 'Tak, porzuć',
      confirmKey: Key('confirm-abandon-${quest.id}'),
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(questRepositoryProvider).abandon(quest);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _complete(Quest quest) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Zgłosić ukończenie?',
      cancelLabel: 'Nie',
      confirmLabel: 'Tak, ukończ',
      confirmKey: Key('confirm-complete-${quest.id}'),
    );
    if (!confirmed || !mounted) return;
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
    final confirmed = await showConfirmDialog(
      context,
      title: 'Wycofać zadanie?',
      cancelLabel: 'Nie',
      confirmLabel: 'Tak, wycofaj',
      confirmKey: Key('confirm-withdraw-${quest.id}'),
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(questRepositoryProvider).withdraw(quest);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _edit(Quest quest) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NewQuestScreen(editing: quest),
        ),
      );

  Future<void> _deactivateDaily(Quest quest) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Zakończyć zadanie codzienne?',
      cancelLabel: 'Nie',
      confirmLabel: 'Tak, zakończ',
      confirmKey: Key('confirm-deactivate-${quest.id}'),
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(questRepositoryProvider).cancelDaily(quest);
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
          // Fixed (fill) tabs clipped "CODZIENNE" once a 4th tab joined the
          // original 3 -- scrollable sizes each tab to its own text instead
          // of dividing the AppBar width evenly, so nothing is ever cut off
          // regardless of screen width or the user's text-scale setting.
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelPadding: const EdgeInsets.symmetric(horizontal: 14),
          labelColor: parchmentLight,
          unselectedLabelColor: parchmentMuted,
          indicatorColor: gold,
          tabs: const [
            Tab(key: Key('quests-tab-board'), text: 'TABLICA'),
            Tab(key: Key('quests-tab-mine'), text: 'MOJE'),
            Tab(key: Key('quests-tab-daily'), text: 'CODZIENNE'),
            Tab(key: Key('quests-tab-log'), text: 'DZIENNIK'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BoardTab(onTake: _take),
          _MineTab(
            onAbandon: _abandon,
            onComplete: _complete,
            onWithdraw: _withdraw,
            onEdit: _edit,
          ),
          _DailyTab(
            onComplete: _complete,
            onEdit: _edit,
            onDeactivate: _deactivateDaily,
          ),
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
                      QuestActionButton(
                        key: Key('take-quest-${quest.id}'),
                        icon: Icons.back_hand,
                        tooltip: 'Podejmij',
                        onPressed: () => onTake(quest),
                      ),
                    ],
                    onShare: () => shareQuest(context, ref, quest),
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
    required this.onEdit,
  });

  final Future<void> Function(Quest quest) onAbandon;
  final Future<void> Function(Quest quest) onComplete;
  final Future<void> Function(Quest quest) onWithdraw;
  final Future<void> Function(Quest quest) onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assigned = ref.watch(myAssignedQuestsProvider).value ?? const <Quest>[];
    final posted = ref.watch(myPostedQuestsProvider).value ?? const <Quest>[];
    // Daily quests live only on the CODZIENNE tab -- their actions
    // (Ukończ-once-per-day, no Porzuć) don't fit this tab's semantics.
    final active = assigned
        .where((q) =>
            !q.isDaily &&
            (q.status == QuestStatus.assigned || q.status == QuestStatus.pendingReview))
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
                      style: TextStyle(fontSize: 12, color: crimson))
                  : null,
              actions: quest.status == QuestStatus.assigned
                  ? [
                      QuestActionButton(
                        key: Key('complete-quest-${quest.id}'),
                        icon: Icons.check_circle,
                        tooltip: 'Ukończ',
                        onPressed: () => onComplete(quest),
                      ),
                      QuestActionButton(
                        key: Key('abandon-quest-${quest.id}'),
                        icon: Icons.undo,
                        tooltip: 'Porzuć',
                        onPressed: () => onAbandon(quest),
                      ),
                    ]
                  : const [],
              onShare: () => shareQuest(context, ref, quest),
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
                QuestActionButton(
                  key: Key('edit-quest-${quest.id}'),
                  icon: Icons.edit,
                  tooltip: 'Edytuj',
                  onPressed: () => onEdit(quest),
                ),
                QuestActionButton(
                  key: Key('withdraw-quest-${quest.id}'),
                  icon: Icons.remove_circle_outline,
                  tooltip: 'Wycofaj',
                  onPressed: () => onWithdraw(quest),
                ),
              ],
              onShare: () => shareQuest(context, ref, quest),
            ),
        ],
      ],
    );
  }
}

// Outcome-style status colours, shared with _LogTab's badges below -- a
// deliberate departure from pure crimson/gold so "due" vs "done" reads at a
// glance, per the design spec.
const Color _dueColor = crimson;
const Color _doneColor = Color(0xFF3C6E3C);

class _DailyTab extends ConsumerWidget {
  const _DailyTab({
    required this.onComplete,
    required this.onEdit,
    required this.onDeactivate,
  });

  final Future<void> Function(Quest quest) onComplete;
  final Future<void> Function(Quest quest) onEdit;
  final Future<void> Function(Quest quest) onDeactivate;

  Widget? _dueBadge(Quest quest) {
    if (quest.status == QuestStatus.pendingReview) {
      return const Text('OCZEKUJE NA AKCEPTACJĘ',
          style: TextStyle(fontSize: 12, color: crimson));
    }
    return Text(
      quest.isDueToday ? 'DO ZROBIENIA DZIŚ' : '✓ ZROBIONE DZIŚ — WRÓCI JUTRO',
      style: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 11.5,
        letterSpacing: 1,
        color: quest.isDueToday ? _dueColor : _doneColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(appUserProvider).value?.admin ?? false;
    final assigned = ref.watch(myAssignedQuestsProvider).value ?? const <Quest>[];
    // watchAssignedTo filters only by assignedToCharacterId, not status, so a
    // deactivated (cancelled) daily quest -- assignment fields deliberately
    // left in place by cancelDaily -- must be excluded here explicitly, or a
    // retired chore would keep showing as still due.
    final mine = assigned.where((q) => q.isDaily && q.status != QuestStatus.cancelled).toList();
    final managed = admin
        ? (ref.watch(allDailyQuestsProvider).value ?? const <Quest>[])
            .where((q) => q.status != QuestStatus.cancelled)
            .toList()
        : const <Quest>[];

    if (mine.isEmpty && managed.isEmpty) {
      return const Center(
        child: Text('Brak zadań codziennych', style: TextStyle(color: parchmentMuted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (mine.isNotEmpty) ...[
          const _SectionLabel('✦ TWOJE ZADANIA CODZIENNE ✦'),
          for (final quest in mine)
            QuestCard(
              key: Key('quest-${quest.id}'),
              quest: quest,
              posterOrHolderLine: 'Przypisane przez: ${quest.posterName}',
              statusBadge: _dueBadge(quest),
              actions: quest.status == QuestStatus.assigned && quest.isDueToday
                  ? [
                      QuestActionButton(
                        key: Key('complete-quest-${quest.id}'),
                        icon: Icons.check_circle,
                        tooltip: 'Ukończ',
                        onPressed: () => onComplete(quest),
                      ),
                    ]
                  : const [],
              onShare: () => shareQuest(context, ref, quest),
            ),
        ] else if (admin)
          const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text('Nie masz własnych zadań codziennych.',
                textAlign: TextAlign.center,
                style: TextStyle(color: parchmentMuted, fontStyle: FontStyle.italic)),
          ),
        if (admin && managed.isNotEmpty) ...[
          const _SectionLabel('✦ ZARZĄDZANIE (ADMIN) ✦'),
          for (final quest in managed)
            _DailyManageRow(
              key: Key('quest-manage-${quest.id}'),
              quest: quest,
              onEdit: () => onEdit(quest),
              onDeactivate: () => onDeactivate(quest),
            ),
        ],
      ],
    );
  }
}

// Chip/row tokens for _DailyManageRow only -- narrow enough in scope that
// they don't belong in app_theme.dart alongside the broadly-reused palette.
const Color _rowBg = Color(0x0DF5E8D0); // ~5% parchment tint on bgDark
const Color _goldChipBg = Color(0x2EC8860A); // ~18% gold
const Color _doneChipBg = Color(0x333C6E3C); // ~20% of _doneColor

/// A compact admin-only management row for one daily quest -- deliberately
/// flatter and denser than [QuestCard] (no parchment card, no ornaments) so
/// the ZARZĄDZANIE section reads as an admin tool distinct from the
/// player-facing card used everywhere else, per the design mockup.
class _DailyManageRow extends StatelessWidget {
  const _DailyManageRow({
    super.key,
    required this.quest,
    required this.onEdit,
    required this.onDeactivate,
  });

  final Quest quest;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  String get _rewardSummary {
    final r = quest.reward;
    final parts = <String>[
      if (r.currentXp != null) '+${r.currentXp} XP',
      for (final t in r.traits) '${t.name} ${t.value}',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final pending = quest.status == QuestStatus.pendingReview;
    final due = quest.isDueToday;
    final chipLabel = pending ? 'OCZEKUJE' : (due ? 'CZEKA' : 'ZROBIONE');
    final chipColor = pending ? crimson : (due ? gold : _doneColor);
    final chipBg = pending ? crimsonFaint : (due ? _goldChipBg : _doneChipBg);
    final name = quest.assignedToCharacterName ?? '—';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _rowBg,
        border: Border.all(color: goldBorderFaint),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: crimsonDeep,
              border: Border.fromBorderSide(BorderSide(color: gold)),
            ),
            child: Text(
              initial,
              style: const TextStyle(fontFamily: fontDisplay, fontSize: 14, color: parchmentLight),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  quest.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: fontDisplay, fontSize: 14, color: parchmentLight),
                ),
                const SizedBox(height: 2),
                Text(
                  '$name · $_rewardSummary',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: parchmentMuted),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: chipBg, borderRadius: BorderRadius.circular(10)),
            child: Text(
              chipLabel,
              style: TextStyle(
                fontFamily: fontDisplay,
                fontSize: 9.5,
                letterSpacing: 1,
                color: chipColor,
              ),
            ),
          ),
          // Not QuestActionButton -- its icon colour (crimson) is tuned for
          // the parchment QuestCard background, and would read as low
          // contrast on this row's dark background.
          IconButton(
            key: Key('edit-daily-${quest.id}'),
            tooltip: 'Edytuj',
            icon: const Icon(Icons.edit, size: 18),
            color: parchmentMuted,
            visualDensity: VisualDensity.compact,
            onPressed: onEdit,
          ),
          IconButton(
            key: Key('deactivate-daily-${quest.id}'),
            tooltip: 'Zakończ',
            icon: const Icon(Icons.remove_circle_outline, size: 18),
            color: parchmentMuted,
            visualDensity: VisualDensity.compact,
            onPressed: onDeactivate,
          ),
        ],
      ),
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
            fontSize: 12,
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
                    onShare: () => shareQuest(context, ref, quest),
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
            fontSize: 12,
            letterSpacing: 1,
            color: Color(0xFF3C6E3C),
          ),
        ),
      QuestStatus.failed => const Text(
          'ODRZUCONE',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 12,
            letterSpacing: 1,
            color: Color(0xFF8C3228),
          ),
        ),
      QuestStatus.cancelled => const Text(
          'WYCOFANE',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 12,
            letterSpacing: 1,
            color: parchmentMuted,
          ),
        ),
      _ => null,
    };
  }
}
