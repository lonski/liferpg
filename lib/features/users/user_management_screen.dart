import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
import '../../models/character.dart';
import '../../providers/character_providers.dart';
import '../../providers/hidden_characters_providers.dart';
import '../../providers/user_providers.dart';
import '../../theme/app_theme.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> {
  final Set<String> _pending = {};

  Future<void> _setReadOnly(AppUser user, bool value) async {
    await _updateFlag(user, {'readOnlyOthers': value});
  }

  Future<void> _setAdmin(AppUser user, bool value) async {
    await _updateFlag(user, {'admin': value});
  }

  Future<void> _updateFlag(AppUser user, Map<String, Object?> flags) async {
    setState(() => _pending.add(user.uid));
    try {
      await ref.read(userRepositoryProvider).updateUserFlags(user.uid, flags);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Zapis nieudany: $error')));
    } finally {
      if (mounted) setState(() => _pending.remove(user.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersProvider);
    final characters = ref.watch(charactersProvider).value?.characters ??
        const <Character>[];
    final hiddenIds = ref.watch(hiddenCharacterIdsProvider);

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
          'Użytkownicy',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontSize: 14,
            letterSpacing: 3,
            color: parchmentLight,
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            children: [
              // Independent of the users query below: an admin can still
              // unhide a character while that query is loading or has
              // failed, since the two have nothing to do with each other.
              _HiddenCharactersSection(
                characters: characters,
                hiddenIds: hiddenIds,
                onUnhide: (id) =>
                    ref.read(hiddenCharacterIdsProvider.notifier).unhide(id),
              ),
              Expanded(
                child: users.when(
                  loading: () => const Center(
                      child:
                          CircularProgressIndicator(color: crimsonBright)),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Nie udało się wczytać użytkowników: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: parchmentLight),
                      ),
                    ),
                  ),
                  data: (list) => list.isEmpty
                      ? const Center(
                          child: Text(
                            'Brak użytkowników',
                            style: TextStyle(
                              fontFamily: fontDisplay,
                              fontSize: 12,
                              // Drawn directly on the dark scaffold (bgDark),
                              // not a parchment surface, so it needs a light
                              // ink -- see CLAUDE.md contrast notes. Matches
                              // the error-state text above.
                              color: parchmentLight,
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          separatorBuilder: (context, i) => const Divider(
                              color: crimsonBorderFaint, height: 1),
                          itemBuilder: (context, i) {
                            final user = list[i];
                            return _UserRow(
                              user: user,
                              busy: _pending.contains(user.uid),
                              onAdmin: (v) => _setAdmin(user, v),
                              onReadOnly: (v) => _setReadOnly(user, v),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// The React original stacked the two switch groups on their own row beneath
// the name and email (UserManagement.jsx). Putting them in a ListTile's
// trailing slot instead crowds ~290dp of fixed-width content onto a 360dp
// phone, leaving nothing for the name; this keeps the React layout.
class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.busy,
    required this.onAdmin,
    required this.onReadOnly,
  });

  final AppUser user;
  final bool busy;
  final ValueChanged<bool> onAdmin;
  final ValueChanged<bool> onReadOnly;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.name.isEmpty ? 'Bez nazwy' : user.name,
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: parchmentLight,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              user.email,
              style: const TextStyle(
                fontFamily: fontBody,
                fontSize: 10,
                color: parchmentFaint,
              ),
            ),
            const SizedBox(height: 4),
            if (busy)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: gold),
                ),
              )
            else
              Row(
                children: [
                  Flexible(
                    child: _LabelledSwitch(
                      switchKey: Key('admin-${user.uid}'),
                      label: 'Admin',
                      value: user.admin,
                      onChanged: onAdmin,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: _LabelledSwitch(
                      switchKey: Key('readonly-${user.uid}'),
                      label: 'Tylko do odczytu',
                      value: user.readOnlyOthers,
                      // Admins already see everything, so the flag is
                      // meaningless for them and stays locked.
                      onChanged: user.admin ? null : onReadOnly,
                    ),
                  ),
                ],
              ),
          ],
        ),
      );
}

/// An admin's own on-device hide list, surfaced here so they have somewhere
/// to bring a character back -- CharacterCard only offers the one-way hide
/// action. Renders nothing when nothing is hidden.
class _HiddenCharactersSection extends StatelessWidget {
  const _HiddenCharactersSection({
    required this.characters,
    required this.hiddenIds,
    required this.onUnhide,
  });

  final List<Character> characters;
  final Set<String> hiddenIds;
  final ValueChanged<String> onUnhide;

  @override
  Widget build(BuildContext context) {
    // Intersected against the live roster rather than rendered from ids
    // alone: a character deleted from Firestore while hidden simply stops
    // appearing here. Its id is left sitting in prefs -- harmless (Firestore
    // ids are unique, so it can never collide with a future character) and
    // deliberately not pruned, since that would mean coupling this notifier
    // to charactersProvider for a few stray bytes of local storage.
    final hidden = [
      for (final c in characters)
        if (hiddenIds.contains(c.id)) c,
    ];
    if (hidden.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ukryte postacie',
            style: TextStyle(
              fontFamily: fontDisplay,
              fontSize: 11,
              letterSpacing: 2,
              color: parchmentMuted,
            ),
          ),
          const SizedBox(height: 6),
          // Bounded and independently scrollable: hiding is meant for a
          // large roster, so this list is exactly the one expected to grow
          // past the screen -- it must not push the user list below it into
          // a RenderFlex overflow.
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 160),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final c in hidden)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(c.name,
                              style: const TextStyle(color: parchmentLight)),
                          TextButton(
                            key: Key('unhide-${c.id}'),
                            onPressed: () => onUnhide(c.id),
                            child: const Text('Pokaż'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(color: crimsonBorderFaint, height: 16),
        ],
      ),
    );
  }
}

class _LabelledSwitch extends StatelessWidget {
  const _LabelledSwitch({
    required this.switchKey,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            key: switchKey,
            value: value,
            // Colours come from the app-wide SwitchThemeData in
            // buildAppTheme() -- see the comment there for the on/off/
            // disabled contrast rationale. Do not reintroduce
            // activeThumbColor/activeTrackColor here: setting both to the
            // same colour is exactly the bug that shipped (thumb invisible
            // inside the track).
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: onChanged,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontSize: 9,
                letterSpacing: 2,
                // This row sits directly on the dark scaffold (bgDark), not
                // the parchment surface `crimson` was designed for in the
                // React dialog -- crimson-on-bgDark is ~1.6:1 contrast,
                // effectively invisible. parchmentMuted matches the muted
                // tone used for other controls/icons on this background
                // (e.g. the AppBar iconTheme) and clears WCAG AA.
                color: parchmentMuted,
              ),
            ),
          ),
        ],
      );
}
