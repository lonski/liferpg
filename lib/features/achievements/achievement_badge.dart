import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../theme/app_theme.dart';
import '../../theme/decor.dart' show BadgeShape, eggPath;
import '../../theme/lagotto_decor.dart' show bonePath;

/// One tier's ring colours. Instances are const and canonical per tier.
class BadgeMetal {
  const BadgeMetal({
    required this.light,
    required this.mid,
    required this.dark,
    required this.rim,
    required this.emblem,
  });

  final Color light;
  final Color mid;
  final Color dark;
  final Color rim;
  final Color emblem;

  static BadgeMetal of(AchievementTier tier) => switch (tier) {
        AchievementTier.gold => const BadgeMetal(
            light: badgeGoldLight, mid: badgeGoldMid, dark: badgeGoldDark,
            rim: badgeGoldDark, emblem: badgeGoldEmblem),
        AchievementTier.silver => const BadgeMetal(
            light: badgeSilverLight, mid: badgeSilverMid, dark: badgeSilverDark,
            rim: badgeSilverDark, emblem: badgeSilverEmblem),
        AchievementTier.bronze => const BadgeMetal(
            light: badgeBronzeLight, mid: badgeBronzeMid, dark: badgeBronzeDark,
            rim: badgeBronzeDark, emblem: badgeBronzeEmblem),
        AchievementTier.ruby => const BadgeMetal(
            light: badgeRubyLight, mid: badgeRubyMid, dark: badgeRubyDark,
            rim: badgeGoldMid, emblem: badgeRubyEmblem),
      };
}

IconData? _iconFor(AchievementEmblem emblem) => switch (emblem) {
      AchievementEmblem.trophy => Icons.emoji_events,
      AchievementEmblem.note => Icons.music_note,
      AchievementEmblem.peak => Icons.landscape,
      AchievementEmblem.book => Icons.menu_book,
      AchievementEmblem.star => Icons.star,
      AchievementEmblem.place => null,
    };

/// The medal from the "Rodzina odznak" sheet: ribbon tails, a ring in the
/// tier's metal with a milled edge, a crimson disk, and the emblem. Drawn
/// on a 120×150 grid scaled to [size] (the width).
class AchievementBadge extends StatelessWidget {
  const AchievementBadge({
    super.key,
    required this.tier,
    required this.emblem,
    this.place,
    this.size = 120,
  });

  AchievementBadge.of(Achievement a, {super.key, this.size = 120})
      : tier = a.tier,
        emblem = a.emblem,
        place = a.place;

  final AchievementTier tier;
  final AchievementEmblem emblem;
  final int? place;
  final double size;

