import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'decor.dart';
import 'lively.dart';
import 'lively_lagotto.dart';
import 'rpg_theme.dart';

/// The assets under assets/lagotto/, drawn by tools/theme_art/lagotto_art.py.
enum Lagotto {
  dogFace('dog_face'),
  dogFaceTongue('dog_face_tongue'),
  dogLie('dog_lie'),
  dogLieBrown('dog_lie_brown'),
  dogSniff('dog_sniff'),
  dogSit('dog_sit'),
  dogSitBrown('dog_sit_brown'),
  puppy('puppy'),
  puppyWhite('puppy_white'),
  truffle('truffle'),
  truffleGold('truffle_gold'),
  basket('basket'),
  // Drawn black; tinted through [LagottoArt.color].
  paw('paw'),
  oakLeaf('oak_leaf'),
  oakLeafBrown('oak_leaf_brown'),
  oakTree('oak_tree'),
  ground('ground'),
  drop('drop'),
  heart('heart'),
  kibbleBowl('kibble_bowl'),
  kibbleHandful('kibble_handful');

  const Lagotto(this.file);

  final String file;

  String get asset => 'assets/lagotto/$file.svg';
}

/// One Lagotto illustration. [flip] mirrors it (facing left), [turns] tilts
/// it, [color] tints a one-colour asset (the paw).
class LagottoArt extends StatelessWidget {
  const LagottoArt(
    this.art, {
    super.key,
    this.width,
    this.height,
    this.flip = false,
    this.turns = 0,
    this.color,
    this.fit = BoxFit.contain,
    this.label,
  });

  final Lagotto art;
  final double? width;
  final double? height;
  final bool flip;
  final double turns;
  final Color? color;
  final BoxFit fit;

  /// A spoken description; null hides it from screen readers (decoration).
  final String? label;

  @override
  Widget build(BuildContext context) {
    Widget picture = SvgPicture.asset(
      art.asset,
      width: width,
      height: height,
      fit: fit,
      colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
      excludeFromSemantics: label == null,
      semanticsLabel: label,
    );
    if (turns != 0) picture = RotationTransition(turns: AlwaysStoppedAnimation(turns), child: picture);
    if (flip) picture = Transform.flip(flipX: true, child: picture);
    return picture;
  }
}

/// A plump bone filling [size]: two round lobes at each end and a fat shaft.
/// [biscuit] has smaller lobes and a taller shaft, to write a value on.
/// Shared by the dog-tag badges and the trait values.
Path bonePath(Size size, {bool biscuit = false}) {
  final w = size.width, h = size.height;
  final r = h * (biscuit ? 0.22 : 0.25);
  final lc = h * (biscuit ? 0.22 : 7 / 24); // lobe centre, from the end
  final dy = h * (biscuit ? 0.27 : 5 / 24); // lobe centre, from the middle
  final half = h * (biscuit ? 0.36 : 5.5 / 24); // shaft half height
  final cy = h / 2;
  final off = (half - dy).abs();
  final xs = r > off ? lc + math.sqrt(r * r - off * off) : lc;
  final notch = math.sqrt(math.max(r * r - dy * dy, 0));
  final radius = Radius.circular(r);
  return Path()
    ..moveTo(xs, cy - half)
    ..lineTo(w - xs, cy - half)
    ..arcToPoint(Offset(w - lc + notch, cy), radius: radius, largeArc: true)
    ..arcToPoint(Offset(w - xs, cy + half), radius: radius, largeArc: true)
    ..lineTo(xs, cy + half)
    ..arcToPoint(Offset(lc - notch, cy), radius: radius, largeArc: true)
    ..arcToPoint(Offset(xs, cy - half), radius: radius, largeArc: true)
    ..close();
}

/// A paw print's main pad on a 52×52 grid, scaled to [size].
Path pawPadPath(Size size) {
  final sx = size.width / 52, sy = size.height / 52;
  Offset p(double x, double y) => Offset(x * sx, y * sy);
  final a = p(26, 24);
  return Path()
    ..moveTo(a.dx, a.dy)
    ..cubicTo(33 * sx, 24 * sy, 41 * sx, 31.5 * sy, 41 * sx, 39.5 * sy)
    ..cubicTo(41 * sx, 45.5 * sy, 35.5 * sx, 48 * sy, 31 * sx, 47 * sy)
    ..cubicTo(29 * sx, 46.5 * sy, 27.5 * sx, 46 * sy, 26 * sx, 46 * sy)
    ..cubicTo(24.5 * sx, 46 * sy, 23 * sx, 46.5 * sy, 21 * sx, 47 * sy)
    ..cubicTo(16.5 * sx, 48 * sy, 11 * sx, 45.5 * sy, 11 * sx, 39.5 * sy)
    ..cubicTo(11 * sx, 31.5 * sy, 19 * sx, 24 * sy, a.dx, a.dy)
    ..close();
}

