import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Plays a short theme sound effect (a hen's cluck) from the asset bundle.
/// A seam so widget tests never reach the audio plugin.
abstract class ThemeSoundPlayer {
  /// [asset] is the path under `assets/`, e.g. `kurczaki/sounds/hen_1.m4a`.
  void play(String asset);
}

/// One fire-and-forget low-latency player per effect, disposed once it has
/// played: effects are rare taps, not a soundtrack, and may overlap.
class AudioplayersThemeSoundPlayer implements ThemeSoundPlayer {
  @override
  void play(String asset) {
    final player = AudioPlayer();
    player.onPlayerComplete.first.then((_) => player.dispose());
    player
        .play(AssetSource(asset), mode: PlayerMode.lowLatency)
        .catchError((Object error) {
      debugPrint('Theme sound $asset failed: $error');
      player.dispose();
    });
  }
}
