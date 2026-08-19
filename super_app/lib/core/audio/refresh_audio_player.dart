import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

/// A singleton audio player for the pull-to-refresh sound.
/// We use `video_player` since it's the only media package available in the app.
class RefreshAudioPlayer {
  static final RefreshAudioPlayer _instance = RefreshAudioPlayer._internal();
  factory RefreshAudioPlayer() => _instance;
  RefreshAudioPlayer._internal();

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  /// Initializes the audio controller. Call this early (e.g. in main or home screen initState)
  /// so there's no delay when pull-to-refresh happens.
  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _controller = VideoPlayerController.asset('assets/audio/refresh.mp4');
      await _controller!.initialize();
      _controller!.setLooping(false);
      _isInitialized = true;

      _controller!.addListener(() {
        if (_controller!.value.isInitialized) {
          if (_controller!.value.position >= _controller!.value.duration) {
            _isPlaying = false;
          }
        }
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to initialize refresh audio: $e');
    }
  }

  /// Plays the refresh sound from the beginning.
  /// If it's already playing, it won't restart.
  Future<void> play() async {
    if (!_isInitialized || _controller == null) {
      await init();
    }
    if (_controller == null || !_isInitialized) return;

    if (_isPlaying) return; // Prevent overlapping audio

    _isPlaying = true;
    try {
      await _controller!.seekTo(Duration.zero);
      await _controller!.play();
    } catch (e) {
      _isPlaying = false;
      if (kDebugMode) debugPrint('Error playing refresh audio: $e');
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }
}
