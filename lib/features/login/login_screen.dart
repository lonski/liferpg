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
      backgroundColor: context.rpg.bgDark,
      body: ThemeBackdrop(
        child: Stack(
          children: [
            if (context.rpg.decor.loginScene(context) case final scene?)
              Positioned(left: 0, right: 0, bottom: 0, child: scene),
            Positioned.fill(child: _content(context, version)),
          ],
        ),
      ),
    );
  }

  Widget _content(BuildContext context, String? version) {
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              context.rpg.decor.loginEmblem(context),
              const SizedBox(height: 10),
              Text(
                'LifeRPG',
                style: TextStyle(
                  fontFamily: context.rpg.fontDisplay,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: context.rpg.onBg,
                  shadows: [Shadow(color: context.rpg.goldBorderFaint, blurRadius: 20)],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Kronika Bohaterów'.toUpperCase(),
                style: TextStyle(
                  fontFamily: context.rpg.fontDisplay,
                  fontSize: 9,
                  letterSpacing: 5,
                  color: context.rpg.goldSubtitle,
                ),
              ),
              const SizedBox(height: 12),
              OrnamentDivider(
                color: context.rpg.goldBorder,
                glyphColor: context.rpg.goldGlyph,
                width: 160,
              ),
              const SizedBox(height: 32),
              _SignInButton(busy: _busy, onPressed: _busy ? null : _signIn),
              const SizedBox(height: 20),
              Text(
                '„Twoja legenda czeka...”',
                style: TextStyle(
                  fontFamily: context.rpg.fontBody,
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1,
                  color: context.rpg.onBgGhost,
                ),
              ),
              if (version != null) ...[
                const SizedBox(height: 12),
                Text(
                  version,
                  key: const Key('app-version'),
                  style: TextStyle(
                    fontFamily: context.rpg.fontBody,
                    fontSize: 9,
                    color: context.rpg.onBgGhost,
                  ),
                ),
              ],
            ],
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
            gradient: context.rpg.buttonGradient,
            border: Border.all(color: context.rpg.goldGlyph),
            borderRadius: BorderRadius.circular(context.rpg.buttonRadius),
            boxShadow: [
              BoxShadow(color: context.rpg.buttonShadowColor, blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: context.rpg.gold),
                )
              else
                Text(
                  'G',
                  style: TextStyle(
                    fontFamily: context.rpg.fontDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.rpg.gold,
                  ),
                ),
              const SizedBox(width: 12),
              // Flexible so a narrow phone or a large text scale wraps the
              // label instead of overflowing the button.
              Flexible(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Zaloguj przez Google'.toUpperCase(),
                    style: TextStyle(
                      fontFamily: context.rpg.fontDisplay,
                      fontSize: 11,
                      letterSpacing: 3,
                      color: context.rpg.parchmentLight,
                    ),
                  ),
                  Text(
                    'Wejdź do Kroniki',
                    style: TextStyle(
                      fontFamily: context.rpg.fontBody,
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      color: context.rpg.parchmentFaint,
                    ),
                  ),
                ],
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
