import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'rpg_theme.dart';

/// How a lively illustration moves on a tap (or a long press).
enum LivelyMove {
  /// A hop with a little wobble.
  hop,

  /// A pirouette in the air (turning about its vertical axis).
  spin,

  /// Shaking itself, like a wet hen or a wet dog.
  shake,

  /// Neck out, standing tall.
  stretch,

  /// Out sideways and back, the way it faces (chicks and puppies on the
  /// grass).
  run,

  /// Sinks, tilts and sways: nodding off, or leaning into a scratch.
  doze,

  /// A full turn in place, chasing its own tail.
  chase,

  /// The play bow: front down, rump up, then back.
  bow,
}

/// A handful of [piece]s thrown off by a move: feathers or water drops
/// fall, hearts [rise].
class LivelyBurst {
  const LivelyBurst({
    required this.piece,
    this.chance = 1,
    this.onlyWith,
    this.rise = false,
  });

  /// One piece, about 12 px; it carries the key tests look it up by.
  final Widget piece;

  /// How likely a tap throws it off (0..1).
  final double chance;

  /// Only when the tap's move is this one (a dog sheds drops only when it
  /// shakes itself); null for any move.
  final LivelyMove? onlyWith;

  /// Float up and away (hearts) rather than burst out and drift down.
  final bool rise;
}

/// The hidden surprise: [taps] quick taps make the illustration say [line]
/// and produce [piece], which rolls away -- dropped at its feet, or, when
/// it [pops], dug up out of the ground first.
class LivelySecret {
  const LivelySecret({
    required this.line,
    required this.piece,
    this.pops = false,
  });

  final String line;
  final Widget piece;
  final bool pops;

  /// Taps this close together count towards the secret.
  static const tapWindow = Duration(milliseconds: 700);

  /// How many quick taps reveal it.
  static const taps = 5;
}

/// An illustration that reacts to a tap: it makes one of [moves] (with
/// [runs], it scurries aside and back instead), says one of [lines] in a
/// speech bubble and buzzes lightly, maybe throwing off a [burst]. A long
/// press plays [holdMove] with one of [holdLines] and [holdBurst]. Quick
/// taps reveal the [secret], if it has one.
///
/// The engine behind each theme's animals ([LivelyKurczak], [LivelyLagotto]),
/// which supply the drawing, the voice and the props. Purely decorative: no
/// state outlives the animation, nothing is written.
class Lively extends StatefulWidget {
  const Lively({
    super.key,
    required this.art,
    required this.width,
    required this.height,
    required this.lines,
    required this.holdLines,
    this.moves = const [LivelyMove.hop],
    this.holdMove = LivelyMove.doze,
    this.flip = false,
    this.runs = false,
    this.burst,
    this.holdBurst,
    this.secret,
  });

  final Widget art;
  final double width;
  final double height;
  final List<String> lines;
  final List<String> holdLines;
  final List<LivelyMove> moves;
  final LivelyMove holdMove;

  /// Faces left: a run sets off that way.
  final bool flip;
  final bool runs;
  final LivelyBurst? burst;
  final LivelyBurst? holdBurst;
  final LivelySecret? secret;

  /// Picks lines, moves and bursts; tests seed it (through each theme's
  /// wrapper) for repeatable runs.
  static math.Random random = math.Random();

  @override
  State<Lively> createState() => _LivelyState();
}

class _LivelyState extends State<Lively> with TickerProviderStateMixin {
  late final _move = AnimationController(vsync: this);
  late final _bubble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final _secret = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  late final _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  math.Random get _random => Lively.random;
  LivelyMove _style = LivelyMove.hop;

  /// The burst on screen, and each piece's flight: direction (radians),
  /// reach, spin.
  LivelyBurst? _shown;
  List<(double, double, double)> _flights = const [];

  String? _line;

  /// The bubble lives in the Overlay, above everything: drawn inside the
  /// illustration's own box it was clipped by the list viewport or the
  /// AppBar for animals at the top of a screen.
  OverlayEntry? _bubbleEntry;
  int _quickTaps = 0;

