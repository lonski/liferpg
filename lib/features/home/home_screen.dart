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
import '../../theme/ornaments.dart';
import '../achievements/achievements_section.dart';
import '../character/character_card.dart';
import '../character/electronics_panel.dart';
import '../quests/quests_summary_card.dart';
import '../requests/change_requests_screen.dart';
import '../requests/new_change_request_screen.dart';
import '../theme/theme_picker_sheet.dart';
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
      backgroundColor: context.rpg.bgDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: context.rpg.appBarGradient,
            border: Border(bottom: BorderSide(color: context.rpg.goldBorderFaint)),
            boxShadow: [
              BoxShadow(color: context.rpg.cardShadowColor, blurRadius: 12, offset: Offset(0, 2)),
            ],
          ),
        ),
        title: const _LogoTitle(),
        actions: [
          if (feed.value?.isOffline ?? false)
            Padding(
              padding: EdgeInsets.only(right: 4),
              child: Tooltip(
                message: 'Dane z pamięci urządzenia',
                child: Icon(Icons.cloud_off, size: 16, color: context.rpg.parchmentFaint),
              ),
            ),
          if (user?.admin ?? false)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: context.rpg.goldBorder),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Badge(
                  key: const Key('pending-requests-badge'),
                  backgroundColor: context.rpg.crimson,
                  textColor: context.rpg.parchmentLight,
                  label: Text('$pendingCount'),
                  isLabelVisible: pendingCount > 0,
                  child: IconButton(
                    key: const Key('open-change-requests'),
                    tooltip: 'Prośby o zmiany',
                    iconSize: 18,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    constraints: const BoxConstraints(),
                    color: context.rpg.parchmentMuted,
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
                  border: Border.all(color: context.rpg.goldBorder),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: IconButton(
                  key: const Key('open-user-management'),
                  tooltip: 'Zarządzaj użytkownikami',
                  iconSize: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  constraints: const BoxConstraints(),
                  color: context.rpg.parchmentMuted,
                  icon: const Icon(Icons.admin_panel_settings),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const UserManagementScreen(),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: context.rpg.goldBorder),
                borderRadius: BorderRadius.circular(3),
              ),
              child: IconButton(
                key: const Key('open-theme-picker'),
                tooltip: 'Wygląd',
                iconSize: 18,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                constraints: const BoxConstraints(),
                color: context.rpg.parchmentMuted,
                icon: const Icon(Icons.palette_outlined),
                onPressed: () => showThemePicker(context),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: context.rpg.goldBorder),
              borderRadius: BorderRadius.circular(3),
            ),
            child: IconButton(
              key: const Key('logout'),
              tooltip: 'Wyloguj',
              iconSize: 18,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              constraints: const BoxConstraints(),
              color: context.rpg.parchmentMuted,
              icon: const Icon(Icons.logout),
              onPressed: () => _signOut(context, ref),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: ownsACharacter ? const _ChangeRequestFab() : null,
      body: ThemeBackdrop(child: feed.when(
        loading: () => Center(child: CircularProgressIndicator(color: context.rpg.gold)),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nie udało się wczytać postaci: $error',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.rpg.onBg),
            ),
          ),
        ),
        data: (data) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                const QuestsSummaryCard(),
                for (final c in data.characters)
                  if (!hiddenIds.contains(c.id))
                    CharacterCard(
                      character: c,
                      canEdit: user?.canEdit ?? false,
                      electronics: ElectronicsPanel(character: c),
                      achievements:
                          AchievementsSection.visibleFor(c, isAdmin: isAdmin)
                              ? AchievementsSection(character: c, isAdmin: isAdmin)
                              : null,
                    ),
                const FooterSceneView(FooterScene.home),
              ],
            ),
          ),
        ),
      )),
    );
  }
}

/// Opens the change-request form. The theme may dress it up (Kurczaki: a
/// chick's face with a small `+` badge).
class _ChangeRequestFab extends StatelessWidget {
  const _ChangeRequestFab();

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    final face = t.decor.fabFace(context);
    void open() => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const NewChangeRequestScreen()),
        );
    if (face == null) {
      return FloatingActionButton(
        key: const Key('change-request-fab'),
        tooltip: 'Prośba o zmianę',
        backgroundColor: t.crimson,
        foregroundColor: t.parchmentLight,
        shape: CircleBorder(side: BorderSide(color: t.goldBorder)),
        onPressed: open,
        child: const Icon(Icons.edit_note),
      );
    }
    return FloatingActionButton(
      key: const Key('change-request-fab'),
      tooltip: 'Prośba o zmianę',
      backgroundColor: t.actionFill,
      shape: CircleBorder(side: BorderSide(color: t.inkHeading, width: 3)),
      onPressed: open,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          face,
          Positioned(
            right: -10,
            bottom: -10,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.crimson,
                border: Border.all(color: t.inkHeading, width: 2),
              ),
              child: Icon(Icons.add, size: 16, color: t.parchmentLight),
            ),
          ),
        ],
      ),
    );
  }
}

/// The AppBar logo + running version. Tapping it manually checks for an
/// update, bypassing [updateCheckProvider]'s once-per-process guard (which
/// exists only to keep the automatic launch-time check from repeating).
class _LogoTitle extends ConsumerStatefulWidget {
  const _LogoTitle();

  @override
  ConsumerState<_LogoTitle> createState() => _LogoTitleState();
}

class _LogoTitleState extends ConsumerState<_LogoTitle> {
  bool _checking = false;

  Widget _logo(BuildContext context) {
    final t = context.rpg;
    final mark = t.decor.logoMark(context);
    final style = TextStyle(
      fontFamily: t.fontDisplay,
      fontWeight: FontWeight.w700,
      fontSize: 20,
      letterSpacing: mark == null ? 3 : 1,
      color: t.parchmentLight,
    );
    if (mark == null) return Text('⚔  LifeRPG', style: style);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [mark, const SizedBox(width: 6), Text('LifeRPG', style: style)],
    );
  }

  Future<void> _checkForUpdate() async {
    if (_checking) return;
    setState(() => _checking = true);
    try {
      final repository = await ref.read(updateRepositoryProvider.future);
      final info = await repository.checkForUpdate();
      if (!mounted) return;
      if (info != null) {
        UpdateDialog.show(context, info);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nie znaleziono nowszej wersji')),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = ref.watch(appVersionProvider).value;
    return InkWell(
      key: const Key('app-version-tap'),
      onTap: _checkForUpdate,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shrinks rather than clips when an admin's four AppBar actions
          // leave a narrow phone little room for the title.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _logo(context),
          ),
          if (_checking)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: context.rpg.parchmentFaint,
              ),
            )
          else if (version != null)
            Text(
              version,
              key: const Key('app-version'),
              style: TextStyle(
                fontFamily: context.rpg.fontBody,
                fontSize: 9,
                color: context.rpg.parchmentFaint,
              ),
            ),
        ],
      ),
    );
  }
}
