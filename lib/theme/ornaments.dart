import 'package:flutter/material.dart';

import 'app_theme.dart';

/// A horizontal rule broken by a ✦, fading out towards the ends.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key, this.color = crimson, this.width = 120});

  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget line(bool leftToRight) => Container(
          width: width / 2,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: leftToRight
                  ? [const Color(0x00000000), color]
                  : [color, const Color(0x00000000)],
            ),
          ),
        );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        line(true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('✦', style: TextStyle(fontSize: 10, color: color)),
        ),
        line(false),
      ],
    );
  }
}

/// The ❧ leaf that sits in the corners of a framed card.
class CornerOrnament extends StatelessWidget {
  const CornerOrnament({super.key, this.mirrored = false});

  final bool mirrored;

  @override
  Widget build(BuildContext context) {
    const glyph = Text(
      '❧',
      style: TextStyle(fontSize: 12, color: ornamentInk, height: 1),
    );
    // Always wrapped, so the widget tree has the same shape either way.
    return Transform.scale(scaleX: mirrored ? -1 : 1, child: glyph);
  }
}

/// The crimson band across the top of a card, with an optional trailing action.
class TopBand extends StatelessWidget {
  const TopBand({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: bandGradient),
      padding: const EdgeInsets.fromLTRB(16, 7, 8, 7),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: fontDisplay,
                fontSize: 8,
                letterSpacing: 4,
                color: Color(0xD9F5E8D0),
              ),
            ),
          ),
          SizedBox(width: 32, child: trailing),
        ],
      ),
    );
  }
}

/// The closing rule at the foot of a card.
class BottomBand extends StatelessWidget {
  const BottomBand({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: bandGradient),
      padding: const EdgeInsets.symmetric(vertical: 5),
      alignment: Alignment.center,
      child: const Text(
        '— ✦ —',
        style: TextStyle(fontSize: 9, color: parchmentMuted, height: 1),
      ),
    );
  }
}
