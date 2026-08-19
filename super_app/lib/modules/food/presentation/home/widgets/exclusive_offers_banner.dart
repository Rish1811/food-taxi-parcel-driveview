import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';

/// Promo card between "Popular Brands" and "Restaurants". Background is the
/// looping, muted promo video from assets/videos/banner.mp4 — the same
/// text/overlays (shine sweep, twinkle pulses) that sat on the static
/// artwork now sit on top of the video instead.
class ExclusiveOffersBanner extends StatefulWidget {
  const ExclusiveOffersBanner({super.key});

  @override
  State<ExclusiveOffersBanner> createState() => _ExclusiveOffersBannerState();
}

class _ExclusiveOffersBannerState extends State<ExclusiveOffersBanner> with TickerProviderStateMixin {
  late final AnimationController _shineController;
  late final Animation<double> _shine;
  late final AnimationController _twinkleController;
  late VideoPlayerController _videoController;
  bool _isRecovering = false;

  @override
  void initState() {
    super.initState();

    _videoController = VideoPlayerController.asset('assets/videos/banner.mp4');
    _bootVideo();

    // Shine sweeps once every cycle, then pauses, so it reads as a subtle
    // premium highlight rather than a constant, distracting motion.
    _shineController = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();
    _shine = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -0.4, end: 1.4).chain(CurveTween(curve: Curves.easeInOut)), weight: 35),
      TweenSequenceItem(tween: ConstantTween(1.4), weight: 65),
    ]).animate(_shineController);

    _twinkleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
  }

  Future<void> _bootVideo() async {
    try {
      await _videoController.initialize();
      if (!mounted) return;
      setState(() {});
      // Mute must finish applying to the underlying player *before* play()
      // is invoked — otherwise an autoplay/focus policy can silently reject
      // an unmuted-at-the-time play() call and the video never starts.
      await _videoController.setVolume(0);
      if (!mounted) return;
      await _ensurePlaying();
      if (!mounted) return;
      // Looping is driven manually via _loopSeamlessly below instead of
      // setLooping(true) — the native "wait for end, then restart" cycle
      // has a brief stall/flash on some platforms, so we seek back to
      // zero just before the video reaches its final frame instead.
      _videoController.addListener(_loopSeamlessly);
      _startWatchdog();
    } catch (e) {
      debugPrint('ExclusiveOffersBanner: video failed to load/play — $e');
    }
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _videoController.removeListener(_loopSeamlessly);
    _shineController.dispose();
    _twinkleController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  // With up to 8 videos on this screen (this banner, the header, and one per
  // restaurant card) all auto-playing at once, Android sometimes loses the
  // race for a decoder/audio-focus slot: play() returns normally and
  // value.isPlaying even flips true, but the frame never actually advances,
  // with no exception to catch. `isPlaying` alone isn't trustworthy here —
  // it can read true optimistically before the real native failure syncs
  // back — so this checks actual position movement instead, and retries
  // until the video is genuinely decoding. If the decoder is truly wedged,
  // retrying play() on the same instance never helps — tearing down and
  // recreating the controller from scratch does.
  Future<void> _ensurePlaying() async {
    for (var attempt = 0; attempt < 8; attempt++) {
      if (!mounted) return;
      final startPosition = _videoController.value.position;
      await _videoController.play();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (_videoController.value.position > startPosition) return;
    }
    await _recreateController();
  }

  Future<void> _recreateController() async {
    if (_isRecovering) return;
    _isRecovering = true;
    try {
      final old = _videoController;
      old.removeListener(_loopSeamlessly);
      final fresh = VideoPlayerController.asset('assets/videos/banner.mp4');
      await fresh.initialize();
      if (!mounted) {
        await fresh.dispose();
        return;
      }
      setState(() => _videoController = fresh);
      await old.dispose();
      await _videoController.setVolume(0);
      if (!mounted) return;
      for (var attempt = 0; attempt < 4; attempt++) {
        if (!mounted) return;
        final startPosition = _videoController.value.position;
        await _videoController.play();
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        if (_videoController.value.position > startPosition) break;
      }
      _videoController.addListener(_loopSeamlessly);
    } catch (e) {
      debugPrint('ExclusiveOffersBanner: controller recreation failed — $e');
    } finally {
      _isRecovering = false;
    }
  }

  // Backstop for the rare case where playback stalls again well after
  // startup (e.g. the OS reclaims the decoder under memory pressure): every
  // couple of seconds, confirm the position actually moved since the last
  // check, and if it's stuck, re-run _ensurePlaying to recover.
  Timer? _watchdog;
  Duration _watchdogLastPosition = Duration.zero;
  void _startWatchdog() {
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted || _isLooping || _isRecovering) return;
      final value = _videoController.value;
      if (!value.isInitialized) return;
      if (value.position <= _watchdogLastPosition) {
        _ensurePlaying();
      }
      _watchdogLastPosition = value.position;
    });
  }

  // Seeks back to the very start just before the video would naturally end,
  // then keeps playing — this avoids the brief stall/flash that the native
  // "play → end → restart" cycle (setLooping(true)) can show, giving a
  // continuous, seamless loop instead.
  bool _isLooping = false;
  void _loopSeamlessly() async {
    final value = _videoController.value;
    if (!value.isInitialized || _isLooping) return;

    final remaining = value.duration - value.position;
    if (remaining <= const Duration(milliseconds: 80)) {
      _isLooping = true;
      await _videoController.seekTo(Duration.zero);
      await _ensurePlaying();
      _isLooping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Match the container's shape to the video's own native aspect ratio
    // once it's known, so BoxFit.cover never has to crop anything — before
    // that, fall back to a plausible widescreen ratio to avoid layout jump.
    final bannerAspectRatio =
        _videoController.value.isInitialized ? _videoController.value.aspectRatio : 16 / 9;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFFDF3E7),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow1,
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: AspectRatio(
          aspectRatio: bannerAspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _videoController.value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      clipBehavior: Clip.hardEdge,
                      child: SizedBox(
                        width: _videoController.value.size.width,
                        height: _videoController.value.size.height,
                        child: VideoPlayer(_videoController),
                      ),
                    )
                  : Container(color: const Color(0xFFFDF3E7)),

              // Shine sweep.
              AnimatedBuilder(
                animation: _shine,
                builder: (context, child) => IgnorePointer(
                  child: CustomPaint(painter: _ShineSweepPainter(_shine.value)),
                ),
              ),

              // Soft twinkle pulses over the illustration's own sparkle accents.
              _twinklePulse(alignment: const Alignment(0.55, -0.55), size: 26),
              _twinklePulse(alignment: const Alignment(0.87, 0.35), size: 18, delay: 0.5),
            ],
          ),
        ),
      ),
    );
  }

  Widget _twinklePulse({required Alignment alignment, required double size, double delay = 0.0}) {
    return AnimatedBuilder(
      animation: _twinkleController,
      builder: (context, child) {
        final t = (_twinkleController.value + delay) % 1.0;
        final opacity = 0.15 + 0.25 * t;
        final scale = 0.8 + 0.4 * t;
        return Align(
          alignment: alignment,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: size,
                  height: size,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [Colors.white, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShineSweepPainter extends CustomPainter {
  final double progress; // roughly -0.4 .. 1.4

  _ShineSweepPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final xPos = size.width * progress;
    final band = size.width * 0.22;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.16),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTRB(xPos - band, 0, xPos + band, size.height));
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ShineSweepPainter oldDelegate) => oldDelegate.progress != progress;
}
