import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/character_providers.dart';
import '../../theme/app_theme.dart';
import '../character/character_card.dart';
import '../users/user_management_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).value;
    final feed = ref.watch(charactersProvider);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: appBarGradient,
            border: Border(bottom: BorderSide(color: goldBorderFaint)),
          ),
        ),
        title: const Text(
          '⚔  LifeRPG',
          style: TextStyle(
            fontFamily: fontDisplay,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            letterSpacing: 3,
            color: parchmentLight,
          ),
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
            IconButton(
              key: const Key('open-user-management'),
              tooltip: 'Zarządzaj użytkownikami',
              iconSize: 18,
              color: parchmentMuted,
              icon: const Icon(Icons.admin_panel_settings),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const UserManagementScreen(),
                ),
              ),
            ),
          IconButton(
            key: const Key('logout'),
            tooltip: 'Wyloguj',
            iconSize: 18,
            color: parchmentMuted,
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
          const SizedBox(width: 4),
        ],
      ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final c in data.characters)
                  CharacterCard(character: c, canEdit: user?.canEdit ?? false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
