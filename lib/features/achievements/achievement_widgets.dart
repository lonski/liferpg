import 'package:flutter/material.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

/// The dark gradient AppBar shared by the achievement screens.
PreferredSizeWidget achievementAppBar(
  BuildContext context,
  String title, {
  List<Widget> actions = const [],
}) =>
    AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: context.rpg.parchmentLight,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: context.rpg.appBarGradient,
          border: Border(bottom: BorderSide(color: context.rpg.goldBorderFaint)),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontFamily: context.rpg.fontDisplay,
          fontSize: 18,
          letterSpacing: 2,
          color: context.rpg.parchmentLight,
        ),
      ),
      actions: actions,
    );

/// A character-card-style frame: banded top, parchment body with corner
/// ornaments, closing band. [gilded] swaps crimson for the gold band and
/// border (the "Nowa odznaka" dialog, the share image).
class ParchmentFrame extends StatelessWidget {
  const ParchmentFrame({
    super.key,
    required this.band,
    required this.child,
    this.gilded = false,
    this.footerLabel,
  });

  final String band;
  final Widget child;
  final bool gilded;

  /// Written into the closing band (`— ✦ LIFERPG ✦ —`); null keeps the
  /// plain `— ✦ —` BottomBand.
  final String? footerLabel;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.rpg.cardRadius),
          boxShadow: context.rpg.cardShadows(blur: 24, offset: const Offset(0, 6)),
        ),
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: gilded ? context.rpg.gold : context.rpg.crimson, width: context.rpg.cardBorderWidth),
          borderRadius: BorderRadius.circular(context.rpg.cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TopBand(
              label: band,
              ornament: BandOrnament.star,
              gradient: gilded ? context.rpg.goldBandGradient : context.rpg.bandGradient,
              labelColor: gilded ? context.rpg.inkHeading : context.rpg.bandLabelColor,
            ),
            Container(
              decoration: BoxDecoration(gradient: context.rpg.cardGradient),
              padding: const EdgeInsets.all(14),
              width: double.infinity,
              // passthrough: the bordered body takes the card's full width,
              // so narrower content (share image, dialog) centres instead of
              // hugging the top-left corner.
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: context.rpg.crimsonBorder),
                      borderRadius: BorderRadius.circular(context.rpg.innerRadius),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: child,
                  ),
                  const Positioned(top: 3, left: 3, child: CornerOrnament()),
                  const Positioned(
                    top: 3,
                    right: 3,
                    child: CornerOrnament(mirrored: true),
                  ),
                ],
              ),
            ),
            BottomBand(label: footerLabel),
          ],
        ),
      );
}

/// One chip per non-zero reward part.
class RewardChips extends StatelessWidget {
  const RewardChips({super.key, required this.reward});

  final AchievementReward reward;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final part in rewardParts(reward))
            Container(
              decoration: BoxDecoration(
                color: context.rpg.crimsonFaint,
                border: Border.all(color: context.rpg.goldBorder),
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              child: Text(
                part,
                style: TextStyle(
                  fontFamily: context.rpg.fontBody,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.rpg.inkHeading,
                ),
              ),
            ),
        ],
      );
}

/// A soft gold halo behind a large badge.
class BadgeGlow extends StatelessWidget {
  const BadgeGlow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [badgeGlow, badgeGlowFade]),
        ),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      );
}