  @override
  Widget build(BuildContext context) {
    final metal = BadgeMetal.of(tier);
    final shown = emblem == AchievementEmblem.place && place == null
        ? AchievementEmblem.trophy
        : emblem;
    final icon = _iconFor(shown);
    final s = size / 120;
    switch (context.rpg.decor.badgeShape) {
      case BadgeShape.egg:
        return _EggBadge(metal: metal, icon: icon, place: place, size: size, tier: tier);
      case BadgeShape.boneTag:
        return _BoneTagBadge(metal: metal, icon: icon, place: place, size: size, tier: tier);
      case BadgeShape.medal:
        break;
    }
    return Semantics(
      label: 'Odznaka ${tierAdjective(tier)}',
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size * 1.25,
        child: CustomPaint(
          painter: _BadgePainter(metal, context.rpg),
          child: Stack(
            children: [
              // The disk is centred at (60, 58) on the 120×150 grid.
              Positioned(
                left: 35 * s,
                top: 33 * s,
                width: 50 * s,
                height: 50 * s,
                child: Center(
                  child: icon != null
                      ? Icon(icon, size: 38 * s, color: metal.emblem)
                      : Text(
                          romanPlace(place!),
                          // A graphic, not prose: it must fit the disk.
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: context.rpg.fontDisplay,
                            fontSize: 30 * s,
                            height: 1,
                            color: metal.emblem,
                          ),
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

/// Kurczaki's badge: an egg cast in the tier's metal, an accent egg inset
/// in it, and the emblem on that. Same footprint as the medal ([size] wide,
/// 1.25 × [size] tall) so every layout that holds a medal holds an egg.
class _EggBadge extends StatelessWidget {
  const _EggBadge({
    required this.metal,
    required this.icon,
    required this.place,
    required this.size,
    required this.tier,
  });

  final BadgeMetal metal;
  final IconData? icon;
  final int? place;
  final double size;
  final AchievementTier tier;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    // The egg is narrower than the medal's 120-wide grid: 0.84 × size wide.
    final w = size * 0.84, h = size * 1.02;
    return Semantics(
      label: 'Odznaka ${tierAdjective(tier)}',
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size * 1.25,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: w,
            height: h,
            child: CustomPaint(
              painter: _EggBadgePainter(metal, t, ruby: tier == AchievementTier.ruby),
              child: Padding(
                // The inner egg's belly, where the emblem sits.
                padding: EdgeInsets.only(top: h * 0.42, bottom: h * 0.1),
                child: Center(
                  child: icon != null
                      ? Icon(icon, size: w * 0.36, color: metal.emblem)
                      : Text(
                          romanPlace(place!),
                          textScaler: TextScaler.noScaling,
                          style: TextStyle(
                            fontFamily: t.fontDisplay,
                            fontWeight: FontWeight.w700,
                            fontSize: w * 0.32,
                            height: 1,
                            color: metal.emblem,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EggBadgePainter extends CustomPainter {
  _EggBadgePainter(this.metal, this.theme, {required this.ruby});

  final BadgeMetal metal;
  final RpgTheme theme;
  final bool ruby;

  @override
  void paint(Canvas canvas, Size size) {
    final outer = eggPath(size);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [metal.light, metal.mid, metal.dark],
          stops: const [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..color = ruby ? metal.rim : theme.inkHeading
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * (ruby ? 0.045 : 0.035),
    );

    // The inset egg: the same shape at ~62 %, its base nearer the bottom.
    final inner = Size(size.width * 0.62, size.height * 0.68);
    canvas.save();
    canvas.translate((size.width - inner.width) / 2, size.height * 0.24);
    final innerEgg = eggPath(inner);
    canvas.drawPath(innerEgg, Paint()..color = theme.crimson);
    canvas.drawPath(
      innerEgg,
      Paint()
        ..color = theme.crimsonDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.03,
    );
    canvas.restore();

    // A highlight on the shell.
    canvas.save();
    canvas.translate(size.width * 0.29, size.height * 0.29);
    canvas.rotate(0.38);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size.width * 0.11, height: size.height * 0.2),
      Paint()..color = const Color(0x80FFFFFF),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EggBadgePainter old) =>
      old.metal != metal || old.theme != theme || old.ruby != ruby;
}

/// Lagotto's badge: a bone-shaped dog tag cast in the tier's metal, hung
/// from a split ring, with an accent bone inset carrying the emblem. Drawn
/// on a 60×46 grid scaled to [size] (the width), at the foot of the medal's
/// [size] × 1.25 [size] footprint.
class _BoneTagBadge extends StatelessWidget {
  const _BoneTagBadge({
    required this.metal,
    required this.icon,
    required this.place,
    required this.size,
    required this.tier,
  });

  final BadgeMetal metal;
  final IconData? icon;
  final int? place;
  final double size;
  final AchievementTier tier;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    final s = size / 60;
    return Semantics(
      label: 'Odznaka ${tierAdjective(tier)}',
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size * 1.25,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: size,
            height: 46 * s,
            child: CustomPaint(
              painter: _BoneTagPainter(metal, t, ruby: tier == AchievementTier.ruby),
              child: Padding(
                // The inset bone's shaft, where the emblem sits.
                padding: EdgeInsets.only(left: 20 * s, right: 20 * s, top: 22 * s, bottom: 13 * s),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: icon != null
                        ? Icon(icon, size: 13 * s, color: metal.emblem)
                        : Text(
                            romanPlace(place!),
                            textScaler: TextScaler.noScaling,
                            style: TextStyle(
                              fontFamily: t.fontDisplay,
                              fontWeight: FontWeight.w800,
                              fontSize: 12 * s,
                              height: 1,
                              color: metal.emblem,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoneTagPainter extends CustomPainter {
  _BoneTagPainter(this.metal, this.theme, {required this.ruby});

  final BadgeMetal metal;
  final RpgTheme theme;
  final bool ruby;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 60;
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * s;

    // The split ring it hangs from.
    canvas.drawCircle(Offset(30 * s, 7 * s), 5 * s, stroke(metal.dark, 2.2));
    canvas.drawCircle(Offset(30 * s, 7 * s), 5 * s, stroke(metal.light, 0.8));

    final outer = bonePath(Size(58 * s, 34 * s)).shift(Offset(1 * s, 11 * s));
    canvas.drawPath(
      outer,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [metal.light, metal.mid, metal.dark],
          stops: const [0, 0.55, 1],
        ).createShader(outer.getBounds()),
    );
    canvas.drawPath(outer, stroke(ruby ? metal.rim : theme.inkHeading, ruby ? 2 : 1.6));
    // The hole the ring passes through.
    canvas.drawCircle(Offset(30 * s, 14.5 * s), 1.8 * s, Paint()..color = metal.dark);

    final inner = bonePath(Size(40 * s, 22 * s)).shift(Offset(10 * s, 17 * s));
    canvas.drawPath(inner, Paint()..color = theme.crimson);
    canvas.drawPath(inner, stroke(metal.dark, 1.2));

    // A highlight on the metal.
    canvas.save();
    canvas.translate(12 * s, 20 * s);
    canvas.rotate(0.6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 4.4 * s, height: 8.8 * s),
      Paint()..color = const Color(0x80FFFFFF),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BoneTagPainter old) =>
      old.metal != metal || old.theme != theme || old.ruby != ruby;
}

class _BadgePainter extends CustomPainter {
  _BadgePainter(this.metal, this.theme);

  final BadgeMetal metal;
  final RpgTheme theme;

  static final Path _leftTail = Path()
    ..moveTo(34, 84)
    ..lineTo(56, 96)
    ..lineTo(44, 146)
    ..lineTo(35, 136)
    ..lineTo(24, 144)
    ..close();

  static final Path _rightTail = Path()
    ..moveTo(86, 84)
    ..lineTo(64, 96)
    ..lineTo(76, 146)
    ..lineTo(85, 136)
    ..lineTo(96, 144)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120);

    final ribbon = Paint()..color = theme.crimson;
    final ribbonEdge = Paint()
      ..color = theme.crimsonDeep
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final tail in [_leftTail, _rightTail]) {
      canvas.drawPath(tail, ribbon);
      canvas.drawPath(tail, ribbonEdge);
    }
    final stripe = Paint()
      ..color = metal.mid
      ..strokeWidth = 3;
    canvas.drawLine(const Offset(45, 92), const Offset(34.5, 139), stripe);
    canvas.drawLine(const Offset(75, 92), const Offset(85.5, 139), stripe);

    const c = Offset(60, 58);
    canvas.drawCircle(
      c,
      50,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [metal.light, metal.mid, metal.dark],
        ).createShader(Rect.fromCircle(center: c, radius: 50)),
    );
    canvas.drawCircle(
      c,
      50,
      Paint()
        ..color = metal.rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Milled edge.
    final milled = Paint()
      ..color = metal.rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    const teeth = 56;
    const sweep = 2 * math.pi / teeth;
    final milledRect = Rect.fromCircle(center: c, radius: 45);
    for (var i = 0; i < teeth; i++) {
      canvas.drawArc(milledRect, i * sweep, sweep * 0.4, false, milled);
    }

    canvas.drawCircle(
      c,
      39,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(0, -0.36),
          radius: 0.75,
          colors: [theme.crimsonBright, badgeDiskEdge],
        ).createShader(Rect.fromCircle(center: c, radius: 39)),
    );
    canvas.drawCircle(
      c,
      39,
      Paint()
        ..color = metal.rim
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      c,
      34,
      Paint()
        ..color = metal.mid
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    _glyph(canvas, const Offset(60, 13.5));
    _glyph(canvas, const Offset(60, 102.5));
    canvas.restore();
  }

  void _glyph(Canvas canvas, Offset center) {
    final tp = TextPainter(
      text: TextSpan(
        text: '✦',
        style: TextStyle(fontSize: 8, height: 1, color: metal.rim),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.metal != metal || old.theme != theme;
}
