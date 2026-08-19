import 'dart:developer' as developer;
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  AudioService._();

  static final AudioPlayer _player = AudioPlayer();
  static bool _playedStarted = false;
  static bool _playedEnded = false;

  /// Plays `started.mp3` sound ONCE when the ride begins.
  static Future<void> playTripStarted() async {
    if (_playedStarted) return;
    _playedStarted = true;
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/started.mp3'));
      developer.log('AudioService: Played started.mp3');
    } catch (e) {
      developer.log('AudioService error playing started.mp3: $e');
    }
  }

  /// Plays `ended.mp3` sound ONCE when the ride completes successfully.
  static Future<void> playRideEnded() async {
    if (_playedEnded) return;
    _playedEnded = true;
    try {
      await _player.stop();
      await _player.play(AssetSource('audio/ended.mp3'));
      developer.log('AudioService: Played ended.mp3');
    } catch (e) {
      developer.log('AudioService error playing ended.mp3: $e');
    }
  }

  /// Resets sound state for a new ride lifecycle.
  static void resetState() {
    _playedStarted = false;
    _playedEnded = false;
  }
}
