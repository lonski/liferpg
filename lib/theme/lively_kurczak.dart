import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'decor.dart';
import 'lively.dart';

/// Which voice a tapped bird answers in.
enum KurczakVoice { hen, rooster, chick }

/// A Kurczaki illustration that reacts to a tap: it hops, spins, shakes
/// itself or stretches its neck (with [runs], a chick scurries aside and
/// back), says something in a speech bubble and buzzes lightly; a hen or a
/// rooster now and then sheds a few feathers. A long press sends it to
/// sleep ("Zzz…"). A hen tapped five times in quick succession lays a
/// golden egg that rolls away -- a secret for the kids to find.
///
/// The birds' voices and props on the shared [Lively] engine.
class LivelyKurczak extends StatelessWidget {
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
  static const eggTapWindow = LivelySecret.tapWindow;

  /// How many quick taps make a hen lay.
  static const eggTaps = LivelySecret.taps;

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
  static math.Random get random => Lively.random;
  static set random(math.Random value) => Lively.random = value;

  /// The sound files (under `assets/`) each voice picks from, and the
  /// laying hen's cackle.
  static const sounds = {
    KurczakVoice.hen: [
      'kurczaki/sounds/hen_1.m4a',
      'kurczaki/sounds/hen_2.m4a',
      'kurczaki/sounds/hen_3.m4a',
    ],
    KurczakVoice.rooster: [
      'kurczaki/sounds/rooster_1.m4a',
      'kurczaki/sounds/rooster_2.m4a',
    ],
    KurczakVoice.chick: [
      'kurczaki/sounds/chick_1.m4a',
      'kurczaki/sounds/chick_2.m4a',
      'kurczaki/sounds/chick_3.m4a',
    ],
  };
  static const eggSound = 'kurczaki/sounds/egg.m4a';

  /// What a bird says when grain is dropped on it.
  static const feedLines = {
    KurczakVoice.hen: ['Mniam!', 'Pyszne ziarenko!', 'Dziękuję!', 'Ko-ko, mniam!'],
    KurczakVoice.rooster: ['Smaczne!', 'Ku-ku-mniam!', 'Dziękuję!'],
    KurczakVoice.chick: ['Mniam mniam!', 'Pip! Pyszne!', 'Jeszcze!'],
  };

  /// What a long-pressed bird says as it nods off.
  static const sleepLines = ['Zzz…', 'Chrr… Zzz…', 'Jeszcze pięć minut…'];

  @override
  Widget build(BuildContext context) => Lively(
        art: KurczakArt(art, width: width, height: height, flip: flip, turns: turns, label: label),
        width: width,
        height: height,
        flip: flip,
        runs: runs,
        lines: linesOf(voice),
        sounds: sounds[voice]!,
        feeding: LivelyFeeding(
          eats: const {'grain'},
          lines: feedLines[voice]!,
          sound: sounds[voice]!.first,
          burst: const LivelyBurst(
            rise: true,
            piece: KurczakArt(Kurczak.heart, key: Key('kurczak-heart'), width: 12, height: 11),
          ),
        ),
        moves: const [LivelyMove.hop, LivelyMove.spin, LivelyMove.shake, LivelyMove.stretch],
        holdLines: sleepLines,
        burst: voice == KurczakVoice.chick
            ? null
            : const LivelyBurst(
                chance: 0.4,
                piece: KurczakArt(Kurczak.feather, key: Key('kurczak-feather'), width: 12, height: 12),
              ),
        secret: voice == KurczakVoice.hen
            ? const LivelySecret(
                line: eggLine,
                sound: eggSound,
                piece: KurczakArt(Kurczak.eggGold, key: Key('kurczak-egg'), width: 22, height: 22),
              )
            : null,
      );
}
