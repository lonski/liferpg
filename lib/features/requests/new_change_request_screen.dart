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
      await ref.read(changeRequestRepositoryProvider).create(ChangeRequest(
            id: '',
            characterId: character.id,
            characterName: character.name,
            requesterUid: user.uid,
            requesterEmail: user.email,
            status: ChangeRequestStatus.pending,
            changes: _changes,
            reason: _reason,
          ));
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się wysłać prośby: $error')),
      );
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prośba anulowana')),
      );
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
    final canSubmit = !_submitting &&
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
                        decoration:
                            const BoxDecoration(gradient: cardGradient),
                        padding: const EdgeInsets.fromLTRB(16, 30, 16, 16),
                        child: Stack(
                          children: [
                            Container(
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
                                      onChanged: (id) => setState(
                                          () => _selectedCharacterId = id),
                                    ),
                                  ChangeRequestForm(
                                    onChanged: (changes, reason) =>
                                        setState(() {
                                      _changes = changes;
                                      _reason = reason;
                                    }),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      key: const Key('submit-request'),
                                      // Left as an ElevatedButton (rather than
                                      // the login screen's InkWell) so the
                                      // disabled state stays a real
                                      // `onPressed: null`, but restyled: the
                                      // stock Material surface reads as a
                                      // foreign widget on the parchment card.
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: crimson,
                                        foregroundColor: parchmentLight,
                                        disabledBackgroundColor: crimsonFaint,
                                        disabledForegroundColor: crimson,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          side: const BorderSide(
                                              color: goldGlyph),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        textStyle: const TextStyle(
                                          fontFamily: fontDisplay,
                                          fontSize: 10,
                                          letterSpacing: 2,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      onPressed: canSubmit
                                          ? () => _submit(selected, user)
                                          : null,
                                      child: Text(_submitting
                                          ? '...'
                                          : 'Wyślij prośbę'.toUpperCase()),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Positioned(
                                top: 5, left: 5, child: CornerOrnament()),
                            const Positioned(
                              top: 5,
                              right: 5,
                              child: CornerOrnament(mirrored: true),
                            ),
                          ],
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
                        Expanded(
                          child: Text(r.characterName,
                              style: const TextStyle(color: parchmentMuted)),
                        ),
                        Text(
                          switch (r.status) {
                            ChangeRequestStatus.pending => 'Oczekuje',
                            ChangeRequestStatus.accepted => 'Zaakceptowana',
                            ChangeRequestStatus.rejected => 'Odrzucona',
                            ChangeRequestStatus.cancelled => 'Anulowana',
                          },
                          style: const TextStyle(
                            fontFamily: fontDisplay,
                            fontSize: 9,
                            letterSpacing: 2,
                            color: parchmentFaint,
                          ),
                        ),
                        if (r.status == ChangeRequestStatus.pending)
                          IconButton(
                            key: Key('cancel-request-${r.id}'),
                            tooltip: 'Anuluj',
                            icon: const Icon(Icons.close,
                                size: 16, color: crimson),
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
