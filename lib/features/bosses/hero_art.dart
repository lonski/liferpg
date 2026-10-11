import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/boss.dart';
import '../../theme/app_theme.dart';

/// The hero's box on the arena floor, feet on its bottom edge.
const Size heroSize = Size(64, 88);

/// When, as a fraction of the fight timeline, each blow lands.
List<double> hitsFor(BlowTier tier) => switch (tier) {
  BlowTier.basic => const [0.55],
  BlowTier.strong => const [0.6],
  BlowTier.combo => const [0.45, 0.62, 0.8],
  BlowTier.hyper => const [0.72],
};

/// How long the whole fight timeline takes.
Duration fightDuration(BlowTier tier) => switch (tier) {
  BlowTier.basic => const Duration(milliseconds: 950),
  BlowTier.strong => const Duration(milliseconds: 1150),
  BlowTier.combo => const Duration(milliseconds: 1800),
  BlowTier.hyper => const Duration(milliseconds: 2300),
};

/// Swords, clubs and brooms walk up to the boss; bows and books strike
/// from where the hero stands.
bool isMelee(Weapon? w) =>
    w == Weapon.miecz || w == Weapon.maczuga || w == Weapon.miotla;

double _ease(double x) => Curves.easeInOut.transform(x.clamp(0.0, 1.0));