  /// Forgets the quick-tap run once [LivelySecret.tapWindow] passes without
  /// another tap (a timer rather than wall-clock reads, so the run is driven
  /// by the same fake time as every other animation in tests).
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
    _secret.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _onTap() {
    HapticFeedback.lightImpact();
    _quickTaps++;
    _tapRunReset?.cancel();
    _tapRunReset = Timer(LivelySecret.tapWindow, () => _quickTaps = 0);

    final secret = widget.secret;
    final reveals = secret != null &&
        _quickTaps >= LivelySecret.taps &&
        !_secret.isAnimating;
    if (reveals) {
      _quickTaps = 0;
      _secret.forward(from: 0);
    }

    _say(reveals ? secret.line : _pick(widget.lines));
    final move = widget.runs ? LivelyMove.run : _pick(widget.moves);
    final burst = widget.burst;
    if (burst != null &&
        !reveals &&
        (burst.onlyWith == null || burst.onlyWith == move) &&
        _random.nextDouble() < burst.chance) {
      _throw(burst);
    }
    _moveAs(move);
  }

  void _onLongPress() {
    HapticFeedback.selectionClick();
    _say(_pick(widget.holdLines));
    if (widget.holdBurst case final burst?) _throw(burst);
    _moveAs(widget.holdMove);
  }

  T _pick<T>(List<T> options) => options[_random.nextInt(options.length)];

  void _say(String line) {
    setState(() => _line = line);
    _showBubble();
    _bubble.forward(from: 0);
  }

  void _throw(LivelyBurst burst) {
    _shown = burst;
    _flights = [
      for (var i = 0; i < 5; i++)
        (
          -math.pi / 2 + (_random.nextDouble() - 0.5) * math.pi * 1.3,
          24 + _random.nextDouble() * 22,
          (_random.nextDouble() - 0.5) * 6,
        ),
    ];
    _burst.forward(from: 0);
  }

