import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// Singleton audio player for playing the ticket dispensing sound effect
/// ('assets/audio/refferticketcomeout.mp3') exactly once per card creation.
class ReferralAudioPlayer {
  static final ReferralAudioPlayer _instance = ReferralAudioPlayer._internal();
  factory ReferralAudioPlayer() => _instance;
  ReferralAudioPlayer._internal();

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  /// Initializes the video/audio controller for referral ticket sound.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _controller = VideoPlayerController.asset('assets/audio/refferticketcomeout.mp3');
      await _controller!.initialize();
      _controller!.setLooping(false);
      _isInitialized = true;

      _controller!.addListener(() {
        if (_controller != null && _controller!.value.isInitialized) {
          if (_controller!.value.position >= _controller!.value.duration) {
            _isPlaying = false;
          }
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to initialize referral ticket audio: $e');
    }
  }

  /// Plays the ticket dispensing sound effect from the beginning exactly once.
  Future<void> playOnce() async {
    if (!_isInitialized || _controller == null) {
      await init();
    }
    if (_controller == null || !_isInitialized) return;

    if (_isPlaying) return; // Prevent duplicate overlapping playback

    _isPlaying = true;
    try {
      await _controller!.seekTo(Duration.zero);
      await _controller!.play();
    } catch (e) {
      _isPlaying = false;
      if (kDebugMode) debugPrint('Error playing referral ticket audio: $e');
    }
  }

  /// Stops playback immediately.
  Future<void> stop() async {
    if (_controller != null && _isInitialized) {
      try {
        await _controller!.pause();
        await _controller!.seekTo(Duration.zero);
        _isPlaying = false;
      } catch (e) {
        if (kDebugMode) debugPrint('Error stopping referral ticket audio: $e');
      }
    }
  }

  /// Releases resources.
  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
    _isPlaying = false;
  }
}
