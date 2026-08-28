import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/change_request.dart';
import '../../providers/auth_providers.dart';
import '../../providers/change_request_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/dialogs.dart';
import '../../theme/ornaments.dart';
import 'change_request_form.dart';

String _signed(num v) => v > 0 ? '+$v' : '$v';

const TextStyle _dialogAction = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 2,
);

/// Plain interpolation and zero-padding, deliberately — no `intl` dependency.
String _formatTimestamp(DateTime t) {
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${t.year}-${pad(t.month)}-${pad(t.day)} ${pad(t.hour)}:${pad(t.minute)}';
}

class ChangeRequestsScreen extends ConsumerStatefulWidget {
  const ChangeRequestsScreen({super.key});

  @override
  ConsumerState<ChangeRequestsScreen> createState() =>
      _ChangeRequestsScreenState();
}

class _ChangeRequestsScreenState extends ConsumerState<ChangeRequestsScreen> {
  ChangeRequestStatus _filter = ChangeRequestStatus.pending;

  Future<void> _decide(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) return;
      // A ChangeRequestNoLongerPending lands here too: its toString is the
      // Polish "already decided" message, and the stream refreshes the list.
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _confirmAndReject(ChangeRequest request, String adminUid) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Odrzucić prośbę?',
      cancelLabel: 'Anuluj',
      confirmLabel: 'Odrzuć',
      confirmKey: Key('confirm-reject-${request.id}'),
    );
    if (!confirmed) return;
    await _decide(
      () => ref
          .read(changeRequestRepositoryProvider)
          .reject(request, adminUid: adminUid),
      'Prośba odrzucona',
    );
  }

  Future<void> _editThenAccept(ChangeRequest request, String adminUid) async {
    var edited = request.changes;
    final confirmed = await showDialog<bool>(
      context: context,
      // Parchment, not bgDark. ChangeRequestForm is a parchment-card widget:
      // its labels are `crimson` and its inputs inherit the app theme's
      // `inkDark` body colour, both of which are near-invisible on a dark
      // surface (buildAppTheme is a LIGHT ThemeData -- the same trap the
      // user-management scaffold and the switch colours hit before). Putting
      // the dialog on parchment makes those colours correct rather than
      // duplicating a second palette, and it matches how the same form
      // renders inside the requester's card.
      builder: (dialogContext) => AlertDialog(
        backgroundColor: parchment,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: crimson, width: 2),
        ),
        title: Text(
          'Edytuj prośbę'.toUpperCase(),
          style: const TextStyle(
            fontFamily: fontDisplay,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: inkHeading,
          ),
        ),
        content: SingleChildScrollView(
          child: ChangeRequestForm(
            initial: request.changes,
            showReason: false,
            onChanged: (changes, _) => edited = changes,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: crimson),
            child: Text('Anuluj'.toUpperCase(), style: _dialogAction),
          ),
          TextButton(
            key: const Key('confirm-edit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: crimson,
              foregroundColor: parchmentLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
                side: const BorderSide(color: goldGlyph),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text('Zaakceptuj'.toUpperCase(), style: _dialogAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _decide(
      () => ref.read(changeRequestRepositoryProvider).accept(
            request,
            overrides: edited,
            adminUid: adminUid,
          ),
      'Prośba zaakceptowana',
    );
  }

  // Built from Containers rather than Material's FilterChip: the stock chip
  // brings its own light-scheme surface and checkmark, which read as a
  // foreign widget dropped onto the dark scaffold. This mirrors the gold-bordered
  // AppBar action treatment instead, which is how the rest of the app renders a
  // control on a dark surface.
  Widget _filterChip(ChangeRequestStatus status, String label) {
    final selected = _filter == status;
    return Expanded(
      child: GestureDetector(
        key: Key('filter-${status.wire}'),
        onTap: () => setState(() => _filter = status),
        child: Container(
          decoration: BoxDecoration(
            color: selected ? crimson : Colors.transparent,
            border: Border.all(color: selected ? goldBorder : goldBorderFaint),
            borderRadius: BorderRadius.circular(3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontDisplay,
              fontSize: 9,
              letterSpacing: 1.5,
              color: selected ? parchmentLight : parchmentMuted,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminUid = ref.watch(appUserProvider).value?.uid;

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
          'Prośby o zmiany',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 14,
            letterSpacing: 3,
            color: parchmentLight,
          ),
        ),
      ),
      body: adminUid == null
          ? const Center(
              child: CircularProgressIndicator(color: gold),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _filterChip(ChangeRequestStatus.pending, 'Oczekujące'),
                      const SizedBox(width: 8),
                      _filterChip(
                          ChangeRequestStatus.accepted, 'Zaakceptowane'),
                      const SizedBox(width: 8),
                      _filterChip(ChangeRequestStatus.rejected, 'Odrzucone'),
                    ],
                  ),
                ),
                Expanded(
                  child: ref
                      .watch(changeRequestsByStatusProvider(_filter))
                      .when(
                        loading: () => const Center(
                          child: CircularProgressIndicator(color: gold),
                        ),
                        error: (e, _) => Center(
                          child: Text(
                            'Nie udało się wczytać próśb: $e',
                            style: const TextStyle(color: parchmentMuted),
                          ),
                        ),
                        data: (requests) => ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            for (final request in requests)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _RequestCard(
                                  request: request,
                                  onAccept: () => _decide(
                                    () => ref
                                        .read(changeRequestRepositoryProvider)
                                        .accept(request, adminUid: adminUid),
                                    'Prośba zaakceptowana',
                                  ),
                                  onReject: () =>
                                      _confirmAndReject(request, adminUid),
                                  onEdit: () =>
                                      _editThenAccept(request, adminUid),
                                ),
                              ),
                          ],
                        ),
                      ),
                ),
              ],
            ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
    required this.onEdit,
  });

  final ChangeRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final changes = request.changes;
    final deltaLines = <String>[
      if (changes.currentXp != null) 'XP: ${_signed(changes.currentXp!)}',
      if (changes.gold != null) 'Złoto: ${_signed(changes.gold!)}',
      if (changes.goldUsd != null) 'Dolary: ${_signed(changes.goldUsd!)}',
    ];

    return Container(
      key: Key('request-${request.id}'),
      decoration: BoxDecoration(
        border: Border.all(color: crimson, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: cardShadowColor,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(gradient: cardGradient),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: crimsonBorder),
                borderRadius: BorderRadius.circular(2),
              ),
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.characterName,
                    style: const TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: inkHeading,
                    ),
                  ),
                  Text(
                    request.requesterEmail,
                    style: const TextStyle(color: traitNameInk),
                  ),
                  const SizedBox(height: 8),
                  for (final line in deltaLines)
                    Text(line, style: const TextStyle(color: inkHeading)),
                  for (final trait in changes.traits)
                    Text(
                      '${trait.name}: ${trait.value}',
                      style: const TextStyle(color: inkHeading),
                    ),
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
                      _formatTimestamp(request.createdAt!),
                      style: const TextStyle(color: traitNameInk, fontSize: 12),
                    ),
                  ],
                  if (request.isPending) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          key: Key('accept-${request.id}'),
                          onPressed: onAccept,
                          child: const Text('Zaakceptuj'),
                        ),
                        TextButton(
                          key: Key('reject-${request.id}'),
                          onPressed: onReject,
                          child: const Text('Odrzuć'),
                        ),
                        TextButton(
                          key: Key('edit-${request.id}'),
                          onPressed: onEdit,
                          child: const Text('Edytuj'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Positioned(top: 0, left: 0, child: CornerOrnament()),
            const Positioned(
              top: 0,
              right: 0,
              child: CornerOrnament(mirrored: true),
            ),
          ],
        ),
      ),
    );
  }
}