  void _moveAs(LivelyMove style) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    _style = style;
    _move
      ..duration = Duration(
        milliseconds: switch (style) {
          LivelyMove.hop => 450,
          LivelyMove.spin => 650,
          LivelyMove.shake => 520,
          LivelyMove.stretch => 600,
          LivelyMove.run => 900,
          LivelyMove.doze => 1800,
          LivelyMove.chase => 800,
          LivelyMove.bow => 700,
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
        // Merged with the move so the bubble follows a running animal.
        animation: Listenable.merge([_bubble, _move]),
        builder: (_, _) => _positionedBubble(overlay),
      ),
    );
    _bubbleEntry = entry;
    overlay.insert(entry);
  }

  static const _bubbleHeight = 28.0;
  static const _bubbleWidth = 200.0;

  /// Above the animal, or below it when that would run under the status
  /// bar (one in the AppBar itself).
  Widget _positionedBubble(OverlayState overlay) {
    final line = _line;
    final self = mounted ? context.findRenderObject() as RenderBox? : null;
    final stage = overlay.context.findRenderObject() as RenderBox?;
    if (line == null ||
        !_bubble.isAnimating ||
        self == null ||
        !self.attached ||
        stage == null) {
      return const SizedBox.shrink();
    }
    final t = _bubble.value;
    final at = stage.globalToLocal(self.localToGlobal(Offset.zero));
    final dx = widget.runs && _move.isAnimating ? _runOffset(_move.value) : 0.0;
    final centreX = at.dx + self.size.width / 2 + dx;
    final safeTop = MediaQuery.paddingOf(overlay.context).top;
    final roomAbove = at.dy - _bubbleHeight - 4 >= safeTop + 2;
    final top = roomAbove
        ? at.dy - _bubbleHeight - 2 - 6 * t
        : at.dy + self.size.height + 2 + 6 * t;
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
          // Pinned over the animal even where the box is clamped to the edge.
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

  /// How far a running animal is from its spot at run progress [t]: out
  /// and back, the way it faces.
  double _runOffset(double t) =>
      (widget.flip ? -1.0 : 1.0) * 56 * math.sin(math.pi * t);

  Widget _moving(BuildContext context, Widget? child) {
    final t = _move.value;
    if (t == 0 || t == 1) return child!;
    final up = math.sin(math.pi * t);
    return switch (_style) {
      // Out and back, facing the way it runs.
      LivelyMove.run => Transform.translate(
        offset: Offset(_runOffset(t), -3 * (math.sin(t * math.pi * 8)).abs()),
        child: Transform.flip(flipX: t > 0.5, child: child),
      ),
      LivelyMove.hop => Transform.translate(
        offset: Offset(0, -12 * up),
        child: Transform.rotate(
          angle: 0.18 * math.sin(math.pi * 2 * t),
          child: child,
        ),
      ),
      LivelyMove.spin => Transform.translate(
        offset: Offset(0, -10 * up),
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(2 * math.pi * t),
          child: child,
        ),
      ),
      LivelyMove.shake => Transform.rotate(
        angle: 0.22 * math.sin(math.pi * 8 * t) * (1 - t),
        child: child,
      ),
      LivelyMove.stretch => Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.diagonal3Values(1 - 0.08 * up, 1 + 0.18 * up, 1),
        child: child,
      ),
      LivelyMove.doze => Transform.translate(
        offset: Offset(0, 4 * up),
        child: Transform.rotate(
          alignment: Alignment.bottomCenter,
          angle: (0.16 + 0.05 * math.sin(math.pi * 4 * t)) * up,
          child: child,
        ),
      ),
      // Round and round after its tail, eased in and out.
      LivelyMove.chase => Transform.rotate(
        angle: (widget.flip ? -1 : 1) * 2 * math.pi * Curves.easeInOut.transform(t),
        child: child,
      ),
      // Front down, rump up: tipped towards the way it faces, squashed.
      LivelyMove.bow => Transform(
        alignment: Alignment.bottomCenter,
        transform: Matrix4.diagonal3Values(1 + 0.06 * up, 1 - 0.12 * up, 1)
          ..rotateZ((widget.flip ? -1 : 1) * 0.22 * up),
        child: child,
      ),
    };
  }

  /// The burst: pieces fly out and drift down and fade, or float up.
  Widget _pieces(BuildContext context, Widget? _) {
    final burst = _shown;
    if (!_burst.isAnimating || burst == null) return const SizedBox.shrink();
    final t = _burst.value;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (final (dir, reach, spin) in _flights)
              Positioned(
                left: widget.width / 2 - 6 + math.cos(dir) * reach * t * (burst.rise ? 0.5 : 1),
                top: burst.rise
                    ? widget.height * 0.25 - reach * 1.2 * t
                    : widget.height * 0.45 + math.sin(dir) * reach * t + 30 * t * t,
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: burst.rise ? 0.3 * math.sin(spin + 6 * t) : spin * t,
                    child: burst.piece,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The secret: dropped at the feet (or dug up), then rolled away.
  Widget _revealed(BuildContext context, Widget? _) {
    final secret = widget.secret;
    if (!_secret.isAnimating || secret == null) return const SizedBox.shrink();
    final t = _secret.value;
    final roll = t < 0.25 ? 0.0 : (t - 0.25) / 0.75;
    final lift = secret.pops && t < 0.25 ? 22 * math.sin(math.pi * t / 0.25) : 0.0;
    return Positioned(
      left: widget.width * 0.4 + 90 * roll,
      bottom: -4 + lift,
      child: Opacity(
        opacity: t < 0.85 ? 1 : (1 - t) / 0.15,
        child: Transform.rotate(angle: roll * math.pi * 3, child: secret.piece),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            AnimatedBuilder(animation: _move, builder: _moving, child: widget.art),
            AnimatedBuilder(animation: _burst, builder: _pieces),
            AnimatedBuilder(animation: _secret, builder: _revealed),
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
