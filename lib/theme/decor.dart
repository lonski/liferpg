import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'lively_kurczak.dart';
import 'rpg_theme.dart';

/// Which glyphs flank an ornamented label: `✦ X ✦`, `⟳ X ⟳`, or none.
enum BandOrnament { none, star, cycle }

/// Where a theme may seat an illustration on top of a card.
enum PerchSpot {
  characterCard,
  questsSummary,
  questCard,
  dailyQuest,
  achievementsSummary,
}

/// Where a theme may stage a scene below the last item of a list.
enum FooterScene { home, quests, achievements }

/// How an achievement badge is cast: Kronika's ribboned medal, Kurczaki's
/// metal egg, Lagotto's bone-shaped dog tag.
enum BadgeShape { medal, egg, boneTag }

/// What holds the electronics-days count: Kronika's ring, Kurczaki's
/// yolk-filling egg, Lagotto's paw pad.
enum MedallionShape { ring, egg, paw }

/// An illustration seated on a card's top edge: [art] rises [rise] px above
/// the card and sits [inset] px in from the [left] or right side. Keep
/// [rise] within a few px of the art's height, so it rests on the frame
/// rather than over the band -- on a narrow phone the band's label spans
/// most of the width and anything lower hides it.
class Perch {
  const Perch({
    required this.art,
    required this.rise,
    this.inset = 16,
    this.left = false,
  });

  final Widget art;
  final double rise;
  final double inset;
  final bool left;
}

/// A theme's ornaments and illustrations. The base class is the Kronika
/// look -- text glyphs (✦ ❧ ⚔ ⟳), no illustrations -- so every scene hook
/// returns null here ("nothing extra"); [KurczakiDecor] overrides them.
class RpgDecor {
  const RpgDecor();

  /// The ✦ breaking an [OrnamentDivider].
  Widget dividerGlyph(BuildContext context, Color color) =>
      Text('✦', style: TextStyle(fontSize: 11, color: color));

  /// The ❧ in a framed card's top corners (left-hand orientation).
  Widget cornerOrnament(BuildContext context) => Text(
    '❧',
    style: TextStyle(fontSize: 12, color: context.rpg.ornamentInk, height: 1),
  );

  /// [text] (already upper-cased by the caller) between two glyphs. One
  /// Text, so `find.text('✦ KARTA POSTACI ✦')` keeps matching.
  Widget ornamentedLabel(
    BuildContext context,
    String text,
    TextStyle style, {
    BandOrnament ornament = BandOrnament.star,
    TextAlign textAlign = TextAlign.center,
  }) {
    final glyph = switch (ornament) {
      BandOrnament.none => null,
      BandOrnament.star => '✦',
      BandOrnament.cycle => '⟳',
    };
    return Text(
      glyph == null ? text : '$glyph $text $glyph',
      style: style,
      textAlign: textAlign,
    );
  }

  /// The content of the closing band at a card's foot.
  Widget bottomBandContent(BuildContext context, String? label) => Text(
    label == null ? '— ✦ —' : '— ✦ ${label.toUpperCase()} ✦ —',
    style: TextStyle(
      fontFamily: label == null ? null : context.rpg.fontDisplay,
      fontSize: 10,
      letterSpacing: 3,
      color: context.rpg.parchmentMedium,
      height: 1,
    ),
  );

  /// The emblem above "LifeRPG" on the login screen.
  Widget loginEmblem(BuildContext context) => Text(
    '⚔',
    style: TextStyle(
      fontSize: 40,
      color: context.rpg.gold,
      shadows: [Shadow(color: context.rpg.goldBorder, blurRadius: 12)],
    ),
  );

  /// A mark beside "LifeRPG" in the home AppBar; null keeps the `⚔` text.
  Widget? logoMark(BuildContext context) => null;

  /// Illustrations staged behind the login screen's content.
  Widget? loginScene(BuildContext context) => null;

  Perch? perch(BuildContext context, PerchSpot spot) => null;

  Widget? footerScene(BuildContext context, FooterScene scene) => null;

  /// Beside the Zadania AppBar title.
  Widget? questsTitleMascot(BuildContext context) => null;

  /// Rides the end of the XP bar's fill.
  Widget? xpRunner(BuildContext context) => null;

  /// Before the gold amount.
  Widget? goldIcon(BuildContext context) => null;

