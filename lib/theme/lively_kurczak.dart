import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'decor.dart';
import 'rpg_theme.dart';

/// Which voice a tapped bird answers in.
enum KurczakVoice { hen, rooster, chick }

/// A Kurczaki illustration that reacts to a tap: it hops (or, with [runs],
/// a chick scurries aside and back), says something in a speech bubble and
/// buzzes lightly. A hen tapped five times in quick succession lays a
/// golden egg that rolls away -- a secret for the kids to find.
///
/// Purely decorative: no state outlives the animation, nothing is written.
class LivelyKurczak extends StatefulWidget {
  const LivelyKurczak(
    this.art, {
    super.key,
    required this.voice,
    required this.width,
    required this.height,
    this.flip = false,
    this.turns = 0,
    this.runs = false,
    this.label,
  });

  final Kurczak art;
  final KurczakVoice voice;
  final double width;
  final double height;
  final bool flip;
  final double turns;

  /// Scurry sideways and back instead of hopping (chicks on the grass).
  final bool runs;
  final String? label;

  /// Taps this close together count towards the hidden egg.
  static const eggTapWindow = Duration(milliseconds: 700);

  /// How many quick taps make a hen lay.
  static const eggTaps = 5;

  static const _lines = {
    KurczakVoice.hen: ['Ko-ko!', 'Ko-ko-ko!', 'Kooo?'],
    KurczakVoice.rooster: ['Kukuryku!', 'Ku-ku-ryku!'],
    KurczakVoice.chick: ['Pi-pi!', 'Pip!', 'Piii!'],
  };

  /// Every line [voice] may say (tests look the bubble up by these).
  static List<String> linesOf(KurczakVoice voice) => _lines[voice]!;

  static const eggLine = 'Ko-ko-KOOO!';

  @override
  State<LivelyKurczak> createState() => _LivelyKurczakState();
}

class _LivelyKurczakState extends State<LivelyKurczak>
    with TickerProviderStateMixin {
  late final _move = AnimationController(vsync: this);
  late final _bubble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final _egg = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  final _random = math.Random();

  String? _line;
  int _quickTaps = 0;

  /// Forgets the quick-tap run once [LivelyKurczak.eggTapWindow] passes
  /// without another tap (a timer rather than wall-clock reads, so the run
  /// is driven by the same fake time as every other animation in tests).
  Timer? _tapRunReset;

  @override
  void dispose() {
    _tapRunReset?.cancel();
    _move.dispose();
    _bubble.dispose();
    _egg.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _quickTaps++;
    _tapRunReset?.cancel();
    _tapRunReset = Timer(LivelyKurczak.eggTapWindow, () => _quickTaps = 0);

    final lays =
        widget.voice == KurczakVoice.hen &&
        _quickTaps >= LivelyKurczak.eggTaps &&
        !_egg.isAnimating;
    if (lays) {
      _quickTaps = 0;
      _egg.forward(from: 0);
    }

    final lines = LivelyKurczak.linesOf(widget.voice);
    setState(
      () => _line = lays
          ? LivelyKurczak.eggLine
          : lines[_random.nextInt(lines.length)],
    );
    _bubble.forward(from: 0);

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _move
      ..duration = Duration(milliseconds: widget.runs ? 900 : 450)
      ..forward(from: 0);
  }

  /// How far a running chick is from its spot at run progress [t]: out
  /// and back, the way it faces.
  double _runOffset(double t) =>
      (widget.flip ? -1.0 : 1.0) * 56 * math.sin(math.pi * t);

  @override
  Widget build(BuildContext context) {
    final art = KurczakArt(
      widget.art,
      width: widget.width,
      height: widget.height,
      flip: widget.flip,
      turns: widget.turns,
      label: widget.label,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _move,
              builder: (context, child) {
                final t = _move.value;
                if (t == 0 || t == 1) return child!;
                if (widget.runs) {
                  // Out and back, facing the way it runs.
                  return Transform.translate(
                    offset: Offset(
                      _runOffset(t),
                      -3 * (math.sin(t * math.pi * 8)).abs(),
                    ),
                    child: Transform.flip(flipX: t > 0.5, child: child),
                  );
                }
                return Transform.translate(
                  offset: Offset(0, -12 * math.sin(math.pi * t)),
                  child: Transform.rotate(
                    angle: 0.18 * math.sin(math.pi * 2 * t),
                    child: child,
                  ),
                );
              },
              child: art,
            ),
            // The golden egg: dropped at the hen's feet, then rolled away.
            AnimatedBuilder(
              animation: _egg,
              builder: (context, _) {
                if (!_egg.isAnimating) return const SizedBox.shrink();
                final t = _egg.value;
                final roll = t < 0.25 ? 0.0 : (t - 0.25) / 0.75;
                return Positioned(
                  left: widget.width * 0.4 + 90 * roll,
                  bottom: -4,
                  child: Opacity(
                    opacity: t < 0.85 ? 1 : (1 - t) / 0.15,
                    child: Transform.rotate(
                      angle: roll * math.pi * 3,
                      child: const KurczakArt(
                        Kurczak.eggGold,
                        key: Key('kurczak-egg'),
                        width: 22,
                        height: 22,
                      ),
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              // Merged with the move so the bubble follows a running chick.
              animation: Listenable.merge([_bubble, _move]),
              builder: (context, _) {
                final line = _line;
                if (line == null || !_bubble.isAnimating) {
                  return const SizedBox.shrink();
                }
                final t = _bubble.value;
                final opacity = t < 0.15
                    ? t / 0.15
                    : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
                final dx = widget.runs && _move.isAnimating
                    ? _runOffset(_move.value)
                    : 0.0;
                return Positioned(
                  left: -40 + dx,
                  right: -40 - dx,
                  bottom: widget.height + 2 + 6 * t,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: opacity.clamp(0.0, 1.0),
                      child: Center(child: _SpeechBubble(line)),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.rpg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: t.parchmentLight,
        border: Border.all(color: t.inkHeading, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontFamily: t.fontDisplay,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          height: 1.1,
          color: t.inkHeading,
        ),
      ),
    );
  }
}