/// How far [t] is into [from]..[to], 0..1.
double _span(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

/// The weapon arm's angle (0 hanging down, π/2 straight forward, π up; more
/// than π reaches back over the head) at fight time [t], or while idle /
/// walking when [tier] is null.
double heroArmAngle(Weapon? weapon, BlowTier? tier, double t, double stride) {
  if (tier == null) return 0.9 + math.sin(stride / 9) * 0.25;
  final hits = hitsFor(tier);
  switch (weapon) {
    case Weapon.luk:
      // Aim and hold; a volley aims high.
      return tier == BlowTier.combo ? 2.3 : math.pi / 2;
    case Weapon.ksiega:
      return 0.9 + (1.8 - 0.9) * _ease(_span(t, 0.05, 0.3));
    case _:
      // Wind up over the head before each blow, then sweep down through it.
      for (final h in hits) {
        if (t < h + 0.06) {
          final windup = _span(t, h - 0.22, h - 0.05);
          final swing = _span(t, h - 0.05, h + 0.03);
          if (swing > 0) {
            return 3.6 + (0.9 - 3.6) * Curves.easeIn.transform(swing);
          }
          return 0.9 + (3.6 - 0.9) * _ease(windup);
        }
      }
      return 0.9;
  }
}

/// How high the hero is off the ground (a hypercios leap).
double heroLift(Weapon? weapon, BlowTier? tier, double t) {
  if (tier != BlowTier.hyper || !isMelee(weapon)) return 0;
  final p = _span(t, 0.42, 0.72);
  return math.sin(p * math.pi) * 54;
}

/// The player's fighter, drawn facing right in [heroSize] and mirrored when
/// [facingRight] is false. Its outfit follows the weapon.
class HeroPainter extends CustomPainter {
  const HeroPainter({
    required this.weapon,
    required this.stride,
    required this.armAngle,
    required this.facingRight,
    this.drawing = 0,
    this.casting = 0,
  });

  final Weapon? weapon;

  /// Distance walked so far, for the swinging legs; 0 standing still.
  final double stride;
  final double armAngle;
  final bool facingRight;

  /// How far a bow string is pulled, 0..1.
  final double drawing;

  /// How brightly an open book glows, 0..1.
  final double casting;

  static Paint _fill(Color c) => Paint()..color = c;

  static Paint _line(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Color get _tunic => switch (weapon) {
    Weapon.ksiega => heroWizardRobe,
    Weapon.maczuga => heroBarbarianTunic,
    Weapon.miotla => heroDress,
    Weapon.miecz => heroKnightTunic,
    Weapon.luk => heroArcherTunic,
    null => heroArcherTunic,
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / heroSize.width, size.height / heroSize.height);
    if (!facingRight) {
      canvas.translate(heroSize.width, 0);
      canvas.scale(-1, 1);
    }
    final outline = _line(heroOutline, 2);

    // Shadow.
    canvas.drawOval(
      const Rect.fromLTWH(14, 82, 36, 6),
      _fill(heroOutline.withValues(alpha: 0.25)),
    );

    // Legs, swinging with the stride.
    final swing = math.sin(stride / 6) * 0.55;
    for (final (dx, a) in [(-5.0, swing), (5.0, -swing)]) {
      final hip = Offset(32 + dx, 62);
      final foot = hip + Offset(math.sin(a) * 18, math.cos(a) * 18);
      canvas.drawLine(hip, foot, _line(heroOutline, 7));
      canvas.drawLine(hip, foot, _line(heroBoot, 5));
      canvas.drawOval(
        Rect.fromCenter(
          center: foot + const Offset(3, 1),
          width: 11,
          height: 6,
        ),
        _fill(heroBoot),
      );
    }

    // The free arm, behind the body.
    final back = Offset(26, 40);
    final backHand =
        back +
        Offset(math.sin(-0.3 - swing * 0.5), math.cos(-0.3 - swing * 0.5)) * 15;
    canvas.drawLine(back, backHand, _line(heroOutline, 7));
    canvas.drawLine(back, backHand, _line(heroSkin, 5));

    // Body: a tunic, a dress with an apron, or a robe.
    final body = Path()
      ..moveTo(22, 38)
      ..lineTo(42, 38)
      ..lineTo(weapon == Weapon.ksiega || weapon == Weapon.miotla ? 48 : 44, 66)
      ..lineTo(weapon == Weapon.ksiega || weapon == Weapon.miotla ? 16 : 20, 66)
      ..close();
    canvas.drawPath(body, _fill(_tunic));
    canvas.drawPath(body, outline);
    switch (weapon) {
      case Weapon.miotla:
        final apron = Path()
          ..moveTo(26, 46)
          ..lineTo(40, 46)
          ..lineTo(43, 64)
          ..lineTo(23, 64)
          ..close();
        canvas.drawPath(apron, _fill(heroApron));
        canvas.drawPath(apron, _line(heroOutline, 1.2));
      case Weapon.maczuga:
        canvas.drawPath(
          Path()
            ..moveTo(21, 38)
            ..lineTo(43, 38)
            ..lineTo(40, 46)
            ..lineTo(24, 46)
            ..close(),
          _fill(heroFur),
        );
      case Weapon.miecz:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(24, 40, 16, 14),
            const Radius.circular(3),
          ),
          _fill(heroMetal),
        );
      case _:
        break;
    }
    canvas.drawLine(
      const Offset(21, 56),
      const Offset(43, 56),
      _line(heroWoodDark, 2.5),
    );

    // Head.
    const head = Offset(32, 24);
    canvas.drawCircle(head, 14, _fill(heroSkin));
    canvas.drawCircle(head, 14, outline);
    _headgear(canvas);
    canvas.drawCircle(const Offset(36, 24), 1.8, _fill(heroOutline));
    canvas.drawCircle(const Offset(42, 24), 1.8, _fill(heroOutline));
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(39, 29), width: 7, height: 5),
      0.2,
      math.pi - 0.4,
      false,
      _line(heroOutline, 1.4),
    );
    canvas.drawCircle(
      const Offset(44, 28),
      2.2,
      _fill(heroDress.withValues(alpha: 0.25)),
    );

    // The weapon arm and its weapon, in front.
    const shoulder = Offset(34, 40);
    final dir = Offset(math.sin(armAngle), math.cos(armAngle));
    final hand = shoulder + dir * 15;
    _weapon(canvas, hand, dir);
    canvas.drawLine(shoulder, hand, _line(heroOutline, 7));
    canvas.drawLine(shoulder, hand, _line(heroSkin, 5));
    canvas.drawCircle(hand, 3.4, _fill(heroSkin));
    canvas.drawCircle(hand, 3.4, _line(heroOutline, 1.2));
    canvas.restore();
  }

  void _headgear(Canvas canvas) {
    final outline = _line(heroOutline, 2);
    switch (weapon) {
      case Weapon.ksiega:
        final hat = Path()
          ..moveTo(14, 16)
          ..lineTo(50, 16)
          ..lineTo(36, -6)
          ..lineTo(30, -2)
          ..close();
        canvas.drawPath(hat, _fill(heroWizardHat));
        canvas.drawPath(hat, outline);
        canvas.drawLine(
          const Offset(12, 16),
          const Offset(52, 16),
          _line(heroWizardHat, 5),
        );
        _star(canvas, const Offset(33, 7), 3.5, heroGold);
      case Weapon.maczuga:
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(32, 22), radius: 15),
          math.pi,
          math.pi,
          true,
          _fill(heroMetal),
        );
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(32, 22), radius: 15),
          math.pi,
          math.pi,
          true,
          outline,
        );
        for (final s in [-1.0, 1.0]) {
          final horn = Path()
            ..moveTo(32 + s * 12, 14)
            ..quadraticBezierTo(32 + s * 22, 10, 32 + s * 20, -2)
            ..quadraticBezierTo(32 + s * 16, 8, 32 + s * 8, 10)
            ..close();
          canvas.drawPath(horn, _fill(heroPaper));
          canvas.drawPath(horn, _line(heroOutline, 1.4));
        }
      case Weapon.miotla:
        final scarf = Path()
          ..moveTo(17, 22)
          ..quadraticBezierTo(32, 0, 47, 22)
          ..quadraticBezierTo(32, 14, 17, 22)
          ..close();
        canvas.drawPath(scarf, _fill(heroDress));
        canvas.drawPath(scarf, _line(heroOutline, 1.4));
        for (final o in const [
          Offset(26, 13),
          Offset(33, 10),
          Offset(40, 14),
        ]) {
          canvas.drawCircle(o, 1.4, _fill(heroApron));
        }
        canvas.drawPath(
          Path()
            ..moveTo(17, 22)
            ..lineTo(12, 30)
            ..lineTo(19, 27)
            ..close(),
          _fill(heroDress),
        );
      case Weapon.miecz:
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(32, 24), radius: 15),
          math.pi * 0.95,
          math.pi * 1.1,
          true,
          _fill(heroMetal),
        );
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(32, 24), radius: 15),
          math.pi * 0.95,
          math.pi * 1.1,
          true,
          outline,
        );
        canvas.drawLine(
          const Offset(32, 9),
          const Offset(32, 20),
          _line(heroMetalDark, 2),
        );
        final plume = Path()
          ..moveTo(30, 9)
          ..quadraticBezierTo(22, -4, 10, 4)
          ..quadraticBezierTo(20, 2, 26, 12)
          ..close();
        canvas.drawPath(plume, _fill(heroPlume));
      case Weapon.luk:
        final hood = Path()
          ..moveTo(16, 30)
          ..quadraticBezierTo(14, 6, 32, 7)
          ..quadraticBezierTo(50, 6, 48, 22)
          ..quadraticBezierTo(36, 12, 22, 20)
          ..lineTo(20, 32)
          ..close();
        canvas.drawPath(hood, _fill(heroHood));
        canvas.drawPath(hood, _line(heroOutline, 1.4));
      case null:
        final hair = Path()
          ..moveTo(18, 22)
          ..quadraticBezierTo(30, 2, 46, 18)
          ..quadraticBezierTo(32, 12, 18, 22)
          ..close();
        canvas.drawPath(hair, _fill(heroHair));
    }
  }

  void _weapon(Canvas canvas, Offset hand, Offset dir) {
    final n = Offset(-dir.dy, dir.dx);
    switch (weapon) {
      case Weapon.miecz:
        canvas.drawLine(hand - dir * 5, hand + dir * 4, _line(heroWoodDark, 4));
        canvas.drawLine(
          hand + dir * 4 + n * 7,
          hand + dir * 4 - n * 7,
          _line(heroGold, 3.5),
        );
        final blade = Path()
          ..moveTo((hand + dir * 5 + n * 2.5).dx, (hand + dir * 5 + n * 2.5).dy)
          ..lineTo((hand + dir * 30 + n * 2).dx, (hand + dir * 30 + n * 2).dy)
          ..lineTo((hand + dir * 36).dx, (hand + dir * 36).dy)
          ..lineTo((hand + dir * 30 - n * 2).dx, (hand + dir * 30 - n * 2).dy)
          ..lineTo((hand + dir * 5 - n * 2.5).dx, (hand + dir * 5 - n * 2.5).dy)
          ..close();
        canvas.drawPath(blade, _fill(heroMetal));
        canvas.drawPath(blade, _line(heroOutline, 1.3));
      case Weapon.maczuga:
        canvas.drawLine(hand - dir * 4, hand + dir * 14, _line(heroOutline, 6));
        canvas.drawLine(hand - dir * 4, hand + dir * 14, _line(heroWood, 4));
        final c = hand + dir * 24;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(math.atan2(dir.dy, dir.dx));
        const club = Rect.fromLTWH(-12, -7, 24, 14);
        canvas.drawOval(club, _fill(heroWood));
        canvas.drawOval(club, _line(heroOutline, 1.6));
        for (final o in const [Offset(-4, -4), Offset(4, 3), Offset(7, -3)]) {
          canvas.drawCircle(o, 1.6, _fill(heroMetal));
        }
        canvas.restore();
      case Weapon.miotla:
        canvas.drawLine(
          hand - dir * 12,
          hand + dir * 22,
          _line(heroOutline, 4.5),
        );
        canvas.drawLine(hand - dir * 12, hand + dir * 22, _line(heroWood, 3));
        final a = hand + dir * 22, b = hand + dir * 38;
        final bristles = Path()
          ..moveTo((a + n * 3).dx, (a + n * 3).dy)
          ..lineTo((b + n * 8).dx, (b + n * 8).dy)
          ..lineTo((b - n * 8).dx, (b - n * 8).dy)
          ..lineTo((a - n * 3).dx, (a - n * 3).dy)
          ..close();
        canvas.drawPath(bristles, _fill(heroStraw));
        canvas.drawPath(bristles, _line(heroOutline, 1.3));
        for (final k in [-4.0, 0.0, 4.0]) {
          canvas.drawLine(
            a + n * (k * 0.4),
            b + n * k,
            _line(heroWoodDark, 0.8),
          );
        }
      case Weapon.luk:
        final top = hand + n * 18 - dir * 2, bottom = hand - n * 18 - dir * 2;
        final bow = Path()
          ..moveTo(top.dx, top.dy)
          ..quadraticBezierTo(
            (hand + dir * 12).dx,
            (hand + dir * 12).dy,
            bottom.dx,
            bottom.dy,
          );
        canvas.drawPath(bow, _line(heroOutline, 4.5));
        canvas.drawPath(bow, _line(heroWood, 3));
        final nock = hand - dir * (2 + drawing * 12);
        canvas.drawLine(top, nock, _line(heroPaper, 1));
        canvas.drawLine(bottom, nock, _line(heroPaper, 1));
        if (drawing > 0) {
          canvas.drawLine(nock, hand + dir * 16, _line(heroWoodDark, 1.6));
          canvas.drawLine(
            hand + dir * 16,
            hand + dir * 12 + n * 3,
            _line(heroMetalDark, 1.6),
          );
          canvas.drawLine(
            hand + dir * 16,
            hand + dir * 12 - n * 3,
            _line(heroMetalDark, 1.6),
          );
        }
      case Weapon.ksiega:
        final c = hand + dir * 5;
        if (casting > 0) {
          canvas.drawCircle(
            c,
            10 + 8 * casting,
            _fill(spellSpark.withValues(alpha: 0.35 * casting)),
          );
        }
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(math.atan2(dir.dy, dir.dx) + math.pi / 2);
        if (casting > 0.2) {
          // Open: two pages.
          for (final s in [-1.0, 1.0]) {
            final page = Rect.fromLTWH(s < 0 ? -11 : 0, -7, 11, 14);
            canvas.drawRect(page, _fill(heroPaper));
            canvas.drawRect(page, _line(heroOutline, 1.2));
          }
          canvas.drawLine(
            const Offset(0, -7),
            const Offset(0, 7),
            _line(heroWizardHat, 1.5),
          );
        } else {
          const cover = Rect.fromLTWH(-7, -9, 14, 18);
          canvas.drawRRect(
            RRect.fromRectAndRadius(cover, const Radius.circular(2)),
            _fill(heroWizardHat),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(cover, const Radius.circular(2)),
            _line(heroOutline, 1.2),
          );
          _star(canvas, Offset.zero, 3, heroGold);
        }
        canvas.restore();
      case null:
        break;
    }
  }

  static void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 10; i++) {
      final rr = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rr;
      i == 0 ? p.moveTo(pt.dx, pt.dy) : p.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(p..close(), _fill(color));
  }

  @override
  bool shouldRepaint(HeroPainter old) =>
      old.weapon != weapon ||
      old.stride != stride ||
      old.armAngle != armAngle ||
      old.facingRight != facingRight ||
      old.drawing != drawing ||
      old.casting != casting;
}

