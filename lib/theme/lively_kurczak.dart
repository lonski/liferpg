import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'decor.dart';
import 'rpg_theme.dart';

/// Which voice a tapped bird answers in.
enum KurczakVoice { hen, rooster, chick }

/// A Kurczaki illustration that reacts to a tap: it hops, spins, shakes
/// itself or stretches its neck (with [runs], a chick scurries aside and
/// back), says something in a speech bubble and buzzes lightly; a hen or a
/// rooster now and then sheds a few feathers. A long press sends it to
/// sleep ("Zzz…"). A hen tapped five times in quick succession lays a
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
    KurczakVoice.hen: [
      'Ko-ko!',
      'Ko-ko-ko!',
      'Kooo?',
      'Gdak, gdak!',
      'Ko-ko-dak!',
      'Masz ziarenko?',
      'Kto mnie łaskocze?',
      'Pilnuję jajek!',
      'Ko? Ko!',
    ],
    KurczakVoice.rooster: [
      'Kukuryku!',
      'Ku-ku-ryku!',
      'Pobudka!',
      'Tu ja rządzę!',
      'Zadania czekają!',
      'Kuku-RYKU!',
    ],
    KurczakVoice.chick: [
      'Pi-pi!',
      'Pip!',
      'Piii!',
      'Mama?',
      'Jestem głodny!',
      'Pip-pip-pip!',
      'Hej!',
      'Łaskocze!',
    ],
  };

  /// Every line [voice] may say (tests look the bubble up by these).
  static List<String> linesOf(KurczakVoice voice) => _lines[voice]!;

  static const eggLine = 'Ko-ko-KOOO!';

  /// Picks lines, moves and feathers; tests seed it for repeatable runs.
  @visibleForTesting
  static math.Random random = math.Random();

  /// What a long-pressed bird says as it nods off.
  static const sleepLines = ['Zzz…', 'Chrr… Zzz…', 'Jeszcze pięć minut…'];

  @override
  State<LivelyKurczak> createState() => _LivelyKurczakState();
}

