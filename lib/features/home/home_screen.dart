import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/character.dart';
import '../../models/update_info.dart';
import '../../providers/auth_providers.dart';
import '../../providers/change_request_providers.dart';
import '../../providers/character_providers.dart';
import '../../providers/hidden_characters_providers.dart';
import '../../providers/update_providers.dart';
import '../../theme/app_theme.dart';
import '../character/character_card.dart';
import '../quests/quests_screen.dart';
import '../requests/change_requests_screen.dart';
import '../requests/new_change_request_screen.dart';
import '../update/update_dialog.dart';
import '../users/user_management_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  // Awaited rather than fired and forgotten: a failing sign-out used to
  // vanish into an unhandled async error with no feedback at all.
  static Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(authRepositoryProvider).signOut();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Wylogowanie nieudane: $error')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value;
    final user = ref.watch(appUserProvider).value;
    final isAdmin = user?.admin ?? false;
    final feed = ref.watch(charactersProvider);
    // Hiding is an admin-only affordance, so a hidden id must never filter
    // anyone else's roster: a stale id left over from before this user was
    // demoted (this screen's own settings can flip that flag) must not
    // strand them with an invisible, unrecoverable card.
    final hiddenIds = isAdmin ? ref.watch(hiddenCharacterIdsProvider) : const <String>{};
    final pendingCount =
        ref.watch(pendingChangeRequestsProvider).value?.length ?? 0;

    // An admin viewing the whole roster still only posts requests for their
    // own characters, so this counts by email rather than by roster size.
    final ownsACharacter = user != null &&
        (feed.value?.characters ?? const <Character>[]).any(
          (c) => c.email.toLowerCase() == user.email.toLowerCase(),
        );

    // Checked once per app launch (see updateCheckProvider); shows at most
    // once here too, since the provider only transitions loading -> data
    // once per process.
    ref.listen<AsyncValue<UpdateInfo?>>(updateCheckProvider, (previous, next) {
      final info = next.value;
      if (info != null) UpdateDialog.show(context, info);
    });

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: appBarGradient,
            border: Border(bottom: BorderSide(color: goldBorderFaint)),
            boxShadow: [
              BoxShadow(color: cardShadowColor, blurRadius: 12, offset: Offset(0, 2)),
            ],
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚔  LifeRPG',
              style: TextStyle(
                fontFamily: fontDisplay,
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: 3,
                color: parchmentLight,
              ),
            ),
            if (version != null)
              Text(
                version,
                key: const Key('app-version'),
                style: const TextStyle(
                  fontFamily: fontBody,
                  fontSize: 9,
                  color: parchmentFaint,
                ),
              ),
          ],
        ),
        actions: [
          if (feed.value?.isOffline ?? false)
            const Padding(
              padding: EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Dane z pamięci urządzenia',
                child: Icon(Icons.cloud_off, size: 16, color: parchmentFaint),
              ),
            ),
          if (user?.admin ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: goldBorder),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Badge(
                  key: const Key('pending-requests-badge'),
                  backgroundColor: crimson,
                  textColor: parchmentLight,
                  label: Text('$pendingCount'),
                  isLabelVisible: pendingCount > 0,
                  child: IconButton(
                    key: const Key('open-change-requests'),
                    tooltip: 'Prośby o zmiany',
                    iconSize: 18,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    constraints: const BoxConstraints(),
                    color: parchmentMuted,
                    icon: const Icon(Icons.inbox),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ChangeRequestsScreen(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (user?.admin ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: goldBorder),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: IconButton(
                  key: const Key('open-user-management'),
                  tooltip: 'Zarządzaj użytkownikami',
                  iconSize: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  constraints: const BoxConstraints(),
                  color: parchmentMuted,
                  icon: const Icon(Icons.admin_panel_settings),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const UserManagementScreen(),
                    ),
                  ),
                ),
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: goldBorder),
              borderRadius: BorderRadius.circular(3),
            ),
            child: IconButton(
              key: const Key('logout'),
              tooltip: 'Wyloguj',
              iconSize: 18,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              constraints: const BoxConstraints(),
              color: parchmentMuted,
              icon: const Icon(Icons.logout),
              onPressed: () => _signOut(context, ref),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton:
          ownsACharacter ? _QuestFab(key: const Key('quest-fab')) : null,
      body: feed.when(
        loading: () => const Center(child: CircularProgressIndicator(color: gold)),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nie udało się wczytać postaci: $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: parchmentLight),
            ),
          ),
        ),
        data: (data) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                for (final c in data.characters)
                  if (!hiddenIds.contains(c.id))
                    CharacterCard(
                      character: c,
                      canEdit: user?.canEdit ?? false,
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The FAB rotates into a close icon and reveals two labeled mini-FABs
/// above it -- Zadania (the quest board/moje/dziennik screen) and the
/// existing change-request form.
class _QuestFab extends StatefulWidget {
  const _QuestFab({super.key});

  @override
  State<_QuestFab> createState() => _QuestFabState();
}

class _QuestFabState extends State<_QuestFab> {
  bool _open = false;

  void _toggle() => setState(() => _open = !_open);

  void _navigate(BuildContext context, Widget screen) {
    setState(() => _open = false);
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Widget _miniFab({
    required Key key,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: parchmentLight,
                border: Border.all(color: crimson),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 10,
                  letterSpacing: 1,
                  color: inkHeading,
                ),
              ),
            ),
            const SizedBox(width: 10),
            FloatingActionButton.small(
              key: key,
              heroTag: key.toString(),
              backgroundColor: crimsonDeep,
              foregroundColor: parchmentLight,
              shape: const CircleBorder(side: BorderSide(color: goldBorder)),
              onPressed: onPressed,
              child: Icon(icon),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open) ...[
          _miniFab(
            key: const Key('quest-fab-quests'),
            label: 'Zadania',
            icon: Icons.checklist,
            onPressed: () => _navigate(context, const QuestsScreen()),
          ),
          _miniFab(
            key: const Key('quest-fab-change-request'),
            label: 'Prośba o zmianę',
            icon: Icons.edit_note,
            onPressed: () => _navigate(context, const NewChangeRequestScreen()),
          ),
        ],
        FloatingActionButton(
          tooltip: _open ? 'Zamknij' : 'Dodaj',
          backgroundColor: crimson,
          foregroundColor: parchmentLight,
          shape: const CircleBorder(side: BorderSide(color: goldBorder)),
          onPressed: _toggle,
          child: Icon(_open ? Icons.close : Icons.add),
        ),
      ],
    );
  }
}
