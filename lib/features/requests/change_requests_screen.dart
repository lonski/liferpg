import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/change_request.dart';
import '../../providers/auth_providers.dart';
import '../../providers/change_request_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';
import 'change_request_form.dart';

String _signed(num v) => v > 0 ? '+$v' : '$v';

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

  Future<void> _editThenAccept(ChangeRequest request, String adminUid) async {
    var edited = request.changes;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: bgDark,
        title: const Text('Edytuj prośbę',
            style: TextStyle(color: parchmentLight)),
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
            child: const Text('Anuluj'),
          ),
          TextButton(
            key: const Key('confirm-edit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Zaakceptuj'),
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

  Widget _filterChip(ChangeRequestStatus status, String label) => FilterChip(
        key: Key('filter-${status.wire}'),
        label: Text(label),
        selected: _filter == status,
        onSelected: (_) => setState(() => _filter = status),
      );

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
                                  adminUid: adminUid,
                                  onAccept: () => _decide(
                                    () => ref
                                        .read(changeRequestRepositoryProvider)
                                        .accept(request, adminUid: adminUid),
                                    'Prośba zaakceptowana',
                                  ),
                                  onReject: () => _decide(
                                    () => ref
                                        .read(changeRequestRepositoryProvider)
                                        .reject(request, adminUid: adminUid),
                                    'Prośba odrzucona',
                                  ),
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
    required this.adminUid,
    required this.onAccept,
    required this.onReject,
    required this.onEdit,
  });

  final ChangeRequest request;
  final String adminUid;
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
