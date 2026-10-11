import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/boss.dart';
import '../../theme/app_theme.dart';
import '../../theme/decor.dart';

/// Whether the endless boss loops (walking, the ready pulse, a spell's
/// glow) run. Off in widget tests, where they would keep pumpAndSettle from
/// ever settling.
abstract final class BossMotion {
  static bool loops = true;
}

/// A boss drawing (`assets/bosses/<look>.svg`), optionally tinted towards
/// white by [flash] (0..1) when it is hit.
class BossArt extends StatelessWidget {
  const BossArt(
    this.look, {
    super.key,
    this.size = 120,
    this.flip = false,
    this.flash = 0,
  });

  final BossLook look;
  final double size;
  final bool flip;
  final double flash;

  @override
  Widget build(BuildContext context) {
    Widget art = SvgPicture.asset(
      look.asset,
      width: size,
      height: size,
      semanticsLabel: look.label,
    );
    if (flash > 0) {
      art = ColorFiltered(
        colorFilter: ColorFilter.mode(
          bossHitFlash.withValues(alpha: bossHitFlash.a * flash.clamp(0, 1)),
          BlendMode.srcATop,
        ),
        child: art,
      );
    }
    if (flip) {
      art = Transform.flip(flipX: true, child: art);
    }
    return art;
  }
}

/// A weapon's line icon, inked in [color].
class WeaponIcon extends StatelessWidget {
  const WeaponIcon(
    this.weapon, {
    super.key,
    this.size = 26,
    required this.color,
  });

  final Weapon weapon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    weapon.asset,
    width: size,
    height: size,
    colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    semanticsLabel: weapon.label,
  );
}

/// The magic circle on a spellbook page, with the spell's symbol inside.
class SpellSigil extends StatelessWidget {
  const SpellSigil({
    super.key,
    required this.tier,
    required this.weapon,
    required this.ink,
    this.size = 120,
  });

  final BlowTier tier;
  final Weapon weapon;
  final Color ink;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(
      painter: _SigilPainter(tier, ink),
      child: weapon == Weapon.ksiega
          ? null
          : Center(
              child: WeaponIcon(weapon, size: size * 0.4, color: ink),
            ),
    ),
  );
}

class _SigilPainter extends CustomPainter {
  const _SigilPainter(this.tier, this.ink);

