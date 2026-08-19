import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

/// Plays short sound effects. Falls back to silence (no crash) if the
/// requested asset hasn't been added to assets/sounds/ yet.
///
/// Uses two players so a short tap sound doesn't cut off a longer
/// machine/ambient effect playing at the same time.
class SoundService {
  static final AudioPlayer _tapPlayer = AudioPlayer();
  static final AudioPlayer _effectsPlayer = AudioPlayer();
  static final AudioPlayer _ringtonePlayer = AudioPlayer();

  /// Short UI feedback sounds, e.g. `SoundService.playTap('printtab.mp3')`
  /// for a file at assets/sounds/printtab.mp3.
  static Future<void> playTap(String assetFileName) async {
    try {
      await _tapPlayer.stop();
      await _tapPlayer.play(AssetSource('sounds/$assetFileName'));
    } catch (_) {
      // Sound asset not available yet — fail silently.
    }
  }

  /// Longer effects, e.g. `SoundService.playEffect('refferticketcomeout.mp3')`
  /// for a file at assets/sounds/refferticketcomeout.mp3.
  static Future<void> playEffect(String assetFileName) async {
    try {
      await _effectsPlayer.stop();
      await _effectsPlayer.play(AssetSource('sounds/$assetFileName'));
    } catch (_) {
      // Sound asset not available yet — fail silently.
    }
  }

  static Future<void> stopEffect() async {
    try {
      await _effectsPlayer.stop();
    } catch (_) {}
  }

  /// Looping ringtone for the full-screen incoming-order alert.
  static Future<void> playRingtone() async {
    try {
      await _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
      await _ringtonePlayer.play(AssetSource('sounds/neworder.mp3'));
    } catch (_) {
      // Sound asset not available yet — fail silently.
    }
  }

  static Future<void> stopRingtone() async {
    try {
      await _ringtonePlayer.stop();
    } catch (_) {}
  }

  /// The built-in platform click sound — needs no asset file.
  static void tapClick() {
    SystemSound.play(SystemSoundType.click);
  }

  /// Refresh sound effect
  static Future<void> playRefresh() async {
    try {
      await _tapPlayer.stop();
      await _tapPlayer.play(AssetSource('sounds/refersh.mp4'));
    } catch (_) {
      // Sound asset not available yet — fail silently.
    }
  }
}
