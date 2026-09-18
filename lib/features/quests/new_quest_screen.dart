import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../models/change_request.dart';
import '../../models/character.dart';
import '../../models/quest.dart';
import '../../models/quest_roster_entry.dart';
import '../../providers/auth_providers.dart';
import '../../providers/character_providers.dart';
import '../../providers/quest_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import '../requests/trait_change_field.dart';

class NewQuestScreen extends ConsumerStatefulWidget {
  const NewQuestScreen({super.key, this.editing});

  /// When set, this screen edits an already-posted quest in place instead of
  /// creating a new one -- see the class doc comment on [_NewQuestScreenState]
  /// for what that restricts. `null` is the ordinary "post a new quest" mode.
  final Quest? editing;

  @override
  ConsumerState<NewQuestScreen> createState() => _NewQuestScreenState();
}

/// Doubles as the edit form for a quest the signed-in user posted
/// themselves: the poster/target pickers only make sense at creation time
/// (see `firestore.rules`' quest update rule), so edit mode hides both and
/// only ever touches title/description/reward via `QuestRepository.edit`.
class _NewQuestScreenState extends ConsumerState<NewQuestScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _xpController = TextEditingController();
  TraitChange? _rewardTrait;
  QuestRosterEntry? _target;
  String? _selectedPosterCharacterId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) {
      _titleController.text = editing.title;
      _descriptionController.text = editing.description ?? '';
      _xpController.text = editing.reward.currentXp?.toString() ?? '';
      _rewardTrait =
          editing.reward.traits.isEmpty ? null : editing.reward.traits.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  // Mirrors NewChangeRequestScreen's _ownCharacters -- the quest is posted
  // as one of the user's own characters (shown in "Wystawione przez:"), not
  // under the account's own display name.
  List<Character> _ownCharacters(WidgetRef ref, AppUser? user) {
    final feed = ref.watch(charactersProvider).value;
    if (feed == null || user == null) return const [];
    final email = user.email.toLowerCase();
    return [
      for (final c in feed.characters)
        if (c.email.toLowerCase() == email) c,
    ];
  }

  Future<void> _pickTarget(List<QuestRosterEntry> roster) async {
    final picked = await showDialog<QuestRosterEntry?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: parchment,
        title: const Text('Wybierz postać'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('— Tablica (dowolna osoba) —'),
          ),
          for (final entry in roster)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(entry),
              child: Text(entry.characterName),
            ),
        ],
      ),
    );
    setState(() => _target = picked);
  }

  // What the submit button's tooltip explains when tapped while disabled --
  // mirrors NewChangeRequestScreen's `_missingRequirement`/`_buildSubmitButton`
  // pattern: a raw Firestore permission-denied (the create rule requires
  // reward.keys().hasAny(['current_xp', 'traits'])) is worse feedback than a
  // disabled button, and a blank title silently no-op-ing is worse still.
  String? _missingRequirement(Character? selected) {
    if (_submitting) return null;
    if (widget.editing == null && selected == null) return 'Wybierz postać';
    if (_titleController.text.trim().isEmpty) return 'Podaj tytuł';
    if (int.tryParse(_xpController.text.trim()) == null) {
      return 'Wprowadź nagrodę';
    }
    return null;
  }

  ChangeSet _reward(int xp) => ChangeSet(
        currentXp: xp,
        traits: _rewardTrait == null ? const [] : [_rewardTrait!],
      );

  Future<void> _submit(Character selected, String uid, String email) async {
    final title = _titleController.text.trim();
    final xp = int.tryParse(_xpController.text.trim());
    if (title.isEmpty || xp == null) return;
    setState(() => _submitting = true);
    final target = _target;
    final quest = Quest(
      id: '',
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      posterUid: uid,
      posterEmail: email,
      posterName: selected.name,
      assignedToCharacterId: target?.characterId,
      assignedToCharacterName: target?.characterName,
      assignedToEmail: target?.email,
      status: target == null ? QuestStatus.open : QuestStatus.assigned,
      reward: _reward(xp),
    );
    try {
      await ref.read(questRepositoryProvider).create(quest);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Nie udało się wystawić zadania: $error')));
    }
  }

  Future<void> _submitEdit(Quest editing) async {
    final title = _titleController.text.trim();
    final xp = int.tryParse(_xpController.text.trim());
    if (title.isEmpty || xp == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(questRepositoryProvider).edit(
            editing,
            title: title,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            reward: _reward(xp),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Nie udało się zapisać zmian: $error')));
    }
  }

  Widget _buildSubmitButton(AppUser? user, Character? selected) {
    final editing = widget.editing;
    Widget button = ElevatedButton(
      key: const Key('submit-quest'),
      // Same restyle as NewChangeRequestScreen's submit button -- the stock
      // Material surface reads as a foreign widget on the parchment card.
      style: ElevatedButton.styleFrom(
        backgroundColor: crimson,
        foregroundColor: parchmentLight,
        disabledBackgroundColor: crimsonFaint,
        disabledForegroundColor: crimson,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: const BorderSide(color: goldGlyph),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        textStyle: const TextStyle(
          fontFamily: fontDisplay,
          fontSize: 10,
          letterSpacing: 2,
          fontWeight: FontWeight.w700,
        ),
      ),
      onPressed: _submitting ||
              (editing == null && user == null) ||
              _missingRequirement(selected) != null
          ? null
          : () => editing != null
              ? _submitEdit(editing)
              : _submit(selected!, user!.uid, user.email),
      child: Text(
        _submitting
            ? '...'
            : (editing != null
                    ? 'Zapisz zmiany'
                    : (_target == null ? 'Wystaw na tablicę' : 'Wystaw zadanie'))
                .toUpperCase(),
      ),
    );
    final missing = _missingRequirement(selected);
    if (missing == null) return button;
    // A disabled ElevatedButton has no tap recognizer of its own
    // (onPressed is null), so a tap on it falls through to this Tooltip
    // instead of being silently swallowed -- same pattern as
    // NewChangeRequestScreen's submit button.
    return Tooltip(
      message: missing,
      triggerMode: TooltipTriggerMode.tap,
      child: button,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final user = ref.watch(appUserProvider).value;
    // Neither the poster-character nor the target picker applies in edit
    // mode (both are fixed at creation -- see firestore.rules' quest update
    // rule), so their backing data isn't even watched then.
    final roster = editing == null
        ? ref.watch(questRosterProvider).value ?? const <QuestRosterEntry>[]
        : const <QuestRosterEntry>[];
    final characters = editing == null ? _ownCharacters(ref, user) : const <Character>[];
    // With exactly one character the picker is pointless, so it is hidden
    // and that character is used implicitly -- same convention as
    // NewChangeRequestScreen.
    final selected = characters.isEmpty
        ? null
        : characters.firstWhere(
            (c) => c.id == _selectedPosterCharacterId,
            orElse: () => characters.first,
          );

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
        title: Text(
          editing != null ? 'Edytuj zadanie' : 'Nowy quest',
          style: const TextStyle(
            fontFamily: fontDisplay,
            fontSize: 14,
            letterSpacing: 3,
            color: parchmentLight,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: crimson, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: const BoxDecoration(gradient: cardGradient),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (editing == null && characters.length > 1)
                      DropdownButtonFormField<String>(
                        key: const Key('poster-character-picker'),
                        initialValue: selected?.id,
                        items: [
                          for (final c in characters)
                            DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                        ],
                        onChanged: (id) =>
                            setState(() => _selectedPosterCharacterId = id),
                      ),
                    TextField(
                      key: const Key('quest-title'),
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Tytuł'),
                      onChanged: (_) => setState(() {}),
                    ),
                    TextField(
                      key: const Key('quest-description'),
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Opis (opcjonalnie)'),
                      maxLines: 2,
                    ),
                    TextField(
                      key: const Key('quest-reward-xp'),
                      controller: _xpController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Nagroda (XP)'),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    TraitChangeField(
                      initial: _rewardTrait,
                      onChanged: (trait) =>
                          setState(() => _rewardTrait = trait),
                    ),
                    if (editing == null) ...[
                      const SizedBox(height: 12),
                      ListTile(
                        key: const Key('quest-target-picker'),
                        onTap: () => _pickTarget(roster),
                        title: Text(
                          _target?.characterName ?? 'Tablica (dowolna osoba)',
                          style: const TextStyle(color: inkHeading),
                        ),
                        trailing: const Icon(Icons.expand_more, color: crimson),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _buildSubmitButton(user, selected),
                    ),
                    const BottomBand(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
