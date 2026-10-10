import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/electronics_days.dart';
import '../../theme/app_theme.dart';
import '../../theme/decor.dart' show MedallionShape, eggPath;
import '../../theme/lagotto_decor.dart' show pawPadPath, pawToePaths;
import '../../theme/ornaments.dart';

TextStyle _headline(BuildContext context) => TextStyle(
  fontFamily: context.rpg.fontBody,
  fontSize: 14,
  fontWeight: FontWeight.w700,
  fontStyle: FontStyle.italic,
  color: context.rpg.inkHeading,
);

TextStyle _status(BuildContext context) => TextStyle(
  fontFamily: context.rpg.fontBody,
  fontSize: 10,
  fontStyle: FontStyle.italic,
  color: context.rpg.crimson,
);

TextStyle _buttonText(BuildContext context) => TextStyle(
  fontFamily: context.rpg.fontDisplay,
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
            backgroundColor: context.rpg.actionFill,
            foregroundColor: context.rpg.onActionFill,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.rpg.buttonRadius),
              side: BorderSide(color: context.rpg.actionBorder),
            ),
          ),
          child: Text('Odbierz'.toUpperCase(), style: _buttonText(context)),
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
              foregroundColor: context.rpg.crimson,
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              side: BorderSide(color: context.rpg.crimson),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.rpg.buttonRadius),
              ),
            ),
            child: Text('Anuluj'.toUpperCase(), style: _buttonText(context)),
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
                  Text(headline, style: _headline(context)),
                  const SizedBox(height: 2),
                  Text(status, style: _status(context)),
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
    final t = context.rpg;
    final badge = switch (state) {
      ElectronicsCardState.pending =>
        (t.gold, t.inkHeading, Icons.hourglass_bottom),
      ElectronicsCardState.claimed => (t.crimson, t.parchmentLight, Icons.close),
      _ => null,
    };
    final shape = t.decor.medallionShape;
    final egg = shape == MedallionShape.egg;

    return SizedBox(
      key: const Key('electronics-ring'),
      width: egg ? 46 : 52,
      height: egg ? 56 : 52,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: switch (shape) {
                MedallionShape.egg => _EggPainter(fraction: dayFraction, state: state, theme: t),
                MedallionShape.paw => _PawPainter(fraction: dayFraction, state: state, theme: t),
                MedallionShape.ring => _RingPainter(fraction: dayFraction, state: state, theme: t),
              },
            ),
          ),
          if (egg)
            // The thin Fredoka Light digit fills the egg yet lets the yolk
            // level show through its strokes.
            Positioned(
              left: 4,
              right: 4,
              top: 10,
              bottom: 2,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$available',
                  key: const Key('electronics-count'),
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 46,
                    fontWeight: FontWeight.w300,
                    height: 1,
                    color: t.inkHeading,
                  ),
                ),
              ),
            )
          else if (shape == MedallionShape.paw)
            // The count sits on the paw's main pad.
            Positioned(
              left: 13,
              right: 13,
              top: 27,
              bottom: 7,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$available',
                  key: const Key('electronics-count'),
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    fontFamily: t.fontDisplay,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: t.inkHeading,
                  ),
                ),
              ),
            )
          else
            Positioned(
              left: 5,
              top: 5,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.crimsonFaint,
                  border: Border.all(color: t.crimson, width: 2),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.all(6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$available',
                    key: const Key('electronics-count'),
                    style: TextStyle(
                      fontFamily: t.fontDisplay,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1,
                      color: t.inkHeading,
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
                  border: Border.all(color: t.parchmentLight, width: 1.5),
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
  _RingPainter({required this.fraction, required this.state, required this.theme});

  final double fraction;
  final ElectronicsCardState state;
  final RpgTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (state == ElectronicsCardState.claimed) {
      final dash = Paint()
        ..color = theme.crimsonBorder
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
        ..color = theme.crimsonBorderFaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * fraction.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = state == ElectronicsCardState.pending ? theme.ornamentInk : theme.gold
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.state != state || old.theme != theme;
}

/// Kurczaki's medallion: an eggshell that fills with yolk from the bottom
/// over the day (paler while a claim is pending), drawn with a dashed shell
/// and no yolk once today is claimed.
class _EggPainter extends CustomPainter {
  _EggPainter({required this.fraction, required this.state, required this.theme});

  final double fraction;
  final ElectronicsCardState state;
  final RpgTheme theme;

  static const _yolk = Color(0xFFFFD95A);

  @override
  void paint(Canvas canvas, Size size) {
    final egg = eggPath(size);
    canvas.drawPath(egg, Paint()..color = theme.parchmentLight);

    if (state != ElectronicsCardState.claimed) {
      final bounds = egg.getBounds();
      final level = bounds.bottom - bounds.height * fraction.clamp(0.0, 1.0);
      canvas.save();
      canvas.clipPath(egg);
      canvas.drawRect(
        Rect.fromLTRB(0, level, size.width, size.height),
        Paint()
          ..color = state == ElectronicsCardState.pending
              ? _yolk.withValues(alpha: 0.45)
              : _yolk,
      );
      canvas.restore();
    }

    final shell = Paint()
      ..color = state == ElectronicsCardState.claimed ? theme.crimsonBorder : theme.crimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    if (state == ElectronicsCardState.claimed) {
      for (final metric in egg.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 7) {
          canvas.drawPath(metric.extractPath(d, d + 3.5), shell);
        }
      }
    } else {
      canvas.drawPath(egg, shell);
    }
  }

  @override
  bool shouldRepaint(_EggPainter old) =>
      old.fraction != fraction || old.state != state || old.theme != theme;
}

/// Lagotto's medallion: a paw print whose main pad fills with orange from
/// the bottom over the day (paler while a claim is pending), drawn dashed
/// and empty once today is claimed.
class _PawPainter extends CustomPainter {
  _PawPainter({required this.fraction, required this.state, required this.theme});

  final double fraction;
  final ElectronicsCardState state;
  final RpgTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    final claimed = state == ElectronicsCardState.claimed;
    final pad = pawPadPath(size);
    final outline = Paint()
      ..color = claimed ? theme.crimsonBorder : theme.crimson
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    void stroke(Path path) {
      if (!claimed) {
        canvas.drawPath(path, outline);
        return;
      }
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 6) {
          canvas.drawPath(metric.extractPath(d, d + 3), outline);
        }
      }
    }

    for (final toe in pawToePaths(size)) {
      canvas.drawPath(toe, Paint()..color = theme.parchmentLight);
      stroke(toe);
    }
    canvas.drawPath(pad, Paint()..color = theme.parchmentLight);
    if (!claimed) {
      final bounds = pad.getBounds();
      final level = bounds.bottom - bounds.height * fraction.clamp(0.0, 1.0);
      canvas.save();
      canvas.clipPath(pad);
      canvas.drawRect(
        Rect.fromLTRB(0, level, size.width, size.height),
        Paint()
          ..color = theme.gold.withValues(
              alpha: state == ElectronicsCardState.pending ? 0.3 : 0.7),
      );
      canvas.restore();
    }
    stroke(pad);
  }

  @override
  bool shouldRepaint(_PawPainter old) =>
      old.fraction != fraction || old.state != state || old.theme != theme;
}
