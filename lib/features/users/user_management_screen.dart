import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_user.dart';
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
    setState(() => _pending.add(user.uid));
    try {
      await ref
          .read(userRepositoryProvider)
          .updateUserFlags(user.uid, {'readOnlyOthers': value});
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
      body: users.when(
        loading: () => const Center(child: CircularProgressIndicator(color: gold)),
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
        data: (list) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (context, i) =>
                  const Divider(color: goldBorderFaint, height: 1),
              itemBuilder: (context, i) {
                final user = list[i];
                final busy = _pending.contains(user.uid);
                return ListTile(
                  title: Text(
                    user.name.isEmpty ? user.email : user.name,
                    style: const TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 13,
                      color: parchmentLight,
                    ),
                  ),
                  subtitle: Text(
                    user.admin ? '${user.email} · admin' : user.email,
                    style: const TextStyle(
                      fontFamily: fontBody,
                      fontSize: 11,
                      color: parchmentFaint,
                    ),
                  ),
                  trailing: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: gold),
                        )
                      : Switch(
                          key: Key('readonly-${user.uid}'),
                          value: user.readOnlyOthers,
                          activeThumbColor: gold,
                          // Admins already see everything, so the flag is
                          // meaningless for them and stays locked.
                          onChanged:
                              user.admin ? null : (v) => _setReadOnly(user, v),
                        ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