/// The paw print's four toes on the same 52×52 grid as [pawPadPath].
List<Path> pawToePaths(Size size) {
  final sx = size.width / 52, sy = size.height / 52;
  const toes = [(10.5, 19.0, -22.0), (19.5, 11.0, -7.0), (32.5, 11.0, 7.0), (41.5, 19.0, 22.0)];
  return [
    for (final (x, y, deg) in toes)
      (Path()..addOval(Rect.fromCenter(center: Offset.zero, width: 9.2 * sx, height: 12 * sy)))
          .transform((Matrix4.translationValues(x * sx, y * sy, 0)..rotateZ(deg * math.pi / 180)).storage),
  ];
}

class LagottoDecor extends RpgDecor {
  const LagottoDecor();

  static Widget _paw(double size, Color color) =>
      LagottoArt(Lagotto.paw, width: size, height: size, color: color);

  @override
  Widget dividerGlyph(BuildContext context, Color color) => _paw(16, color);

  @override
  Widget cornerOrnament(BuildContext context) => const LagottoArt(
        Lagotto.oakLeaf,
        width: 20,
        height: 20,
        turns: -0.1,
      );

  @override
  Widget ornamentedLabel(
    BuildContext context,
    String text,
    TextStyle style, {
    BandOrnament ornament = BandOrnament.star,
    TextAlign textAlign = TextAlign.center,
  }) {
    final size = (style.fontSize ?? 12) + 5;
    final Widget? glyph = switch (ornament) {
      BandOrnament.none => null,
      BandOrnament.star => LagottoArt(Lagotto.dogFace, width: size, height: size),
      BandOrnament.cycle => Icon(Icons.autorenew, size: size - 2, color: style.color),
    };
    if (glyph == null) return Text(text, style: style, textAlign: textAlign);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        glyph,
        const SizedBox(width: 8),
        Flexible(child: Text(text, style: style, textAlign: textAlign)),
        const SizedBox(width: 8),
        glyph,
      ],
    );
  }

  @override
  Widget bottomBandContent(BuildContext context, String? label) {
    final color = context.rpg.parchmentMuted;
    // Paw prints walking along the band.
    Widget step(double turns) => RotationTransition(
          turns: AlwaysStoppedAnimation(turns),
          child: _paw(13, color),
        );
    if (label == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [step(0.22), const SizedBox(width: 7), step(0.28), const SizedBox(width: 7), step(0.22)],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        step(0.25),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: context.rpg.fontDisplay,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            height: 1,
            color: context.rpg.bandLabelColor,
          ),
        ),
        const SizedBox(width: 8),
        step(0.25),
      ],
    );
  }

  @override
  Widget loginEmblem(BuildContext context) => const LivelyLagotto(
        Lagotto.dogSit,
        voice: LagottoVoice.dog,
        width: 150,
        height: 162,
        label: 'Lagotto romagnolo',
      );

  @override
  Widget? logoMark(BuildContext context) =>
      const LagottoArt(Lagotto.dogFace, width: 34, height: 34);

  @override
  Widget? loginScene(BuildContext context) => const _LoginWood();

  @override
  Perch? perch(BuildContext context, PerchSpot spot) => switch (spot) {
        // The card sits 8 px down its margin; the dog's paws rest on the frame.
        PerchSpot.characterCard => const Perch(art: _CardDen(), rise: 66, inset: 0),
        PerchSpot.questsSummary => const Perch(
            art: LivelyLagotto(Lagotto.puppy, voice: LagottoVoice.puppy, width: 50, height: 40),
            rise: 37,
            inset: 52,
          ),
        PerchSpot.questCard => const Perch(
            art: LivelyLagotto(Lagotto.puppy, voice: LagottoVoice.puppy, width: 56, height: 45, flip: true),
            rise: 42,
            inset: 26,
          ),
        PerchSpot.dailyQuest => const Perch(
            art: LivelyLagotto(Lagotto.dogSitBrown, voice: LagottoVoice.dog, width: 60, height: 65),
            rise: 61,
            inset: 14,
            left: true,
          ),
        PerchSpot.achievementsSummary => const Perch(
            art: LivelyLagotto(Lagotto.puppyWhite, voice: LagottoVoice.puppy, width: 62, height: 50),
            rise: 47,
            inset: 18,
          ),
      };

  @override
  Widget? footerScene(BuildContext context, FooterScene scene) => _WoodFloor(scene: scene);

  @override
  Widget? questsTitleMascot(BuildContext context) =>
      const LivelyLagotto(Lagotto.dogSit, voice: LagottoVoice.dog, width: 40, height: 43);

  @override
  Widget? xpRunner(BuildContext context) =>
      const LagottoArt(Lagotto.puppy, width: 36, height: 29);

  @override
  Widget? goldIcon(BuildContext context) =>
      const LagottoArt(Lagotto.truffleGold, width: 19, height: 19);

  @override
  Widget? fabFace(BuildContext context) =>
      const LagottoArt(Lagotto.dogFaceTongue, width: 48, height: 48);

  @override
  Widget? traitLeading(BuildContext context) => _paw(12, context.rpg.crimson);

  @override
  Widget? traitValue(BuildContext context, String value) => value.length > 3
      // A long, free-text legacy value would shrink to nothing on a bone.
      ? null
      : _BoneValue(value: value);

  @override
  BadgeShape get badgeShape => BadgeShape.boneTag;

  @override
  Widget badgeHero(BuildContext context, Widget badge) => SizedBox(
        height: 236,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: [
            const Positioned(
              left: 0,
              bottom: 0,
              child: LivelyLagotto(Lagotto.dogSit, voice: LagottoVoice.dog, width: 90, height: 97, label: 'Dumny lagotto'),
            ),
            const Positioned(
              right: 8,
              bottom: 2,
              child: LivelyLagotto(Lagotto.puppy, voice: LagottoVoice.puppy, width: 58, height: 46, flip: true),
            ),
            Positioned(bottom: 0, child: badge),
          ],
        ),
      );

  @override
  MedallionShape get medallionShape => MedallionShape.paw;

  @override
  Widget? countEgg(BuildContext context, int count) => _CountTag(count: count);

  @override
  Widget backdrop(BuildContext context, Widget child) => CustomPaint(
        painter: const _CurlsPainter(),
        child: child,
      );

  @override
  bool get stitchedBands => true;

  @override
  ArenaFloor get arenaFloor => ArenaFloor.forest;

  @override
  Widget? arenaOnlooker(BuildContext context) =>
      const LagottoArt(Lagotto.oakLeafBrown, width: 26, height: 26);

  @override
  Widget? spellbookKeeper(BuildContext context) =>
      const LagottoArt(Lagotto.dogFace, width: 62, height: 58);

  @override
  Widget spellbookSeal(BuildContext context) =>
      LagottoArt(Lagotto.paw, width: 32, height: 32, color: context.rpg.crimson);

  @override
  String get sealedSpellLabel => 'Zakopane głęboko';
}

