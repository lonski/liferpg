import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/character.dart';
import '../../models/quest.dart';
import '../../providers/auth_providers.dart';
import '../../providers/character_providers.dart';
import '../../providers/quest_providers.dart';
import '../../theme/app_theme.dart';
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
          const SizedBox.shrink(),
          const SizedBox.shrink(),
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
