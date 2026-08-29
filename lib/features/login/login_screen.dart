import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/update_providers.dart';
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
    final version = ref.watch(appVersionProvider).value;
    return Scaffold(
      backgroundColor: bgDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '⚔',
                style: TextStyle(
                  fontSize: 40,
                  color: gold,
                  shadows: [Shadow(color: goldBorder, blurRadius: 12)],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'LifeRPG',
                style: TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: parchmentLight,
                  shadows: [Shadow(color: goldBorderFaint, blurRadius: 20)],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kronika Bohaterów'.toUpperCase(),
                style: const TextStyle(
                  fontFamily: fontDisplay,
                  fontSize: 9,
                  letterSpacing: 5,
                  color: goldSubtitle,
                ),
              ),
              const SizedBox(height: 12),
              const OrnamentDivider(
                color: goldBorder,
                glyphColor: goldGlyph,
                width: 160,
              ),
              const SizedBox(height: 32),
              _SignInButton(busy: _busy, onPressed: _busy ? null : _signIn),
              const SizedBox(height: 20),
              const Text(
                '„Twoja legenda czeka...”',
                style: TextStyle(
                  fontFamily: fontBody,
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1,
                  color: parchmentGhost,
                ),
              ),
              if (version != null) ...[
                const SizedBox(height: 12),
                Text(
                  version,
                  key: const Key('app-version'),
                  style: const TextStyle(
                    fontFamily: fontBody,
                    fontSize: 9,
                    color: parchmentGhost,
                  ),
                ),
              ],
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
            border: Border.all(color: goldGlyph),
            borderRadius: BorderRadius.circular(3),
            boxShadow: const [
              BoxShadow(color: buttonShadowColor, blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
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
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zaloguj przez Google'.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: fontDisplay,
                      fontSize: 11,
                      letterSpacing: 3,
                      color: parchmentLight,
                    ),
                  ),
                  const Text(
                    'Wejdź do Kroniki',
                    style: TextStyle(
                      fontFamily: fontBody,
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: parchmentFaint,
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
