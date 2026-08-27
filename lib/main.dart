import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/home/home_screen.dart';
import 'features/login/login_screen.dart';
import 'firebase_options.dart';
import 'providers/auth_providers.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const ProviderScope(child: LifeRpgApp()));
}

class LifeRpgApp extends StatelessWidget {
  const LifeRpgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeRPG',
      debugShowCheckedModeBanner: false,
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
          data: (user) => user == null ? const LoginScreen() : const HomeScreen(),
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