/// How a bird moves on a tap (or a long press: [doze]).
enum _Moves { hop, spin, shake, stretch, run, doze }

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
  late final _feathers = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  math.Random get _random => LivelyKurczak.random;
  _Moves _style = _Moves.hop;

  /// Each shed feather's flight: direction (radians), reach, spin.
  List<(double, double, double)> _flights = const [];

  String? _line;

  /// The bubble lives in the Overlay, above everything: drawn inside the
  /// bird's own box it was clipped by the list viewport or the AppBar for
  /// birds at the top of a screen.
  OverlayEntry? _bubbleEntry;
  int _quickTaps = 0;

  /// Forgets the quick-tap run once [LivelyKurczak.eggTapWindow] passes
  /// without another tap (a timer rather than wall-clock reads, so the run
  /// is driven by the same fake time as every other animation in tests).
  Timer? _tapRunReset;

  @override
  void initState() {
    super.initState();
    _bubble.addStatusListener((status) {
      if (status == AnimationStatus.completed) _removeBubble();
    });
  }

  @override
  void dispose() {
    _removeBubble();
    _tapRunReset?.cancel();
    _move.dispose();
    _bubble.dispose();
    _egg.dispose();
    _feathers.dispose();
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
    final grown = widget.voice != KurczakVoice.chick;
    _say(lays ? LivelyKurczak.eggLine : _pick(lines));
    if (grown && !lays && _random.nextInt(10) < 4) _shedFeathers();
    _moveAs(
      widget.runs
          ? _Moves.run
          : _pick(const [
              _Moves.hop,
              _Moves.spin,
              _Moves.shake,
              _Moves.stretch,
            ]),
    );
  }

  void _onLongPress() {
    HapticFeedback.selectionClick();
    _say(_pick(LivelyKurczak.sleepLines));
    _moveAs(_Moves.doze);
  }

  T _pick<T>(List<T> options) => options[_random.nextInt(options.length)];

  void _say(String line) {
    setState(() => _line = line);
    _showBubble();
    _bubble.forward(from: 0);
  }

  void _shedFeathers() {
    _flights = [
      for (var i = 0; i < 5; i++)
        (
          -math.pi / 2 + (_random.nextDouble() - 0.5) * math.pi * 1.3,
          24 + _random.nextDouble() * 22,
          (_random.nextDouble() - 0.5) * 6,
        ),
    ];
    _feathers.forward(from: 0);
  }

  void _moveAs(_Moves style) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _style = style;
    _move
      ..duration = Duration(
        milliseconds: switch (style) {
          _Moves.hop => 450,
          _Moves.spin => 650,
          _Moves.shake => 520,
          _Moves.stretch => 600,
          _Moves.run => 900,
          _Moves.doze => 1800,
        },
      )
      ..forward(from: 0);
  }

  void _removeBubble() {
    _bubbleEntry?.remove();
    _bubbleEntry?.dispose();
    _bubbleEntry = null;
  }

  void _showBubble() {
    _removeBubble();
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;
    final entry = OverlayEntry(
      builder: (_) => AnimatedBuilder(
        // Merged with the move so the bubble follows a running chick.
        animation: Listenable.merge([_bubble, _move]),
        builder: (_, _) => _positionedBubble(overlay),
      ),
    );
    _bubbleEntry = entry;
    overlay.insert(entry);
  }

  static const _bubbleHeight = 28.0;
  static const _bubbleWidth = 200.0;

  /// Above the bird, or below it when that would run under the status bar
  /// (a bird in the AppBar itself).
  Widget _positionedBubble(OverlayState overlay) {
    final line = _line;
    final bird = mounted ? context.findRenderObject() as RenderBox? : null;
    final stage = overlay.context.findRenderObject() as RenderBox?;
    if (line == null ||
        !_bubble.isAnimating ||
        bird == null ||
        !bird.attached ||
        stage == null) {
      return const SizedBox.shrink();
    }
    final t = _bubble.value;
    final at = stage.globalToLocal(bird.localToGlobal(Offset.zero));
    final dx = widget.runs && _move.isAnimating ? _runOffset(_move.value) : 0.0;
    final centreX = at.dx + bird.size.width / 2 + dx;
    final safeTop = MediaQuery.paddingOf(overlay.context).top;
    final roomAbove = at.dy - _bubbleHeight - 4 >= safeTop + 2;
    final top = roomAbove
        ? at.dy - _bubbleHeight - 2 - 6 * t
        : at.dy + bird.size.height + 2 + 6 * t;
    final opacity = t < 0.15 ? t / 0.15 : (t > 0.8 ? (1 - t) / 0.2 : 1.0);
    final left = (centreX - _bubbleWidth / 2)
        .clamp(4.0, math.max(4.0, stage.size.width - _bubbleWidth - 4))
        .toDouble();
    return Positioned(
      left: left,
      top: top,
      width: _bubbleWidth,
      height: _bubbleHeight,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          // Pinned over the bird even where the box is clamped to the edge.
          child: Align(
            alignment: Alignment(
              ((centreX - left) / _bubbleWidth * 2 - 1).clamp(-1.0, 1.0),
              0,
            ),
            child: _SpeechBubble(line),
          ),
        ),
      ),
    );
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
      onLongPress: _onLongPress,
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
                final up = math.sin(math.pi * t);
                return switch (_style) {
                  // Out and back, facing the way it runs.
                  _Moves.run => Transform.translate(
                    offset: Offset(
                      _runOffset(t),
                      -3 * (math.sin(t * math.pi * 8)).abs(),
                    ),
                    child: Transform.flip(flipX: t > 0.5, child: child),
                  ),
                  _Moves.hop => Transform.translate(
                    offset: Offset(0, -12 * up),
                    child: Transform.rotate(
                      angle: 0.18 * math.sin(math.pi * 2 * t),
                      child: child,
                    ),
                  ),
                  // A pirouette in the air.
                  _Moves.spin => Transform.translate(
                    offset: Offset(0, -10 * up),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(2 * math.pi * t),
                      child: child,
                    ),
                  ),
                  // Shaking itself like a wet hen.
                  _Moves.shake => Transform.rotate(
                    angle: 0.22 * math.sin(math.pi * 8 * t) * (1 - t),
                    child: child,
                  ),
                  // Neck out, standing tall.
                  _Moves.stretch => Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(
                      1 - 0.08 * up,
                      1 + 0.18 * up,
                      1,
                    ),
                    child: child,
                  ),
                  // Nodding off: sinks, tilts and sways.
                  _Moves.doze => Transform.translate(
                    offset: Offset(0, 4 * up),
                    child: Transform.rotate(
                      alignment: Alignment.bottomCenter,
                      angle: (0.16 + 0.05 * math.sin(math.pi * 4 * t)) * up,
                      child: child,
                    ),
                  ),
                };
              },
              child: art,
            ),
            // Shed feathers: burst out, drift down and fade.
            AnimatedBuilder(
              animation: _feathers,
              builder: (context, _) {
                if (!_feathers.isAnimating) return const SizedBox.shrink();
                final t = _feathers.value;
                return Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final (dir, reach, spin) in _flights)
                          Positioned(
                            left:
                                widget.width / 2 -
                                6 +
                                math.cos(dir) * reach * t,
                            top:
                                widget.height * 0.45 +
                                math.sin(dir) * reach * t +
                                30 * t * t,
                            child: Opacity(
                              opacity: (1 - t).clamp(0.0, 1.0),
                              child: Transform.rotate(
                                angle: spin * t,
                                child: const KurczakArt(
                                  Kurczak.feather,
                                  key: Key('kurczak-feather'),
                                  width: 12,
                                  height: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
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
