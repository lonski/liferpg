import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/electronics_days.dart';
import '../../theme/app_theme.dart';
import '../../theme/ornaments.dart';

const TextStyle _headline = TextStyle(
  fontFamily: fontBody,
  fontSize: 14,
  fontWeight: FontWeight.w700,
  fontStyle: FontStyle.italic,
  color: inkHeading,
);

const TextStyle _status = TextStyle(
  fontFamily: fontBody,
  fontSize: 10,
  fontStyle: FontStyle.italic,
  color: crimson,
);

const TextStyle _buttonText = TextStyle(
  fontFamily: fontDisplay,
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 2,
);

/// The "Dni elektroniki" block on a character card: one row with a small ring
/// medallion (the available count), today's state, and at most one compact
/// action at the right. Purely presentational -- ElectronicsPanel decides the
/// state and the callbacks.
class ElectronicsSection extends StatelessWidget {
  const ElectronicsSection({
    super.key,
    required this.available,
    required this.state,
    required this.dayFraction,
    this.onClaim,
    this.onCancel,
  });

  final int available;
  final ElectronicsCardState state;

  /// Elapsed share of the local day, drawn as the ring's arc.
  final double dayFraction;

  /// Shown as ODBIERZ only in the charging state.
  final VoidCallback? onClaim;

  /// Shown as ANULUJ PROŚBĘ only in the pending state.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final (headline, status) = switch (state) {
      ElectronicsCardState.charging ||
      ElectronicsCardState.empty =>
        ('Ładowanie…', 'dzień bez elektroniki'),
      ElectronicsCardState.pending =>
        ('Dzień z elektroniką?', 'czeka na akceptację'),
      ElectronicsCardState.claimed =>
        ('Dzień z elektroniką', 'odebrano dzisiaj'),
    };

    final Widget? action = switch (state) {
      ElectronicsCardState.charging when onClaim != null => FilledButton(
          key: const Key('electronics-claim'),
          onPressed: onClaim,
          style: FilledButton.styleFrom(
            backgroundColor: crimson,
            foregroundColor: parchmentLight,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
              side: const BorderSide(color: goldGlyph),
            ),
          ),
          child: Text('Odbierz'.toUpperCase(), style: _buttonText),
        ),
      // The full "Anuluj prośbę" would squeeze the status text on narrow
      // screens now that the button shares the ring's row; it lives on in
      // the tooltip.
      ElectronicsCardState.pending when onCancel != null => Tooltip(
          message: 'Anuluj prośbę',
          child: OutlinedButton(
            key: const Key('electronics-cancel'),
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: crimson,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: const BorderSide(color: crimson),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            child: Text('Anuluj'.toUpperCase(), style: _buttonText),
          ),
        ),
      _ => null,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LabelledDivider(label: 'Dni elektroniki'),
        const SizedBox(height: 10),
        Row(
          children: [
            _Medallion(
              available: available,
              state: state,
              dayFraction: dayFraction,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(headline, style: _headline),
                  const SizedBox(height: 2),
                  Text(status, style: _status),
                ],
              ),
            ),
            if (action != null) ...[const SizedBox(width: 8), action],
          ],
        ),
      ],
    );
  }
}

class _Medallion extends StatelessWidget {
  const _Medallion({
    required this.available,
    required this.state,
    required this.dayFraction,
  });

  final int available;
  final ElectronicsCardState state;
  final double dayFraction;

  @override
  Widget build(BuildContext context) {
    final badge = switch (state) {
      ElectronicsCardState.pending =>
        (gold, inkHeading, Icons.hourglass_bottom),
      ElectronicsCardState.claimed => (crimson, parchmentLight, Icons.close),
      _ => null,
    };

    return SizedBox(
      key: const Key('electronics-ring'),
      width: 52,
      height: 52,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(fraction: dayFraction, state: state),
            ),
          ),
          Positioned(
            left: 5,
            top: 5,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: crimsonFaint,
                border: Border.all(color: crimson, width: 2),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$available',
                  key: const Key('electronics-count'),
                  style: const TextStyle(
                    fontFamily: fontDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: inkHeading,
                  ),
                ),
              ),
            ),
          ),
          if (badge != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: badge.$1,
                  border: Border.all(color: parchmentLight, width: 1.5),
                ),
                child: Icon(badge.$3, size: 9, color: badge.$2),
              ),
            ),
        ],
      ),
    );
  }
}

/// The track plus today's arc: gold while charging, faded crimson while a
/// claim is pending, and a dashed crimson circle once today is claimed.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.state});

  final double fraction;
  final ElectronicsCardState state;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (state == ElectronicsCardState.claimed) {
      final dash = Paint()
        ..color = crimsonBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      const segments = 32;
      const sweep = 2 * math.pi / segments;
      for (var i = 0; i < segments; i++) {
        canvas.drawArc(rect, i * sweep, sweep * 0.45, false, dash);
      }
      return;
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = crimsonBorderFaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = state == ElectronicsCardState.pending ? ornamentInk : gold
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.state != state;
}
