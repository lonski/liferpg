import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/flutter_local_notifications_change_request_service.dart';
import 'data/plugin_update_installer_service.dart';
import 'data/quest_deep_link.dart';
import 'data/shared_preferences_provider.dart';
import 'features/home/home_screen.dart';
import 'features/login/login_screen.dart';
import 'features/quests/quest_detail_screen.dart';
import 'features/quests/quests_screen.dart';
import 'features/requests/change_requests_screen.dart';
import 'features/requests/new_change_request_screen.dart';
import 'firebase_options.dart';
import 'providers/auth_providers.dart';
import 'providers/change_request_notification_providers.dart';
import 'providers/quest_notification_providers.dart';
import 'providers/update_providers.dart';
import 'theme/app_theme.dart';

/// Lets a tapped system-tray notification open a screen without threading a
/// BuildContext through the plugin's tap callback.
final navigatorKey = GlobalKey<NavigatorState>();

/// A quest id extracted from a `liferpg://quest/<id>` link that hasn't been
/// opened yet -- set from `main()` (cold start) and the `app_links` stream
/// (warm/background), consumed by `_PendingQuestLinkGate` once a user is
/// signed in. `null` after consumption, same "nothing pending" meaning as
/// before anything ever arrived.
final pendingQuestDeepLink = ValueNotifier<String?>(null);

void _handleIncomingLink(Uri uri) {
  final id = questIdFromDeepLink(uri);
  if (id != null) pendingQuestDeepLink.value = id;
}

void _openNotificationTarget(String payload) {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  switch (payload) {
    case 'admin_queue':
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const ChangeRequestsScreen()),
      );
    case 'my_requests':
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const NewChangeRequestScreen(),
        ),
      );
    case 'quest_board':
    case 'my_quests':
      // Deep-linking to a specific tab or quest is out of scope -- this just
      // gets the user to the Quests screen at all, same as the other cases.
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const QuestsScreen()),
      );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  final prefs = await SharedPreferences.getInstance();

  final appLinks = AppLinks();
  final initialLink = await appLinks.getInitialLink();
  if (initialLink != null) _handleIncomingLink(initialLink);
  appLinks.uriLinkStream.listen(_handleIncomingLink);

  final notificationService = FlutterLocalNotificationsChangeRequestService(
    FlutterLocalNotificationsPlugin(),
    onTap: _openNotificationTarget,
  );
  await notificationService.init();

  runApp(ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      changeRequestNotificationServiceProvider
          .overrideWithValue(notificationService),
      updateInstallerServiceProvider
          .overrideWithValue(PluginUpdateInstallerService()),
    ],
    child: const LifeRpgApp(),
  ));
}

class LifeRpgApp extends StatelessWidget {
  const LifeRpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeRPG',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildAppTheme(),
      home: const AuthGate(),
    );
  }
}

/// Chooses the root screen from auth state. This replaces the imperative
/// navigate("/login") the React useAuth hook performed.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(authStateProvider).when(
          data: (user) {
            if (user == null) return const LoginScreen();
            // Kept alive for the session so the admin queue / own-requests
            // streams are watched even while the user is elsewhere in the app.
            ref.watch(changeRequestNotificationsProvider);
            ref.watch(questNotificationsProvider);
            return const _PendingQuestLinkGate(child: HomeScreen());
          },
          loading: () => const Scaffold(
            backgroundColor: bgDark,
            body: Center(child: CircularProgressIndicator(color: gold)),
          ),
          error: (error, _) => Scaffold(
            backgroundColor: bgDark,
            body: Center(
              child: Text(
                'Błąd logowania: $error',
                style: const TextStyle(color: parchmentLight),
              ),
            ),
          ),
        );
  }
}

/// Opens [QuestDetailScreen] for a deep link that arrived before the user
/// was signed in -- listens for one to show up while mounted, and also
/// checks for one already waiting (the cold-start case, where the link was
/// consumed in `main()` before this gate ever existed) after the first
/// frame, once `navigatorKey` is guaranteed attached.
class _PendingQuestLinkGate extends StatefulWidget {
  const _PendingQuestLinkGate({required this.child});

  final Widget child;

  @override
  State<_PendingQuestLinkGate> createState() => _PendingQuestLinkGateState();
}

class _PendingQuestLinkGateState extends State<_PendingQuestLinkGate> {
  @override
  void initState() {
    super.initState();
    pendingQuestDeepLink.addListener(_consumePending);
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumePending());
  }

  @override
  void dispose() {
    pendingQuestDeepLink.removeListener(_consumePending);
    super.dispose();
  }

  void _consumePending() {
    final id = pendingQuestDeepLink.value;
    if (id == null) return;
    pendingQuestDeepLink.value = null;
    navigatorKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => QuestDetailScreen(questId: id)),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