  /// Replaces the change-request FAB's icon (and its colours).
  Widget? fabFace(BuildContext context) => null;

  /// Before a trait's name in a trait pill.
  Widget? traitLeading(BuildContext context) => null;

  /// Holds a trait's value in place of the bold text; null keeps the text.
  Widget? traitValue(BuildContext context, String value) => null;

  /// How an achievement badge is drawn.
  BadgeShape get badgeShape => BadgeShape.medal;

  /// Under a badge in the card section and the gallery.
  Widget? badgeNest(BuildContext context, double width) => null;

  /// Stages the big badge on its detail screen; the base shows it alone.
  Widget badgeHero(BuildContext context, Widget badge) => badge;

  /// What holds the electronics count.
  MedallionShape get medallionShape => MedallionShape.ring;

  /// A count shown in an egg (the quests summary); null keeps the disk.
  Widget? countEgg(BuildContext context, int count) => null;

  /// Paints the scaffold behind [child]; the base leaves it plain.
  Widget backdrop(BuildContext context, Widget child) => child;

  /// Bands stitched like a leather collar: a dashed seam along each long
  /// edge (see [Stitched]).
  bool get stitchedBands => false;
}

class KronikaDecor extends RpgDecor {
  const KronikaDecor();
}

/// The assets under assets/kurczaki/.
enum Kurczak {
  hen('hen'),
  henBrown('hen_brown'),
  henPerched('hen_perched'),
  henLogo('hen_logo'),
  henNest('hen_nest'),
  henHero('hen_hero'),
  rooster('rooster'),
  roosterLight('rooster_light'),
  chick('chick'),
  chickPeck('chick_peck'),
  chickGlyph('chick_glyph'),
  chickFlat('chick_flat'),
  chickHead('chick_head'),
  chickFace('chick_face'),
  footprint('footprint'),
  eggGold('egg_gold'),
  eggPlain('egg_plain'),
  feather('feather'),
  nest('nest'),
  grain('grain'),
  grass('grass'),
  fence('fence');

  const Kurczak(this.file);

  final String file;

  String get asset => 'assets/kurczaki/$file.svg';
}

/// One Kurczaki illustration. [flip] mirrors it (facing left), [turns]
/// tilts it (a pecking chick) -- both purely visual.
class KurczakArt extends StatelessWidget {
  const KurczakArt(
    this.art, {
    super.key,
    this.width,
    this.height,
    this.flip = false,
    this.turns = 0,
    this.fit = BoxFit.contain,
    this.label,
  });

  final Kurczak art;
  final double? width;
  final double? height;
  final bool flip;
  final double turns;
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
      excludeFromSemantics: label == null,
      semanticsLabel: label,
    );
    if (turns != 0) {
      picture = RotationTransition(
        turns: AlwaysStoppedAnimation(turns),
        child: picture,
      );
    }
    if (flip) picture = Transform.flip(flipX: true, child: picture);
    return picture;
  }
}

class KurczakiDecor extends RpgDecor {
  const KurczakiDecor();

  @override
  Widget dividerGlyph(BuildContext context, Color color) =>
      const KurczakArt(Kurczak.chickGlyph, width: 22, height: 21);

  @override
  Widget cornerOrnament(BuildContext context) =>
      const KurczakArt(Kurczak.footprint, width: 16, height: 16);

