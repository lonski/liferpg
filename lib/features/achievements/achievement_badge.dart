import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/achievement.dart';
import '../../models/achievement_formatting.dart';
import '../../theme/app_theme.dart';

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
            light: badgeGoldLight, mid: gold, dark: goldBandDeep,
            rim: goldBandDeep, emblem: badgeGoldEmblem),
        AchievementTier.silver => const BadgeMetal(
            light: badgeSilverLight, mid: badgeSilverMid, dark: badgeSilverDark,
            rim: badgeSilverDark, emblem: badgeSilverEmblem),
        AchievementTier.bronze => const BadgeMetal(
            light: badgeBronzeLight, mid: badgeBronzeMid, dark: badgeBronzeDark,
            rim: badgeBronzeDark, emblem: badgeBronzeEmblem),
        AchievementTier.ruby => const BadgeMetal(
            light: badgeRubyLight, mid: crimsonBright, dark: crimsonDeep,
            rim: gold, emblem: badgeRubyEmblem),
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
    return Semantics(
      label: 'Odznaka ${tierAdjective(tier)}',
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        width: size,
        height: size * 1.25,
        child: CustomPaint(
          painter: _BadgePainter(metal),
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
                            fontFamily: fontDisplay,
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

class _BadgePainter extends CustomPainter {
  _BadgePainter(this.metal);

  final BadgeMetal metal;

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

    final ribbon = Paint()..color = crimson;
    final ribbonEdge = Paint()
      ..color = crimsonDeep
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
        ..shader = const RadialGradient(
          center: Alignment(0, -0.36),
          radius: 0.75,
          colors: [crimsonBright, badgeDiskEdge],
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
  bool shouldRepaint(_BadgePainter old) => old.metal != metal;
}