const _biscuit = Color(0xFFF3B866);

/// A trait value written on a biscuit bone.
class _BoneValue extends StatelessWidget {
  const _BoneValue({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    return SizedBox(
      width: value.length < 2 ? 30 : 36,
      height: 18,
      child: CustomPaint(
        painter: _BonePainter(fill: _biscuit, stroke: t.crimson),
        child: Center(
          child: Text(
            value,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: t.fontDisplay,
              fontWeight: FontWeight.w800,
              fontSize: 11,
              height: 1,
              color: t.inkHeading,
            ),
          ),
        ),
      ),
    );
  }
}

class _BonePainter extends CustomPainter {
  const _BonePainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final bone = bonePath(Size(size.width - 1, size.height - 1), biscuit: true).shift(const Offset(.5, .5));
    canvas.drawPath(bone, Paint()..color = fill);
    canvas.drawPath(
      bone,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3,
    );
  }

  @override
  bool shouldRepaint(_BonePainter old) => old.fill != fill || old.stroke != stroke;
}

/// A round dog tag on its ring with a count (the quests summary).
class _CountTag extends StatelessWidget {
  const _CountTag({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    return SizedBox(
      width: 34,
      height: 40,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            top: 0,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.parchmentLight, width: 2),
              ),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: t.gold,
              border: Border.all(color: t.parchmentLight, width: 2.5),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$count',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: t.fontDisplay,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  height: 1,
                  color: t.inkHeading,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Honey gold with a fine pattern of coat curls.
class _CurlsPainter extends CustomPainter {
  const _CurlsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final curl = Paint()
      ..color = const Color(0xFFE3BC5E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const tile = 40.0;
    for (var y = 0.0; y < size.height; y += tile) {
      for (var x = 0.0; x < size.width; x += tile) {
        for (final (dx, dy) in const [(10.0, 10.0), (28.0, 26.0)]) {
          canvas.drawArc(
            Rect.fromCircle(center: Offset(x + dx, y + dy), radius: 3.2),
            math.pi * 0.6,
            math.pi * 1.6,
            false,
            curl,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CurlsPainter old) => false;
}

/// The white dog asleep on the character card beside a basket of truffles.
class _CardDen extends StatelessWidget {
  const _CardDen();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 300,
        height: 77,
        child: Stack(
          children: [
            Positioned(
              left: 18,
              bottom: 0,
              child: LagottoArt(Lagotto.basket, width: 54, height: 36, label: 'Kosz trufli'),
            ),
            Positioned(
              right: 30,
              bottom: 0,
              child: LivelyLagotto(Lagotto.dogLie, voice: LagottoVoice.sleepy, width: 150, height: 77, label: 'Lagotto drzemie'),
            ),
          ],
        ),
      );
}

/// The wood floor closing a list: moss, fallen leaves and dogs.
class _WoodFloor extends StatelessWidget {
  const _WoodFloor({required this.scene});

  final FooterScene scene;

  @override
  Widget build(BuildContext context) {
    final cast = switch (scene) {
      FooterScene.home => const [
          Positioned(left: 14, bottom: 30, child: LivelyLagotto(Lagotto.dogSniff, voice: LagottoVoice.dog, width: 118, height: 95, label: 'Lagotto szuka trufli')),
          Positioned(left: 134, bottom: 30, child: LagottoArt(Lagotto.truffle, width: 26, height: 26)),
          Positioned(left: 176, bottom: 34, child: LivelyLagotto(Lagotto.puppyWhite, voice: LagottoVoice.puppy, width: 60, height: 48, flip: true, runs: true)),
          Positioned(left: 246, bottom: 26, child: KibbleBowl()),
        ],
      FooterScene.quests => const [
          Positioned(left: 12, bottom: 28, child: LivelyLagotto(Lagotto.dogLieBrown, voice: LagottoVoice.sleepy, width: 140, height: 72, label: 'Lagotto śpi')),
          Positioned(left: 152, bottom: 30, child: LagottoArt(Lagotto.basket, width: 64, height: 43)),
          Positioned(left: 220, bottom: 26, child: KibbleBowl()),
          Positioned(right: 26, bottom: 32, child: LivelyLagotto(Lagotto.puppyWhite, voice: LagottoVoice.puppy, width: 62, height: 50, flip: true, runs: true)),
        ],
      FooterScene.achievements => const [
          Positioned(left: 60, bottom: 28, child: LivelyLagotto(Lagotto.dogSit, voice: LagottoVoice.dog, width: 76, height: 82, label: 'Lagotto pilnuje złotej trufli')),
          Positioned(left: 150, bottom: 30, child: LagottoArt(Lagotto.truffleGold, width: 32, height: 32)),
          Positioned(left: 196, bottom: 32, child: LivelyLagotto(Lagotto.puppy, voice: LagottoVoice.puppy, width: 58, height: 46, flip: true, runs: true)),
          Positioned(left: 262, bottom: 26, child: KibbleBowl()),
        ],
    };
    return SizedBox(
      height: 130,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: -16,
            right: -16,
            bottom: 0,
            height: 48,
            child: LagottoArt(Lagotto.ground, fit: BoxFit.fill),
          ),
          const Positioned(left: 100, bottom: 12, child: LagottoArt(Lagotto.oakLeafBrown, width: 18, height: 18, turns: 0.05)),
          const Positioned(right: 70, bottom: 8, child: LagottoArt(Lagotto.oakLeaf, width: 16, height: 16, turns: -0.08)),
          ...cast,
        ],
      ),
    );
  }
}

/// A bowl of kibble on the wood floor: drag a handful onto any dog to
/// feed it.
class KibbleBowl extends StatelessWidget {
  const KibbleBowl({super.key});

  @override
  Widget build(BuildContext context) => const LivelyFoodPile(
        food: LivelyFood.kibble,
        pile: LagottoArt(
          Lagotto.kibbleBowl,
          width: 48,
          height: 30,
          label: 'Karma — przeciągnij ją na psa',
        ),
        handful: LagottoArt(Lagotto.kibbleHandful, width: 40, height: 30),
      );
}

/// Two oaks, the wood floor, the brown dog nosing out a truffle, a puppy and
/// a basket, along the foot of the login screen.
class _LoginWood extends StatelessWidget {
  const _LoginWood();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 230,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: -46, bottom: 40, child: LagottoArt(Lagotto.oakTree, width: 150, height: 207)),
            Positioned(right: -34, bottom: 40, child: LagottoArt(Lagotto.oakTree, width: 124, height: 171)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 64,
              child: LagottoArt(Lagotto.ground, fit: BoxFit.fill),
            ),
            Positioned(left: 50, bottom: 38, child: LivelyLagotto(Lagotto.dogSniff, voice: LagottoVoice.dog, width: 124, height: 100, label: 'Lagotto węszy')),
            Positioned(left: 174, bottom: 42, child: LagottoArt(Lagotto.truffle, width: 26, height: 26)),
            Positioned(left: 8, bottom: 36, child: KibbleBowl()),
            Positioned(right: 104, bottom: 42, child: LivelyLagotto(Lagotto.puppy, voice: LagottoVoice.puppy, width: 64, height: 51, flip: true, runs: true)),
            Positioned(right: 24, bottom: 42, child: LagottoArt(Lagotto.basket, width: 58, height: 39, label: 'Kosz trufli')),
          ],
        ),
      );
}
