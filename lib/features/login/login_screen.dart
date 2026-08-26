import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Logowanie nieudane: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚔', style: TextStyle(fontSize: 40, color: gold)),
              const SizedBox(height: 12),
              const Text(
                'LifeRPG',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                  color: parchmentLight,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Kronika Bohaterów',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 2,
                  color: parchmentFaint,
                ),
              ),
              const SizedBox(height: 20),
              const OrnamentDivider(color: gold, width: 160),
              const SizedBox(height: 32),
              _SignInButton(busy: _busy, onPressed: _busy ? null : _signIn),
              const SizedBox(height: 28),
              const Text(
                '„Twoja legenda czeka...”',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: parchmentFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.busy, required this.onPressed});

  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            gradient: buttonGradient,
            border: Border.all(color: goldBorder),
            borderRadius: BorderRadius.circular(3),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: gold),
                )
              else
                const Text(
                  'G',
                  style: TextStyle(
                    fontFamily: fontDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: gold,
                  ),
                ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zaloguj przez Google',
                    style: TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 13,
                      letterSpacing: 1,
                      color: parchmentLight,
                    ),
                  ),
                  Text(
                    'Wejdź do Kroniki',
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: parchmentMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
