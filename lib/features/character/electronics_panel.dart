// lib/features/character/electronics_panel.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/change_request.dart';
import '../../models/character.dart';
import '../../models/electronics_days.dart';
import '../../providers/auth_providers.dart';
import '../../providers/change_request_providers.dart';
import '../../providers/character_providers.dart';
import '../../providers/clock_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/dialogs.dart';
import 'electronics_section.dart';

/// Decides what the electronics section shows for the signed-in viewer and
/// wires its actions: a player's claim is a change request, an admin's is
/// applied at once. Rebuilds every minute so the ring advances and the count
/// rolls over at midnight while the app is open.
class ElectronicsPanel extends ConsumerStatefulWidget {
  const ElectronicsPanel({super.key, required this.character});

  final Character character;

  @override
  ConsumerState<ElectronicsPanel> createState() => _ElectronicsPanelState();
}

class _ElectronicsPanelState extends ConsumerState<ElectronicsPanel>
    with WidgetsBindingObserver {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  /// A resume can cross midnight without the ticker having fired.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  /// The local day right now, read at tap time rather than captured by build.
  int _clockDay() => dayOf(ref.read(clockProvider)());

  /// True (after refreshing the card) when the day is no longer [builtDay], so
  /// a claim never carries a day other than the one the player tapped on.
  bool _dayMoved(int builtDay) {
    if (_clockDay() == builtDay) return false;
    if (mounted) setState(() {});
    return true;
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text('Nie udało się: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    final now = ref.watch(clockProvider)();
    final today = dayOf(now);
    final todayKey = formatDay(today);
    final user = ref.watch(appUserProvider).value;

    bool isTodaysClaim(ChangeRequest r) =>
        r.isPending &&
        r.characterId == c.id &&
        r.changes.electronicsClaim == todayKey;

    final mine = ref.watch(myChangeRequestsProvider).value ?? const [];
    final queue = ref.watch(pendingChangeRequestsProvider).value ?? const [];
    final ownPending = mine.where(isTodaysClaim).firstOrNull;
    final hasPending = ownPending != null || queue.any(isTodaysClaim);

    final available = c.electronics.available(today);
    final state = c.electronics.stateFor(today, hasPendingClaim: hasPending);

    final isAdmin = user?.admin ?? false;
    final isOwner = user != null &&
        user.email.toLowerCase() == c.email.toLowerCase();

    VoidCallback? onClaim;
    if (user != null && isAdmin) {
      onClaim = () async {
        if (_dayMoved(today)) return;
        final ok = await _confirmClaim(
          available,
          'Odbierasz dzień dla postaci ${c.name}. Licznik spadnie od razu, '
              'a dzisiejszy dzień się nie doliczy.',
          'Odbierz',
        );
        if (!ok || !mounted || _dayMoved(today)) return;
        await _run(
          () => ref.read(characterRepositoryProvider).claimElectronicsDay(c.id),
          'Odebrano dzień elektroniki',
        );
      };
    } else if (user != null && isOwner) {
      onClaim = () async {
        if (_dayMoved(today)) return;
        final ok = await _confirmClaim(
          available,
          'Prośba trafi do admina. Po akceptacji licznik spadnie o jeden, '
              'a dzisiejszy dzień się nie doliczy.',
          'Wyślij prośbę',
        );
        if (!ok || !mounted || _dayMoved(today)) return;
        await _run(
          () => ref.read(changeRequestRepositoryProvider).create(ChangeRequest(
                id: '',
                characterId: c.id,
                characterName: c.name,
                requesterUid: user.uid,
                requesterEmail: user.email,
                status: ChangeRequestStatus.pending,
                changes: ChangeSet(electronicsClaim: todayKey),
              )),
          'Wysłano prośbę o odbiór dnia',
        );
      };
    }

    VoidCallback? onCancel;
    if (ownPending != null) {
      onCancel = () async {
        final ok = await showConfirmDialog(
          context,
          title: 'Anulować prośbę?',
          cancelLabel: 'Nie',
          confirmLabel: 'Tak, anuluj',
          confirmKey: const Key('electronics-cancel-confirm'),
        );
        if (!ok || !mounted) return;
        await _run(
          () => ref.read(changeRequestRepositoryProvider).cancel(ownPending),
          'Prośba anulowana',
        );
      };
    }

    return ElectronicsSection(
      available: available,
      state: state,
      dayFraction: dayFraction(now),
      onClaim: onClaim,
      onCancel: onCancel,
    );
  }

  /// The parchment confirm dialog, with the count's before -> after.
  Future<bool> _confirmClaim(int from, String body, String confirmLabel) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: parchment,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: crimson, width: 2),
        ),
        title: Text(
          'Dzień z elektroniką?'.toUpperCase(),
          style: const TextStyle(
            fontFamily: fontDisplay,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            color: inkHeading,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$from', style: _countStyle(inkHeading)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Icon(Icons.arrow_forward, color: crimson, size: 20),
                ),
                Text('${from - 1}', style: _countStyle(crimson)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: const TextStyle(
                fontFamily: fontBody,
                fontSize: 12,
                height: 1.6,
                color: inkDark,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: crimson),
            child: Text('Anuluj'.toUpperCase(), style: dialogActionStyle),
          ),
          TextButton(
            key: const Key('electronics-claim-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: crimson,
              foregroundColor: parchmentLight,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
                side: const BorderSide(color: goldGlyph),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            child: Text(confirmLabel.toUpperCase(), style: dialogActionStyle),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static TextStyle _countStyle(Color color) => TextStyle(
        fontFamily: fontDisplay,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: color,
      );
}
