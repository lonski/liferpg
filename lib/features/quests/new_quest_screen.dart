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

  /// Only toggleable at creation (firestore.rules only ever grants an
  /// admin-authored quest `isDaily: true`), so this seeds from `editing` but
  /// the toggle itself is hidden in edit mode -- see [_isDaily]'s use below.
  late bool _isDaily = widget.editing?.isDaily ?? false;

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

  /// [required] omits the "— Tablica —" option (a daily quest always has a
  /// target) and, since dismissing the dialog then returns null the same way
  /// picking "Tablica" would on a normal quest, a dismissal in that mode
  /// leaves `_target` untouched rather than clearing an already-made pick.
  Future<void> _pickTarget(List<QuestRosterEntry> roster, {required bool required}) async {
    final picked = await showDialog<QuestRosterEntry?>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: parchment,
        title: const Text('Wybierz postać'),
        children: [
          if (!required)
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
    if (required && picked == null) return;
    setState(() => _target = picked);
  }

  // What the submit button's tooltip explains when tapped while disabled --
  // mirrors NewChangeRequestScreen's `_missingRequirement`/`_buildSubmitButton`
  // pattern: a raw Firestore permission-denied (the create rule requires
  // reward.keys().hasAny(['current_xp', 'traits'])) is worse feedback than a
  // disabled button, and a blank title silently no-op-ing is worse still.
  String? _missingRequirement(Character? selected) {
    if (_submitting) return null;
    if (widget.editing == null) {
      if (_isDaily) {
        if (_target == null) return 'Wybierz osobę';
      } else if (selected == null) {
        return 'Wybierz postać';
      }
    }
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
      final description = _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim();
      final repo = ref.read(questRepositoryProvider);
      // A daily quest is never `open` (edit()'s status guard), and its edit
      // is an admin action rather than the poster-while-open path -- see
      // QuestRepository.editDaily.
      if (editing.isDaily) {
        await repo.editDaily(editing, title: title, description: description, reward: _reward(xp));
      } else {
        await repo.edit(editing, title: title, description: description, reward: _reward(xp));
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Nie udało się zapisać zmian: $error')));
    }
  }

  /// The admin-only daily-quest creation path: the poster identity is the
  /// admin's own account (shown as "Przypisane przez: `<name>`"), not one of
  /// their characters -- an admin managing family chores shouldn't need to
  /// own a character of their own, unlike posting an ordinary quest.
  Future<void> _submitDaily(AppUser user) async {
    final title = _titleController.text.trim();
    final xp = int.tryParse(_xpController.text.trim());
    final target = _target;
    if (title.isEmpty || xp == null || target == null) return;
    setState(() => _submitting = true);
    final quest = Quest(
      id: '',
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      posterUid: user.uid,
      posterEmail: user.email,
      posterName: user.name,
      assignedToCharacterId: target.characterId,
      assignedToCharacterName: target.characterName,
      assignedToEmail: target.email,
      status: QuestStatus.assigned,
      reward: _reward(xp),
      isDaily: true,
    );
    try {
      await ref.read(questRepositoryProvider).create(quest);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Nie udało się przypisać zadania: $error')));
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
              : (_isDaily ? _submitDaily(user!) : _submit(selected!, user!.uid, user.email)),
      child: Text(
        _submitting
            ? '...'
            : (editing != null
                    ? 'Zapisz zmiany'
                    : (_isDaily
                        ? 'Przypisz zadanie codzienne'
                        : (_target == null ? 'Wystaw na tablicę' : 'Wystaw zadanie')))
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
          editing != null
              ? 'Edytuj zadanie'
              : (_isDaily ? 'Nowe zadanie codzienne' : 'Nowy quest'),
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
                    // Only an admin may post a daily quest (firestore.rules),
                    // and only at creation -- isDaily is fixed afterwards,
                    // same as the poster/target pickers below.
                    if (editing == null && (user?.admin ?? false)) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Zadanie codzienne', style: TextStyle(color: inkHeading)),
                          Switch(
                            key: const Key('quest-daily-toggle'),
                            value: _isDaily,
                            onChanged: (v) => setState(() => _isDaily = v),
                          ),
                        ],
                      ),
                      if (_isDaily)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Zadania codzienne są zawsze przypisane do jednej osoby — nie trafiają na tablicę i odnawiają się co dzień.',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: traitNameInk,
                            ),
                          ),
                        ),
                    ],
                    if (editing == null && !_isDaily && characters.length > 1)
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
                        onTap: () => _pickTarget(roster, required: _isDaily),
                        title: Text(
                          _target?.characterName ??
                              (_isDaily ? 'Wybierz osobę' : 'Tablica (dowolna osoba)'),
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