  final BlowTier tier;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 140;
    canvas.save();
    canvas.scale(s);
    const c = Offset(70, 70);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, 62, line);
    final thin = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var a = 0.0; a < 2 * math.pi; a += 2 * math.pi / 36) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: 52),
        a,
        0.06,
        false,
        thin,
      );
    }
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final d = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + d * 52, c + d * 62, line);
    }
    _symbol(canvas);
    canvas.restore();
  }

  void _symbol(Canvas canvas) {
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..style = PaintingStyle.fill;
    switch (tier) {
      case BlowTier.basic:
        final star = Path()..moveTo(70, 38);
        for (var i = 1; i <= 10; i++) {
          final r = i.isOdd ? 14.0 : 32.0;
          final a = -math.pi / 2 + i * math.pi / 5;
          star.lineTo(70 + r * math.cos(a), 70 + r * math.sin(a));
        }
        star.close();
        canvas.drawPath(star, fill..color = spellSpark);
        canvas.drawPath(
          star,
          stroke
            ..color = spellFire
            ..strokeWidth = 2.5,
        );
      case BlowTier.strong:
        final flame = Path()
          ..moveTo(70, 32)
          ..cubicTo(84, 48, 100, 60, 96, 82)
          ..cubicTo(93, 98, 82, 106, 70, 106)
          ..cubicTo(58, 106, 46, 98, 44, 82)
          ..cubicTo(42, 68, 50, 60, 56, 52)
          ..cubicTo(58, 62, 62, 66, 66, 66)
          ..cubicTo(64, 52, 66, 42, 70, 32)
          ..close();
        canvas.drawPath(flame, fill..color = spellFire);
        canvas.drawPath(
          flame,
          stroke
            ..color = spellRockDark
            ..strokeWidth = 2.5,
        );
        canvas.drawOval(
          const Rect.fromLTWH(60, 72, 20, 26),
          fill..color = spellSpark,
        );
      case BlowTier.combo:
        stroke
          ..color = spellIce
          ..strokeWidth = 5;
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi / 3 + math.pi / 2;
          final d = Offset(math.cos(a), math.sin(a)) * 36;
          canvas.drawLine(
            const Offset(70, 70) - d,
            const Offset(70, 70) + d,
            stroke,
          );
        }
        final tips = Paint()
          ..color = spellIceLight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 6; i++) {
          final a = i * math.pi / 3 + math.pi / 2;
          final d = Offset(math.cos(a), math.sin(a));
          final p = const Offset(70, 70) + d * 26;
          final n = Offset(-d.dy, d.dx) * 7;
          canvas.drawLine(p, p + d * 7 + n, tips);
          canvas.drawLine(p, p + d * 7 - n, tips);
        }
      case BlowTier.hyper:
        final trail = Paint()
          ..color = spellSpark.withValues(alpha: 0.7)
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(30, 34), const Offset(70, 74), trail);
        canvas.drawLine(const Offset(54, 26), const Offset(84, 56), trail);
        canvas.drawLine(const Offset(24, 60), const Offset(50, 86), trail);
        for (final (o, r) in const [
          (Offset(80, 84), 16.0),
          (Offset(96, 58), 9.0),
          (Offset(58, 100), 7.0),
        ]) {
          canvas.drawCircle(o, r, fill..color = spellRock);
          canvas.drawCircle(
            o,
            r,
            stroke
              ..color = spellRockDark
              ..strokeWidth = 2.5,
          );
        }
    }
  }

  @override
  bool shouldRepaint(_SigilPainter old) => old.tier != tier || old.ink != ink;
}

/// A dashed rounded-rectangle seam (the stitched spellbook cover).
class DashedFrame extends StatelessWidget {
  const DashedFrame({
    super.key,
    required this.color,
    required this.radius,
    required this.child,
  });

  final Color color;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: _DashedFramePainter(color, radius),
    child: child,
  );
}

class _DashedFramePainter extends CustomPainter {
  const _DashedFramePainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(1.5),
      Radius.circular(radius),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 9) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + 5, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFramePainter old) =>
      old.color != color || old.radius != radius;
}

/// The arena's ground: stone flags, a straw yard or a forest floor.
class ArenaFloorPainter extends CustomPainter {
  const ArenaFloorPainter({
    required this.style,
    required this.floor,
    required this.line,
    this.grass,
  });

  final ArenaFloor style;
  final Color floor;
  final Color line;
  final Color? grass;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = floor);
    final p = Paint()
      ..color = line
      ..strokeWidth = 1;
    switch (style) {
      case ArenaFloor.stone:
        const w = 28.0, h = 14.0;
        for (var y = 0.0, row = 0; y < size.height; y += h, row++) {
          canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
          for (var x = row.isOdd ? w / 2 : 0.0; x < size.width; x += w) {
            canvas.drawLine(Offset(x, y), Offset(x, y + h), p);
          }
        }
      case ArenaFloor.yard:
        p.strokeWidth = 2;
        for (var x = -size.height; x < size.width; x += 9) {
          canvas.drawLine(
            Offset(x, size.height),
            Offset(x + size.height * 0.18, 0),
            p,
          );
        }
      case ArenaFloor.forest:
        final rnd = math.Random(7);
        p.style = PaintingStyle.fill;
        for (var i = 0; i < size.width * size.height / 260; i++) {
          canvas.drawCircle(
            Offset(
              rnd.nextDouble() * size.width,
              rnd.nextDouble() * size.height,
            ),
            1 + rnd.nextDouble() * 1.5,
            p,
          );
        }
    }
    if (grass != null) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, 8),
        Paint()..color = grass!,
      );
    }
  }

  @override
  bool shouldRepaint(ArenaFloorPainter old) =>
      old.style != style ||
      old.floor != floor ||
      old.line != line ||
      old.grass != grass;
}