/// Everything a blow throws around, painted over the whole arena floor:
/// slashes, arrows, spells, and the burst where each hit lands.
class FightFxPainter extends CustomPainter {
  const FightFxPainter({
    required this.weapon,
    required this.tier,
    required this.t,
    required this.hand,
    required this.heroFeet,
    required this.boss,
    required this.accent,
  });

  final Weapon weapon;
  final BlowTier tier;

  /// Fight timeline, 0..1.
  final double t;

  /// Where the weapon is held and where the hero stands, in floor
  /// coordinates.
  final Offset hand;
  final Offset heroFeet;

  /// The boss's box in floor coordinates.
  final Rect boss;
  final Color accent;

  static Paint _line(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final hits = hitsFor(tier);
    switch (weapon) {
      case Weapon.ksiega:
        _magicCircle(canvas);
        _spell(canvas, hits);
      case Weapon.luk:
        _arrows(canvas, hits);
      case Weapon.miecz:
      case Weapon.maczuga:
      case Weapon.miotla:
        _slashes(canvas, hits);
    }
    for (final (i, h) in hits.indexed) {
      _burst(canvas, h, i, big: tier == BlowTier.hyper);
    }
  }

  /// A burst of sparks and a ring where a blow lands, just after [h].
  void _burst(Canvas canvas, double h, int seed, {bool big = false}) {
    final p = _span(t, h, h + (big ? 0.25 : 0.16));
    if (p <= 0 || p >= 1) return;
    final c = boss.center + Offset(0, boss.height * 0.08);
    final fade = 1 - p;
    final color = switch (weapon) {
      Weapon.ksiega =>
        tier == BlowTier.hyper ? spellFire : spellColors(tier).$2,
      _ => spellSpark,
    };
    canvas.drawCircle(
      c,
      (big ? 22 : 12) + p * (big ? 70 : 34),
      _line(color.withValues(alpha: fade * 0.8), big ? 5 : 3),
    );
    final rnd = math.Random(seed * 31 + tier.index);
    final count = big ? 16 : 10;
    for (var i = 0; i < count; i++) {
      final a = i * 2 * math.pi / count + rnd.nextDouble() * 0.4;
      final d = Offset(math.cos(a), math.sin(a));
      final r0 = 8 + p * (big ? 50 : 26), r1 = r0 + 8 + rnd.nextDouble() * 10;
      canvas.drawLine(
        c + d * r0,
        c + d * r1,
        _line((i.isEven ? color : bossHitFlash).withValues(alpha: fade), 2.5),
      );
    }
  }

