import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../models/character.dart';
import '../../models/change_request.dart';
import '../../providers/auth_providers.dart';
import '../../providers/change_request_providers.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/dialogs.dart';
import '../../theme/ornaments.dart';
import 'change_request_form.dart';
import 'change_request_formatting.dart';

const TextStyle _detailSectionLabel = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 10,
  letterSpacing: 2,
  color: crimson,
);

class NewChangeRequestScreen extends ConsumerStatefulWidget {
  const NewChangeRequestScreen({super.key});

  @override
  ConsumerState<NewChangeRequestScreen> createState() =>
      _NewChangeRequestScreenState();
}

class _NewChangeRequestScreenState
    extends ConsumerState<NewChangeRequestScreen> {
  ChangeSet _changes = const ChangeSet();
  String? _reason;
  String? _selectedCharacterId;
  bool _submitting = false;

  // What the submit button's tooltip explains when tapped while disabled --
  // the field validation hints this replaced only ever pointed at one thing
  // at a time, so this keeps that same single-message behaviour.
  String? _missingRequirement(Character? selected, AppUser? user) {
    if (_submitting) return null;
    if (selected == null || user == null) return 'Wybierz postać';
    if (_changes.isEmpty) return 'Wprowadź przynajmniej jedną zmianę';
    if (_reason == null) return 'Podaj powód';
    return null;
  }

  Widget _buildSubmitButton({
    required bool canSubmit,
    required Character? selected,
    required AppUser? user,
  }) {
    Widget button = ElevatedButton(
      key: const Key('submit-request'),
      // Left as an ElevatedButton (rather than the login screen's InkWell)
      // so the disabled state stays a real `onPressed: null`, but restyled:
      // the stock Material surface reads as a foreign widget on the
      // parchment card.
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
      onPressed: canSubmit && selected != null && user != null
          ? () => _submit(selected, user)
          : null,
      child: Text(_submitting ? '...' : 'Wyślij prośbę'.toUpperCase()),
    );
    final missing = _missingRequirement(selected, user);
    if (missing == null) return button;
    // A disabled ElevatedButton has no tap recognizer of its own
    // (onPressed is null), so a tap on it falls through to this Tooltip
    // instead of being silently swallowed.
    return Tooltip(
      message: missing,
      triggerMode: TooltipTriggerMode.tap,
      child: button,
    );
  }

  List<Character> _ownCharacters(WidgetRef ref, AppUser? user) {
    final feed = ref.watch(charactersProvider).value;
    if (feed == null || user == null) return const [];
    final email = user.email.toLowerCase();
    return [
      for (final c in feed.characters)
        if (c.email.toLowerCase() == email) c,
    ];
  }

  Future<void> _submit(Character character, AppUser user) async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(changeRequestRepositoryProvider)
          .create(
            ChangeRequest(
              id: '',
              characterId: character.id,
              characterName: character.name,
              requesterUid: user.uid,
              requesterEmail: user.email,
              status: ChangeRequestStatus.pending,
              changes: _changes,
              reason: _reason,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się wysłać prośby: $error')),
      );
    }
  }

  Future<void> _showDetails(ChangeRequest request) async {
    final askedLines = changeSetLines(request.changes);
    final applied = request.appliedChanges;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: parchment,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: crimson, width: 2),
        ),
        title: Text(
          request.characterName.toUpperCase(),
          style: const TextStyle(
            fontFamily: fontDisplay,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: inkHeading,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                changeRequestStatusLabel(request.status),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: inkHeading,
                ),
              ),
              const SizedBox(height: 8),
              Text('Poproszono o'.toUpperCase(), style: _detailSectionLabel),
              for (final line in askedLines)
                Text(line, style: const TextStyle(color: inkHeading)),
              if (request.reason != null) ...[
                const SizedBox(height: 8),
                Text(
                  request.reason!,
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: traitNameInk,
                  ),
                ),
              ],
              if (request.createdAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Wysłano: ${formatTimestamp(request.createdAt!)}',
                  style: const TextStyle(color: traitNameInk, fontSize: 12),
                ),
              ],
              if (applied != null) ...[
                const SizedBox(height: 12),
                const Divider(color: crimsonBorderFaint, height: 1),
                const SizedBox(height: 12),
                Text('Zastosowano'.toUpperCase(), style: _detailSectionLabel),
                for (final line in changeSetLines(applied))
                  Text(line, style: const TextStyle(color: inkHeading)),
                if (request.decidedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Rozpatrzono: ${formatTimestamp(request.decidedAt!)}',
                    style: const TextStyle(color: traitNameInk, fontSize: 12),
                  ),
                ],
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: TextButton.styleFrom(foregroundColor: crimson),
            child: Text('Zamknij'.toUpperCase(), style: dialogActionStyle),
          ),
        ],
      ),
    );
  }

  Future<void> _cancel(ChangeRequest request) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Anulować prośbę?',
      cancelLabel: 'Nie',
      confirmLabel: 'Tak, anuluj',
      confirmKey: Key('confirm-cancel-${request.id}'),
    );
    if (!confirmed) return;
    try {
      await ref.read(changeRequestRepositoryProvider).cancel(request);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Prośba anulowana')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(appUserProvider).value;
    final characters = _ownCharacters(ref, user);
    // With exactly one character the picker is pointless, so it is hidden and
    // that character is used implicitly.
    final selected = characters.isEmpty
        ? null
        : characters.firstWhere(
            (c) => c.id == _selectedCharacterId,
            orElse: () => characters.first,
          );
    final canSubmit =
        !_submitting &&
        selected != null &&
        user != null &&
        !_changes.isEmpty &&
        _reason != null;
    final myRequests = ref.watch(myChangeRequestsProvider).value ?? const [];

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
          'Prośba o zmianę',
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
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: crimson, width: 2),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: const [
                      BoxShadow(
                        color: dialogShadowColor,
                        blurRadius: 32,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      Container(
                        decoration: const BoxDecoration(gradient: cardGradient),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: crimsonBorder),
                            borderRadius: BorderRadius.circular(2),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              if (characters.length > 1)
                                DropdownButtonFormField<String>(
                                  key: const Key('character-picker'),
                                  initialValue: selected?.id,
                                  items: [
                                    for (final c in characters)
                                      DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      ),
                                  ],
                                  onChanged: (id) =>
                                      setState(() => _selectedCharacterId = id),
                                ),
                              ChangeRequestForm(
                                onChanged: (changes, reason) => setState(() {
                                  _changes = changes;
                                  _reason = reason;
                                }),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: _buildSubmitButton(
                                  canSubmit: canSubmit,
                                  selected: selected,
                                  user: user,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const BottomBand(),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const OrnamentDivider(),
                const SizedBox(height: 12),
                for (final r in myRequests)
                  Padding(
                    key: Key('my-request-${r.id}'),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // The tappable region stops at the name/status pair,
                        // as a sibling of the cancel button rather than its
                        // parent -- nesting a button inside a tappable Row
                        // leaves both taps in the same gesture arena with no
                        // clear winner, so the cancel button silently stops
                        // resolving its own tap.
                        Expanded(
                          child: InkWell(
                            onTap: () => _showDetails(r),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    r.characterName,
                                    style: const TextStyle(
                                      color: parchmentMuted,
                                    ),
                                  ),
                                ),
                                Text(
                                  changeRequestStatusLabel(r.status),
                                  style: const TextStyle(
                                    fontFamily: fontDisplay,
                                    fontSize: 9,
                                    letterSpacing: 2,
                                    // Was parchmentFaint (~3.95:1 against
                                    // bgDark at this size -- fails WCAG AA's
                                    // 4.5:1 floor). parchmentMuted matches
                                    // the name colour and clears 6:1.
                                    color: parchmentMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (r.status == ChangeRequestStatus.pending)
                          IconButton(
                            key: Key('cancel-request-${r.id}'),
                            tooltip: 'Anuluj',
                            icon: const Icon(
                              Icons.close,
                              size: 16,
                              color: crimson,
                            ),
                            onPressed: () => _cancel(r),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
