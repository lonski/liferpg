import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'lagotto_decor.dart';
import 'lively.dart';

/// Which voice a tapped dog answers in.
enum LagottoVoice { dog, puppy, sleepy }

/// A Lagotto illustration that reacts to a tap: it hops, chases its tail,
/// shakes itself like a wet dog (throwing off water drops) or makes a play
/// bow (with [runs], a puppy scurries aside and back), barks something in a
/// speech bubble and buzzes lightly. A long press is a scratch behind the
/// ear: it leans in and hearts float up. A grown dog tapped five times in
/// quick succession digs up a golden truffle that rolls away -- a secret
/// for the kids to find. The dog asleep on the character card only stirs
/// and mumbles.
///
/// The dogs' voices and props on the shared [Lively] engine.
class LivelyLagotto extends StatelessWidget {
  const LivelyLagotto(
    this.art, {
    super.key,
    required this.voice,
    required this.width,
    required this.height,
    this.flip = false,
    this.runs = false,
    this.label,
  });

  final Lagotto art;
  final LagottoVoice voice;
  final double width;
  final double height;
  final bool flip;

  /// Scurry sideways and back instead of hopping (puppies on the grass).
  final bool runs;
  final String? label;

  static const _lines = {
    LagottoVoice.dog: [
      'Hau!',
      'Hau-hau!',
      'Czuję truflę!',
      'Rzucisz piłkę?',
      'Podrap za uchem!',
      'Wrrr… żartuję!',
      'Hau? Hau!',
      'Gdzie mój smaczek?',
    ],
    LagottoVoice.puppy: [
      'Hau!',
      'Hał-hał!',
      'Bawimy się?',
      'Łap mnie!',
      'Mam kość!',
      'Jeszcze!',
    ],
    LagottoVoice.sleepy: [
      'Zzz… hau?',
      'Hrrr…',
      'Jeszcze chwilkę…',
      'Śnię o truflach…',
      'Mhm… hau.',
    ],
  };

  /// Every line [voice] may say on a tap (tests look the bubble up by these).
  static List<String> linesOf(LagottoVoice voice) => _lines[voice]!;

  /// What a scratched dog says.
  static const petLines = ['Jeszcze, jeszcze!', 'Mmm…', 'Tu, za uchem!'];

  /// What the sleeping dog says when held: it does not wake.
  static const sleepLines = ['Zzz…', 'Chrr… Zzz…'];

  static const truffleLine = 'Hau! Trufla!';

  /// What a dog says when kibble is dropped on it.
  static const feedLines = {
    LagottoVoice.dog: ['Mniam, karma!', 'Hau! Pyszne!', 'Dziękuję!', 'Jeszcze miseczkę?'],
    LagottoVoice.puppy: ['Mniam mniam!', 'Hał! Pyszne!', 'Jeszcze!'],
    LagottoVoice.sleepy: ['Mhm… mniam…', 'Zzz… mniam…'],
  };

  /// Picks lines, moves and drops; tests seed it for repeatable runs.
  @visibleForTesting
  static math.Random get random => Lively.random;
  static set random(math.Random value) => Lively.random = value;

  @override
  Widget build(BuildContext context) {
    final asleep = voice == LagottoVoice.sleepy;
    return Lively(
      art: LagottoArt(art, width: width, height: height, flip: flip, label: label),
      width: width,
      height: height,
      flip: flip,
      runs: runs,
      lines: linesOf(voice),
      moves: asleep
          ? const [LivelyMove.stretch, LivelyMove.shake]
          : const [LivelyMove.hop, LivelyMove.chase, LivelyMove.shake, LivelyMove.bow],
      holdLines: asleep ? sleepLines : petLines,
      feeding: LivelyFeeding(
        eats: const {'kibble'},
        lines: feedLines[voice]!,
        move: asleep ? LivelyMove.stretch : LivelyMove.peck,
        burst: const LivelyBurst(
          rise: true,
          piece: LagottoArt(Lagotto.heart, key: Key('lagotto-fed-heart'), width: 13, height: 13),
        ),
      ),
      burst: asleep
          ? null
          : const LivelyBurst(
              onlyWith: LivelyMove.shake,
              piece: LagottoArt(Lagotto.drop, key: Key('lagotto-drop'), width: 11, height: 11),
            ),
      holdBurst: asleep
          ? null
          : const LivelyBurst(
              rise: true,
              piece: LagottoArt(Lagotto.heart, key: Key('lagotto-heart'), width: 13, height: 13),
            ),
      secret: voice == LagottoVoice.dog
          ? const LivelySecret(
              line: truffleLine,
              pops: true,
              piece: LagottoArt(Lagotto.truffleGold, key: Key('lagotto-truffle'), width: 22, height: 22),
            )
          : null,
    );
  }
}
