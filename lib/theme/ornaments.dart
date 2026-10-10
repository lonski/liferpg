import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'decor.dart';

export 'decor.dart' show BandOrnament, FooterScene, PerchSpot;

/// A horizontal rule broken by the theme's glyph (✦ in Kronika), fading out
/// towards the ends.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({
    super.key,
    this.color,
    this.glyphColor,
    this.width = 120,
  });

  /// Defaults to the theme's crimson.
  final Color? color;

  /// Colour of the glyph, when it differs from the line colour (e.g. the
  /// Login screen's gold divider uses a different alpha for each).
  /// Defaults to [color].
  final Color? glyphColor;
  final double width;

  @override
  Widget build(BuildContext context) {
    final lineColor = color ?? context.rpg.crimson;
    Widget line(bool leftToRight) => Container(
          width: width / 2,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: leftToRight
                  ? [const Color(0x00000000), lineColor]
                  : [lineColor, const Color(0x00000000)],
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: context.rpg.decor.dividerGlyph(context, glyphColor ?? lineColor),
        ),
        line(false),
      ],
    );
  }
}

/// The ornament that sits in the corners of a framed card (❧ in Kronika).
class CornerOrnament extends StatelessWidget {
  const CornerOrnament({super.key, this.mirrored = false});

  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    // Always wrapped, so the widget tree has the same shape either way.
    return Transform.scale(
      scaleX: mirrored ? -1 : 1,
      child: context.rpg.decor.cornerOrnament(context),
    );
  }
}

/// [text] upper-cased between the theme's glyphs -- `✦ TEXT ✦` in Kronika.
class OrnamentedLabel extends StatelessWidget {
  const OrnamentedLabel(
    this.text, {
    super.key,
    required this.style,
    this.ornament = BandOrnament.star,
  });

  final String text;
  final TextStyle style;
  final BandOrnament ornament;

  @override
  Widget build(BuildContext context) => context.rpg.decor.ornamentedLabel(
        context,
        text.toUpperCase(),
        style,
        ornament: ornament,
      );
}

/// The crimson band across the top of a card, with an optional trailing
/// action. [gradient]/[labelColor] default to the ordinary band -- a daily
/// quest's [QuestCard] passes the gold variants instead, so its band reads
/// as visually distinct at a glance. [ornament] flanks the label with the
/// theme's glyphs.
class TopBand extends StatelessWidget {
  const TopBand({
    super.key,
    required this.label,
    this.ornament = BandOrnament.none,
    this.trailing,
    this.gradient,
    this.labelColor,
  });

  final String label;
  final BandOrnament ornament;
  final Widget? trailing;
  final Gradient? gradient;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    return Container(
      decoration: BoxDecoration(gradient: gradient ?? t.bandGradient),
      padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Center(
              child: t.decor.ornamentedLabel(
                context,
                label.toUpperCase(),
                TextStyle(
                  fontFamily: t.fontDisplay,
                  fontSize: 12,
                  fontWeight: t.id == AppThemeId.kronika ? null : FontWeight.w600,
                  letterSpacing: 4,
                  color: labelColor ?? t.bandLabelColor,
                ),
                ornament: ornament,
              ),
            ),
          ),
          SizedBox(width: 32, child: trailing),
        ],
      ),
    );
  }
}

/// The closing rule at the foot of a card; [label] is written into it
/// (`— ✦ LIFERPG ✦ —` in Kronika).
class BottomBand extends StatelessWidget {
  const BottomBand({super.key, this.label, this.gradient});

  final String? label;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: gradient ?? context.rpg.bandGradient),
      padding: const EdgeInsets.symmetric(vertical: 5),
      alignment: Alignment.center,
      child: context.rpg.decor.bottomBandContent(context, label),
    );
  }
}

/// A centred label between two hairlines -- the Cechy / Dni elektroniki
/// section headings on the character card.
class LabelledDivider extends StatelessWidget {
  const LabelledDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Divider(color: context.rpg.crimsonBorderStrong, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(label.toUpperCase(), style: context.rpg.traitsDividerLabel),
          ),
          Expanded(child: Divider(color: context.rpg.crimsonBorderStrong, height: 1)),
        ],
      );
}

/// [child] with the theme's illustration for [spot] seated on its top edge
/// (nothing in Kronika). The illustration never takes taps -- it must not
/// shadow a band's edit button.
class Perched extends StatelessWidget {
  const Perched({super.key, required this.spot, required this.child});

  final PerchSpot spot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final perch = context.rpg.decor.perch(context, spot);
    if (perch == null) return child;
    return Padding(
      padding: EdgeInsets.only(top: perch.rise),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          Positioned(
            top: -perch.rise,
            left: perch.left ? perch.inset : null,
            right: perch.left ? null : perch.inset,
            child: IgnorePointer(child: ExcludeSemantics(child: perch.art)),
          ),
        ],
      ),
    );
  }
}

/// The theme's scene closing a list (nothing in Kronika).
class FooterSceneView extends StatelessWidget {
  const FooterSceneView(this.scene, {super.key});

  final FooterScene scene;

  @override
  Widget build(BuildContext context) =>
      context.rpg.decor.footerScene(context, scene) ?? const SizedBox.shrink();
}

/// Paints the theme's scaffold backdrop (straw in Kurczaki) behind [child].
class ThemeBackdrop extends StatelessWidget {
  const ThemeBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => context.rpg.decor.backdrop(context, child);
}