  @override
  Widget ornamentedLabel(
    BuildContext context,
    String text,
    TextStyle style, {
    BandOrnament ornament = BandOrnament.star,
    TextAlign textAlign = TextAlign.center,
  }) {
    final size = (style.fontSize ?? 12) + 4;
    final Widget? glyph = switch (ornament) {
      BandOrnament.none => null,
      BandOrnament.star => KurczakArt(
        Kurczak.chickHead,
        width: size,
        height: size,
      ),
      BandOrnament.cycle => Icon(
        Icons.autorenew,
        size: size,
        color: style.color,
      ),
    };
    final label = Flexible(
      child: Text(text, style: style, textAlign: textAlign),
    );
    if (glyph == null) return Text(text, style: style, textAlign: textAlign);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        glyph,
        const SizedBox(width: 8),
        label,
        const SizedBox(width: 8),
        glyph,
      ],
    );
  }

  @override
  Widget bottomBandContent(BuildContext context, String? label) {
    const chick = KurczakArt(Kurczak.chickFlat, width: 16, height: 15);
    if (label == null) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [chick, SizedBox(width: 6), chick, SizedBox(width: 6), chick],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chick,
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: context.rpg.fontDisplay,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
            height: 1,
            color: context.rpg.bandLabelColor,
          ),
        ),
        const SizedBox(width: 8),
        chick,
      ],
    );
  }

  @override
  Widget loginEmblem(BuildContext context) => const LivelyKurczak(
    Kurczak.henHero,
    voice: KurczakVoice.hen,
    width: 150,
    height: 150,
    label: 'Kura',
  );

  @override
  Widget? logoMark(BuildContext context) =>
      const KurczakArt(Kurczak.henLogo, width: 34, height: 32);

  @override
  Widget? loginScene(BuildContext context) => const _LoginYard();

  @override
  Perch? perch(BuildContext context, PerchSpot spot) => switch (spot) {
    PerchSpot.characterCard => const Perch(
      art: _CardRoost(),
      rise: 92,
      inset: 0,
    ),
    PerchSpot.questsSummary => const Perch(
      art: LivelyKurczak(
        Kurczak.chick,
        voice: KurczakVoice.chick,
        width: 36,
        height: 34,
      ),
      rise: 31,
      inset: 56,
    ),
    PerchSpot.questCard => const Perch(
      art: LivelyKurczak(
        Kurczak.chick,
        voice: KurczakVoice.chick,
        width: 44,
        height: 42,
        flip: true,
      ),
      rise: 39,
      inset: 26,
    ),
    PerchSpot.dailyQuest => const Perch(
      art: LivelyKurczak(
        Kurczak.henPerched,
        voice: KurczakVoice.hen,
        width: 74,
        height: 68,
      ),
      rise: 64,
      inset: 12,
      left: true,
    ),
    PerchSpot.achievementsSummary => const Perch(
      art: LivelyKurczak(
        Kurczak.hen,
        voice: KurczakVoice.hen,
        width: 70,
        height: 64,
      ),
      rise: 60,
      inset: 14,
    ),
  };

  @override
  Widget? footerScene(BuildContext context, FooterScene scene) =>
      _Meadow(scene: scene);

  @override
  Widget? questsTitleMascot(BuildContext context) => const LivelyKurczak(
    Kurczak.roosterLight,
    voice: KurczakVoice.rooster,
    width: 46,
    height: 42,
  );

  @override
  Widget? xpRunner(BuildContext context) =>
      const KurczakArt(Kurczak.chick, width: 30, height: 29);

  @override
  Widget? goldIcon(BuildContext context) =>
      const KurczakArt(Kurczak.eggGold, width: 18, height: 18);

  @override
  Widget? fabFace(BuildContext context) =>
      const KurczakArt(Kurczak.chickFace, width: 46, height: 46);

  @override
  Widget? traitLeading(BuildContext context) =>
      const KurczakArt(Kurczak.feather, width: 12, height: 12);

  @override
  Widget? traitValue(BuildContext context, String value) => value.length > 3
      // A long, free-text legacy value would shrink to nothing in an egg.
      ? null
      : _EggNumber(value: value, width: 18, height: 22, fontSize: 11);

  @override
  BadgeShape get badgeShape => BadgeShape.egg;

  @override
  Widget? badgeNest(BuildContext context, double width) => KurczakArt(
    Kurczak.nest,
    width: width,
    height: width / 4,
    fit: BoxFit.fill,
  );

  @override
  Widget badgeHero(BuildContext context, Widget badge) => SizedBox(
    height: 244,
    child: Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 0,
          bottom: 4,
          child: LivelyKurczak(
            Kurczak.hen,
            voice: KurczakVoice.hen,
            width: 88,
            height: 80,
            label: 'Dumna kura',
          ),
        ),
        const Positioned(
          right: 12,
          bottom: 6,
          child: LivelyKurczak(
            Kurczak.chick,
            voice: KurczakVoice.chick,
            width: 46,
            height: 44,
            flip: true,
          ),
        ),
        Positioned(bottom: 22, child: badge),
        const Positioned(
          bottom: 0,
          child: KurczakArt(
            Kurczak.nest,
            width: 170,
            height: 42,
            fit: BoxFit.fill,
          ),
        ),
      ],
    ),
  );

  @override
  MedallionShape get medallionShape => MedallionShape.egg;

  @override
  Widget? countEgg(BuildContext context, int count) => _EggNumber(
    value: '$count',
    width: 30,
    height: 36,
    fontSize: 20,
    outline: context.rpg.parchmentLight,
  );

  @override
  Widget backdrop(BuildContext context, Widget child) =>
      CustomPaint(painter: const _StrawPainter(), child: child);
}

