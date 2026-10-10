import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/change_request.dart';
import '../../providers/auth_providers.dart';
import '../../providers/change_request_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/dialogs.dart';
import '../../theme/ornaments.dart';
import 'change_request_form.dart';
import 'change_request_formatting.dart';

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
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.rpg.parchment,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.rpg.cardRadius),
          side: BorderSide(color: context.rpg.crimson, width: context.rpg.cardBorderWidth),
        ),
        title: Text(
          'Odrzucić prośbę?'.toUpperCase(),
          style: TextStyle(
            fontFamily: context.rpg.fontDisplay,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: context.rpg.inkHeading,
          ),
        ),
        content: TextField(
          key: const Key('reject-reason'),
          controller: reasonController,
          maxLines: 2,
          style: TextStyle(color: context.rpg.inkHeading),
          decoration: const InputDecoration(
            hintText: 'Powód (opcjonalnie)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: context.rpg.crimson),
            child: Text('Anuluj'.toUpperCase(), style: dialogActionStyle(context)),
          ),
          TextButton(
            key: Key('confirm-reject-${request.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: context.rpg.crimson,
              foregroundColor: context.rpg.parchmentLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
                side: BorderSide(color: context.rpg.goldGlyph),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text('Odrzuć'.toUpperCase(), style: dialogActionStyle(context)),
          ),
        ],
      ),
    );
    // Not disposed here: the dialog route is still animating its exit when
    // showDialog's future completes, and disposing while the TextField that
    // owns this controller is still in the tree throws. It is a short-lived,
    // unattached-to-State controller, so leaving it for GC is fine.
    final reason = reasonController.text.trim();
    if (confirmed != true) return;
    await _decide(
      () => ref.read(changeRequestRepositoryProvider).reject(
            request,
            adminUid: adminUid,
            reason: reason.isEmpty ? null : reason,
          ),
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
        backgroundColor: context.rpg.parchment,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.rpg.cardRadius),
          side: BorderSide(color: context.rpg.crimson, width: context.rpg.cardBorderWidth),
        ),
        title: Text(
          'Edytuj prośbę'.toUpperCase(),
          style: TextStyle(
            fontFamily: context.rpg.fontDisplay,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: context.rpg.inkHeading,
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
            style: TextButton.styleFrom(foregroundColor: context.rpg.crimson),
            child: Text('Anuluj'.toUpperCase(), style: dialogActionStyle(context)),
          ),
          TextButton(
            key: const Key('confirm-edit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: context.rpg.crimson,
              foregroundColor: context.rpg.parchmentLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
                side: BorderSide(color: context.rpg.goldGlyph),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text('Zaakceptuj'.toUpperCase(), style: dialogActionStyle(context)),
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
            color: selected ? context.rpg.crimson : Colors.transparent,
            border: Border.all(color: selected ? context.rpg.goldBorder : context.rpg.goldBorderFaint),
            borderRadius: BorderRadius.circular(3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: context.rpg.fontDisplay,
              fontSize: 9,
              letterSpacing: 1.5,
              color: selected ? context.rpg.parchmentLight : context.rpg.onBgMuted,
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
      backgroundColor: context.rpg.bgDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: context.rpg.parchmentMuted),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: context.rpg.appBarGradient,
            border: Border(bottom: BorderSide(color: context.rpg.goldBorderFaint)),
          ),
        ),
        title: Text(
          'Prośby o zmiany',
          style: TextStyle(
            fontFamily: context.rpg.fontDisplay,
            fontSize: 14,
            letterSpacing: 3,
            color: context.rpg.parchmentLight,
          ),
        ),
      ),
      body: ThemeBackdrop(child: adminUid == null
          ? Center(
              child: CircularProgressIndicator(color: context.rpg.gold),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // No `cancelled` chip: cancellation is the requester's
                      // own business, not something an admin acts on, so it
                      // is deliberately never surfaced in this queue (see
                      // the design spec).
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
                        loading: () => Center(
                          child: CircularProgressIndicator(color: context.rpg.gold),
                        ),
                        error: (e, _) => Center(
                          child: Text(
                            'Nie udało się wczytać próśb: $e',
                            style: TextStyle(color: context.rpg.onBgMuted),
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
                                  onRestore: () => _decide(
                                    () => ref
                                        .read(changeRequestRepositoryProvider)
                                        .restoreToPending(request),
                                    'Prośba przywrócona do oczekujących',
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                ),
              ],
            )),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onReject,
    required this.onEdit,
    required this.onRestore,
  });

  final ChangeRequest request;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final VoidCallback onEdit;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    // Once accepted, appliedChanges is what actually landed on the character
    // -- which can differ from the original ask if an admin edited it before
    // accepting (see _editThenAccept). Falling back to `changes` covers the
    // pending/rejected cases, where appliedChanges is still null.
    final changes = request.appliedChanges ?? request.changes;
    final deltaLines = changeSetLines(changes);

    return Container(
      key: Key('request-${request.id}'),
      decoration: BoxDecoration(
        border: Border.all(color: context.rpg.crimson, width: context.rpg.cardBorderWidth),
        borderRadius: BorderRadius.circular(context.rpg.cardRadius),
        boxShadow: [
          BoxShadow(
            color: context.rpg.cardShadowColor,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(gradient: context.rpg.cardGradient),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: context.rpg.crimsonBorder),
                borderRadius: BorderRadius.circular(context.rpg.innerRadius),
              ),
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    request.characterName,
                    style: TextStyle(
                      fontFamily: context.rpg.fontDisplay,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.rpg.inkHeading,
                    ),
                  ),
                  Text(
                    request.requesterEmail,
                    style: TextStyle(color: context.rpg.traitNameInk),
                  ),
                  if (request.questTitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Zadanie: ${request.questTitle}',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: context.rpg.traitNameInk,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  for (final line in deltaLines)
                    Text(line, style: TextStyle(color: context.rpg.inkHeading)),
                  if (request.reason != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      request.reason!,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: context.rpg.traitNameInk,
                      ),
                    ),
                  ],
                  if (request.createdAt != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      formatTimestamp(request.createdAt!),
                      style: TextStyle(color: context.rpg.traitNameInk, fontSize: 12),
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
                        // An electronics claim has nothing to edit: it is just a date.
                        if (request.changes.electronicsClaim == null)
                          TextButton(
                            key: Key('edit-${request.id}'),
                            onPressed: onEdit,
                            child: const Text('Edytuj'),
                          ),
                      ],
                    ),
                  ],
                  if (request.status == ChangeRequestStatus.rejected) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton(
                          key: Key('restore-${request.id}'),
                          onPressed: onRestore,
                          child: const Text('Przywróć'),
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
