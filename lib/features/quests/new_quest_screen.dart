import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../models/change_request.dart';
import '../../models/quest.dart';
import '../../models/quest_roster_entry.dart';
import '../../providers/auth_providers.dart';
import '../../providers/quest_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

class NewQuestScreen extends ConsumerStatefulWidget {
  const NewQuestScreen({super.key});

  @override
  ConsumerState<NewQuestScreen> createState() => _NewQuestScreenState();
}

class _NewQuestScreenState extends ConsumerState<NewQuestScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _xpController = TextEditingController();
  QuestRosterEntry? _target;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _xpController.dispose();
    super.dispose();
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
  String? _missingRequirement() {
    if (_submitting) return null;
    if (_titleController.text.trim().isEmpty) return 'Podaj tytuł';
    if (int.tryParse(_xpController.text.trim()) == null) {
      return 'Wprowadź nagrodę';
    }
    return null;
  }

  Future<void> _submit(String uid, String email, String name) async {
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
      posterName: name,
      assignedToCharacterId: target?.characterId,
      assignedToCharacterName: target?.characterName,
      assignedToEmail: target?.email,
      status: target == null ? QuestStatus.open : QuestStatus.assigned,
      reward: ChangeSet(currentXp: xp),
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

  Widget _buildSubmitButton(AppUser? user) {
    Widget button = ElevatedButton(
      key: const Key('submit-quest'),
      onPressed: _submitting || user == null || _missingRequirement() != null
          ? null
          : () => _submit(user.uid, user.email, user.name),
      child: Text(
        (_target == null ? 'Wystaw na tablicę' : 'Wystaw zadanie').toUpperCase(),
      ),
    );
    final missing = _missingRequirement();
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
    final user = ref.watch(appUserProvider).value;
    final roster = ref.watch(questRosterProvider).value ?? const <QuestRosterEntry>[];

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
          'Nowy quest',
          style: TextStyle(
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
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _buildSubmitButton(user),
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