/// The shape every Kurczaki egg shares, on a 52×62 grid: a pointed top and
/// a half-circle base of radius 21 centred at (26, 38).
Path eggPath(Size size) {
  final sx = size.width / 52, sy = size.height / 62;
  return Path()
    ..moveTo(26 * sx, 4 * sy)
    ..cubicTo(13 * sx, 4 * sy, 5 * sx, 25 * sy, 5 * sx, 38 * sy)
    ..arcToPoint(
      Offset(47 * sx, 38 * sy),
      radius: Radius.elliptical(21 * sx, 21 * sy),
      clockwise: false,
    )
    ..cubicTo(47 * sx, 25 * sy, 39 * sx, 4 * sy, 26 * sx, 4 * sy)
    ..close();
}

/// A value written in a yolk-yellow egg (trait values, the quests count).
class _EggNumber extends StatelessWidget {
  const _EggNumber({
    required this.value,
    required this.width,
    required this.height,
    required this.fontSize,
    this.outline,
  });

  final String value;
  final double width;
  final double height;
  final double fontSize;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _EggFillPainter(
          fill: const Color(0xFFFFC83D),
          stroke: outline ?? t.crimson,
        ),
        child: Padding(
          padding: EdgeInsets.only(top: height * 0.3),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  fontFamily: t.fontDisplay,
                  fontWeight: FontWeight.w600,
                  fontSize: fontSize,
                  height: 1,
                  color: t.inkHeading,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EggFillPainter extends CustomPainter {
  const _EggFillPainter({required this.fill, required this.stroke});

  final Color fill;
  final Color stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final egg = eggPath(size);
    canvas.drawPath(egg, Paint()..color = fill);
    canvas.drawPath(
      egg,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_EggFillPainter old) =>
      old.fill != fill || old.stroke != stroke;
}

/// Straw: the scaffold colour with a fine grid of darker dots.
class _StrawPainter extends CustomPainter {
  const _StrawPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = const Color(0xFFF2CF6B);
    for (var y = 9.0; y < size.height; y += 18) {
      for (var x = 9.0; x < size.width; x += 18) {
        canvas.drawCircle(Offset(x, y), 1.3, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_StrawPainter old) => false;
}

/// The hen on her nest plus a chick, riding the character card's top edge.
class _CardRoost extends StatelessWidget {
  const _CardRoost();

  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 300,
    height: 96,
    child: Stack(
      children: [
        Positioned(
          left: 18,
          bottom: 0,
          child: LivelyKurczak(
            Kurczak.chick,
            voice: KurczakVoice.chick,
            width: 44,
            height: 42,
            label: 'Pisklak',
          ),
        ),
        Positioned(
          right: 14,
          top: 0,
          child: LivelyKurczak(
            Kurczak.henNest,
            voice: KurczakVoice.hen,
            width: 104,
            height: 96,
            label: 'Kura wysiadująca jajka',
          ),
        ),
      ],
    ),
  );
}

/// Grass with a hen and her chicks, closing a list.
class _Meadow extends StatelessWidget {
  const _Meadow({required this.scene});

  final FooterScene scene;

  @override
  Widget build(BuildContext context) {
    final cast = switch (scene) {
      FooterScene.home => const [
        Positioned(
          left: 14,
          bottom: 26,
          child: LivelyKurczak(
            Kurczak.chick,
            voice: KurczakVoice.chick,
            runs: true,
            width: 32,
            height: 30,
          ),
        ),
        Positioned(
          left: 56,
          bottom: 22,
          child: LivelyKurczak(
            Kurczak.chickPeck,
            voice: KurczakVoice.chick,
            runs: true,
            width: 36,
            height: 34,
            turns: 0.06,
          ),
        ),
        Positioned(
          left: 92,
          bottom: 22,
          child: KurczakArt(Kurczak.grain, width: 20, height: 8),
        ),
        Positioned(
          left: 100,
          bottom: 26,
          child: LivelyKurczak(
            Kurczak.chick,
            voice: KurczakVoice.chick,
            runs: true,
            width: 40,
            height: 38,
          ),
        ),
        Positioned(
          left: 150,
          bottom: 26,
          child: LivelyKurczak(
            Kurczak.henBrown,
            voice: KurczakVoice.hen,
            width: 96,
            height: 88,
            label: 'Kura z pisklętami',
          ),
        ),
      ],
      FooterScene.quests => const [
        Positioned(
          left: 20,
          bottom: 24,
          child: LivelyKurczak(
            Kurczak.hen,
            voice: KurczakVoice.hen,
            width: 92,
            height: 84,
            turns: 0.04,
            label: 'Kury dziobią ziarno',
          ),
        ),
        Positioned(
          left: 116,
          bottom: 22,
          child: KurczakArt(Kurczak.grain, width: 34, height: 10),
        ),
        Positioned(
          left: 150,
          bottom: 22,
          child: LivelyKurczak(
            Kurczak.chickPeck,
            voice: KurczakVoice.chick,
            runs: true,
            width: 36,
            height: 34,
            flip: true,
            turns: -0.06,
          ),
        ),
        Positioned(
          left: 196,
          bottom: 26,
          child: LivelyKurczak(
            Kurczak.chick,
            voice: KurczakVoice.chick,
            runs: true,
            width: 40,
            height: 38,
          ),
        ),
        Positioned(
          right: 16,
          bottom: 24,
          child: LivelyKurczak(
            Kurczak.henBrown,
            voice: KurczakVoice.hen,
            width: 92,
            height: 84,
            flip: true,
          ),
        ),
      ],
      FooterScene.achievements => const [
        Positioned(
          left: 70,
          bottom: 26,
          child: LivelyKurczak(
            Kurczak.chick,
            voice: KurczakVoice.chick,
            runs: true,
            width: 40,
            height: 38,
          ),
        ),
        Positioned(
          left: 172,
          bottom: 22,
          child: KurczakArt(Kurczak.eggPlain, width: 44, height: 54),
        ),
        Positioned(
          left: 260,
          bottom: 26,
          child: LivelyKurczak(
            Kurczak.chick,
            voice: KurczakVoice.chick,
            runs: true,
            width: 40,
            height: 38,
            flip: true,
            label: 'Pisklęta podziwiają jajko',
          ),
        ),
      ],
    };
    return SizedBox(
      height: 124,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(
            left: -16,
            right: -16,
            bottom: 0,
            height: 46,
            child: KurczakArt(Kurczak.grass, fit: BoxFit.fill),
          ),
          ...cast,
        ],
      ),
    );
  }
}

/// The fence, the crowing rooster and a hen leading her chicks, along the
/// foot of the login screen.
class _LoginYard extends StatelessWidget {
  const _LoginYard();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 190,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 110,
          child: KurczakArt(Kurczak.fence, fit: BoxFit.fill),
        ),
        Positioned(
          left: -4,
          bottom: 82,
          child: LivelyKurczak(
            Kurczak.rooster,
            voice: KurczakVoice.rooster,
            width: 96,
            height: 88,
            label: 'Kogut pieje',
          ),
        ),
        Positioned(
          right: 20,
          bottom: 6,
          child: LivelyKurczak(
            Kurczak.henBrown,
            voice: KurczakVoice.hen,
            width: 84,
            height: 78,
            label: 'Kura prowadzi pisklęta',
          ),
        ),
        Positioned(
          right: 112,
          bottom: 8,
          child: LivelyKurczak(
            Kurczak.chick,
            voice: KurczakVoice.chick,
            runs: true,
            width: 38,
            height: 36,
          ),
        ),
        Positioned(
          right: 160,
          bottom: 6,
          child: LivelyKurczak(
            Kurczak.chick,
            voice: KurczakVoice.chick,
            runs: true,
            width: 34,
            height: 32,
          ),
        ),
        Positioned(
          right: 204,
          bottom: 4,
          child: LivelyKurczak(
            Kurczak.chickPeck,
            voice: KurczakVoice.chick,
            runs: true,
            width: 30,
            height: 28,
            turns: 0.06,
          ),
        ),
      ],
    ),
  );
}