  void _slashes(Canvas canvas, List<double> hits) {
    for (final h in hits) {
      final p = _span(t, h - 0.04, h + 0.12);
      if (p <= 0 || p >= 1) continue;
      final fromLeft = hand.dx < boss.center.dx;
      final rect = Rect.fromCenter(
        center: boss.center,
        width: boss.width * 1.1,
        height: boss.height * 1.1,
      );
      final start = fromLeft ? -2.4 : -0.7;
      final sweep = (fromLeft ? 2.2 : -2.2) * Curves.easeOut.transform(p);
      final fade = 1 - _span(p, 0.5, 1);
      final color = weapon == Weapon.miotla ? heroStraw : bossHitFlash;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        _line(accent.withValues(alpha: 0.6 * fade), 12),
      );
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        _line(color.withValues(alpha: fade), 5),
      );
    }
    if (tier == BlowTier.hyper) {
      // The landing shakes the ground: a shockwave and dust.
      final p = _span(t, 0.72, 1);
      if (p > 0 && p < 1) {
        final ground = Offset(boss.center.dx, boss.bottom - 2);
        final w = 40 + p * 260;
        canvas.drawOval(
          Rect.fromCenter(center: ground, width: w, height: w * 0.18),
          _line(accent.withValues(alpha: 1 - p), 4),
        );
        final rnd = math.Random(5);
        for (var i = 0; i < 12; i++) {
          final dx = (rnd.nextDouble() - 0.5) * 2 * (30 + p * 120);
          final up = math.sin(p * math.pi) * (10 + rnd.nextDouble() * 30);
          canvas.drawCircle(
            ground + Offset(dx, -up),
            3 + rnd.nextDouble() * 3,
            Paint()..color = heroWood.withValues(alpha: 0.6 * (1 - p)),
          );
        }
      }
    }
    if (weapon == Weapon.miotla && tier == BlowTier.strong) {
      // Kurz w oczy: a cloud of dust.
      final p = _span(t, 0.5, 0.95);
      if (p > 0 && p < 1) {
        final rnd = math.Random(9);
        for (var i = 0; i < 14; i++) {
          final o =
              boss.center +
              Offset(
                (rnd.nextDouble() - 0.5) * 70 * (0.5 + p),
                (rnd.nextDouble() - 0.7) * 50 * (0.5 + p),
              );
          canvas.drawCircle(
            o,
            6 + rnd.nextDouble() * 8,
            Paint()..color = heroFur.withValues(alpha: 0.55 * (1 - p)),
          );
        }
      }
    }
  }

  void _arrow(Canvas canvas, Offset from, Offset to, double p, {Color? glow}) {
    final pos =
        Offset.lerp(from, to, p)! - Offset(0, math.sin(p * math.pi) * 26);
    final ahead =
        Offset.lerp(from, to, math.min(1, p + 0.05))! -
        Offset(0, math.sin(math.min(1, p + 0.05) * math.pi) * 26);
    final dir = ahead - pos;
    final d = dir.distance == 0 ? const Offset(1, 0) : dir / dir.distance;
    final n = Offset(-d.dy, d.dx);
    if (glow != null) {
      canvas.drawLine(pos - d * 30, pos, _line(glow.withValues(alpha: 0.5), 7));
    }
    canvas.drawLine(pos - d * 22, pos, _line(heroWoodDark, 2));
    canvas.drawPath(
      Path()
        ..moveTo((pos + d * 6).dx, (pos + d * 6).dy)
        ..lineTo((pos + n * 3.5).dx, (pos + n * 3.5).dy)
        ..lineTo((pos - n * 3.5).dx, (pos - n * 3.5).dy)
        ..close(),
      Paint()..color = heroMetalDark,
    );
    canvas.drawLine(pos - d * 22 + n * 3, pos - d * 17, _line(heroPlume, 2));
    canvas.drawLine(pos - d * 22 - n * 3, pos - d * 17, _line(heroPlume, 2));
  }

  void _arrows(Canvas canvas, List<double> hits) {
    switch (tier) {
      case BlowTier.basic:
      case BlowTier.strong:
        final h = hits.single;
        final p = _span(t, h - 0.2, h);
        if (p > 0 && p < 1) {
          _arrow(
            canvas,
            hand,
            boss.center,
            p,
            glow: tier == BlowTier.strong ? spellSpark : null,
          );
        }
      case BlowTier.combo:
        // Grad strzał: shot up, then raining down on the boss.
        for (var i = 0; i < 6; i++) {
          final land = 0.42 + i * 0.08;
          final p = _span(t, land - 0.12, land);
          if (p <= 0 || p >= 1) continue;
          final x = boss.center.dx + (i - 2.5) * 12;
          final from = Offset(x - 40, -30);
          final to = Offset(x, boss.center.dy + (i.isEven ? -10 : 12));
          final pos = Offset.lerp(from, to, p)!;
          final d = (to - from) / (to - from).distance;
          canvas.drawLine(pos - d * 22, pos, _line(heroWoodDark, 2));
          canvas.drawCircle(pos, 2.5, Paint()..color = heroMetalDark);
        }
      case BlowTier.hyper:
        final p = _span(t, 0.5, 0.68);
        if (p > 0 && p < 1) {
          _arrow(canvas, hand, boss.center, p, glow: spellIceLight);
        }
        final strike = _span(t, 0.66, 0.9);
        if (strike > 0 && strike < 1) {
          // Strzała gromu: a bolt out of the sky.
          final rnd = math.Random(3);
          final path = Path()..moveTo(boss.center.dx + 10, 0);
          var y = 0.0;
          while (y < boss.center.dy) {
            y += 14;
            path.lineTo(boss.center.dx + (rnd.nextDouble() - 0.5) * 26, y);
          }
          final fade = 1 - strike;
          canvas.drawPath(
            path,
            _line(spellIceLight.withValues(alpha: fade * 0.6), 9),
          );
          canvas.drawPath(path, _line(bossHitFlash.withValues(alpha: fade), 3));
        }
    }
  }

  void _magicCircle(Canvas canvas) {
    final p = _span(t, 0.0, 0.15) * (1 - _span(t, 0.85, 1));
    if (p <= 0) return;
    final c = heroFeet;
    final rect = Rect.fromCenter(center: c, width: 70, height: 16);
    final (core, edge) = spellColors(tier);
    canvas.drawOval(rect, _line(edge.withValues(alpha: 0.8 * p), 2.5));
    canvas.drawOval(
      rect.deflate(5),
      _line(core.withValues(alpha: 0.6 * p), 1.5),
    );
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + t * 6;
      final o = c + Offset(math.cos(a) * 30, math.sin(a) * 6);
      canvas.drawCircle(o, 2, Paint()..color = core.withValues(alpha: p));
    }
    // Motes rising off the circle.
    final rnd = math.Random(11);
    for (var i = 0; i < 8; i++) {
      final up = ((t * 2 + rnd.nextDouble()) % 1);
      final o = c + Offset((rnd.nextDouble() - 0.5) * 60, -up * 60);
      canvas.drawCircle(
        o,
        1.8,
        Paint()..color = edge.withValues(alpha: p * (1 - up)),
      );
    }
  }

  void _spell(Canvas canvas, List<double> hits) {
    final (core, edge) = spellColors(tier);
    switch (tier) {
      case BlowTier.basic:
      case BlowTier.strong:
        final h = hits.single;
        final p = _span(t, h - 0.25, h);
        if (p <= 0 || p >= 1) return;
        Offset at(double q) =>
            Offset.lerp(hand, boss.center, Curves.easeIn.transform(q))! -
            Offset(0, math.sin(q * math.pi) * 30);
        final r = tier == BlowTier.strong ? 13.0 : 7.0;
        // A trail of fading embers behind the shot.
        for (var i = 8; i >= 1; i--) {
          final q = math.max(0.0, p - i * 0.035);
          canvas.drawCircle(
            at(q),
            r * (1 - i / 10),
            Paint()..color = edge.withValues(alpha: 0.5 * (1 - i / 9)),
          );
        }
        final pos = at(p);
        canvas.drawCircle(
          pos,
          r * 1.8,
          Paint()..color = edge.withValues(alpha: 0.35),
        );
        canvas.drawCircle(pos, r, Paint()..color = edge);
        canvas.drawCircle(pos, r * 0.55, Paint()..color = core);
      case BlowTier.combo:
        // Lodowa burza: shards falling round the boss.
        final rnd = math.Random(4);
        for (var i = 0; i < 9; i++) {
          final land = 0.38 + i * 0.05;
          final p = _span(t, land - 0.14, land);
          final melt = _span(t, land, land + 0.12);
          if (p <= 0 || melt >= 1) continue;
          final x = boss.left + rnd.nextDouble() * boss.width;
          final to = Offset(
            x,
            boss.top + boss.height * (0.3 + rnd.nextDouble() * 0.6),
          );
          final pos = Offset.lerp(Offset(x - 20, -20), to, p)!;
          final a = 1 - melt;
          final shard = Path()
            ..moveTo(pos.dx, pos.dy + 9)
            ..lineTo(pos.dx - 4, pos.dy - 6)
            ..lineTo(pos.dx + 4, pos.dy - 6)
            ..close();
          canvas.drawPath(shard, Paint()..color = core.withValues(alpha: a));
          canvas.drawPath(shard, _line(edge.withValues(alpha: a), 1.5));
        }
        final frost = _span(t, 0.75, 1);
        if (frost > 0 && frost < 1) {
          canvas.drawCircle(
            boss.center,
            boss.width * 0.6,
            Paint()..color = core.withValues(alpha: 0.35 * (1 - frost)),
          );
        }
      case BlowTier.hyper:
        // Deszcz meteorów: three rocks out of the sky, the last one biggest.
        for (var i = 0; i < 3; i++) {
          final land = 0.56 + i * 0.08;
          final p = _span(t, land - 0.2, land);
          if (p <= 0 || p >= 1) continue;
          final to = boss.center + Offset((i - 1) * 22.0, (i - 1).abs() * 8.0);
          final from = to + const Offset(-130, -190);
          final pos = Offset.lerp(from, to, Curves.easeIn.transform(p))!;
          final d = (to - from) / (to - from).distance;
          final r = 8.0 + i * 3;
          canvas.drawLine(
            pos - d * 50,
            pos,
            _line(spellFire.withValues(alpha: 0.45), r * 1.6),
          );
          canvas.drawLine(
            pos - d * 30,
            pos,
            _line(spellSpark.withValues(alpha: 0.7), r * 0.8),
          );
          canvas.drawCircle(pos, r, Paint()..color = core);
          canvas.drawCircle(pos, r, _line(edge, 2));
        }
        final boom = _span(t, 0.72, 0.95);
        if (boom > 0 && boom < 1) {
          canvas.drawCircle(
            boss.center,
            20 + boom * 70,
            Paint()..color = spellFire.withValues(alpha: 0.45 * (1 - boom)),
          );
          canvas.drawCircle(
            boss.center,
            10 + boom * 40,
            Paint()..color = spellFireCore.withValues(alpha: 0.6 * (1 - boom)),
          );
        }
    }
  }

  @override
  bool shouldRepaint(FightFxPainter old) =>
      old.t != t || old.hand != hand || old.boss != boss || old.tier != tier;
}

/// A spell's colours: inner and outer, for the book's four tiers.
(Color, Color) spellColors(BlowTier tier) => switch (tier) {
  BlowTier.basic => (spellFireCore, spellSpark),
  BlowTier.strong => (spellFireCore, spellFire),
  BlowTier.combo => (spellIceLight, spellIce),
  BlowTier.hyper => (spellRock, spellRockDark),
};
