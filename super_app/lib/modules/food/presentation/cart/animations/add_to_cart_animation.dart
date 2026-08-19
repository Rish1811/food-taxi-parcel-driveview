import 'package:flutter/material.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';

class AddToCartAnimation {
  static void run({
    required BuildContext context,
    required GlobalKey startKey,
    required GlobalKey endKey,
    required String imageUrl,
    required VoidCallback onAnimationComplete,
  }) {
    final startRenderBox = startKey.currentContext?.findRenderObject() as RenderBox?;
    final endRenderBox = endKey.currentContext?.findRenderObject() as RenderBox?;

    if (startRenderBox == null || endRenderBox == null) {
      onAnimationComplete();
      return;
    }

    final startPosition = startRenderBox.localToGlobal(Offset.zero);
    final endPosition = endRenderBox.localToGlobal(Offset.zero);
    final startSize = startRenderBox.size;
    final endSize = endRenderBox.size;

    // Animate center-to-center so the flight lands on the middle of the bag
    // icon rather than aligning mismatched top-left corners.
    final startCenter = startPosition + Offset(startSize.width / 2, startSize.height / 2);
    final endCenter = endPosition + Offset(endSize.width / 2, endSize.height / 2);

    OverlayEntry? overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return _CinematicMorphImage(
          startCenter: startCenter,
          endCenter: endCenter,
          startSize: startSize,
          endSize: endSize,
          imageUrl: imageUrl,
          onComplete: () {
            overlayEntry?.remove();
            onAnimationComplete();
          },
        );
      },
    );

    // Use the root overlay, not the nearest one: inside a StatefulShellRoute
    // branch, the nearest overlay lives inside the Scaffold's body and would
    // paint underneath the bottomNavigationBar, hiding the flight mid-flight.
    Overlay.of(context, rootOverlay: true).insert(overlayEntry);
  }
}

class _CinematicMorphImage extends StatefulWidget {
  final Offset startCenter;
  final Offset endCenter;
  final Size startSize;
  final Size endSize;
  final String imageUrl;
  final VoidCallback onComplete;

  const _CinematicMorphImage({
    required this.startCenter,
    required this.endCenter,
    required this.startSize,
    required this.endSize,
    required this.imageUrl,
    required this.onComplete,
  });

  @override
  State<_CinematicMorphImage> createState() => _CinematicMorphImageState();
}

class _CinematicMorphImageState extends State<_CinematicMorphImage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  // Phase 1: Focus & Expand (0-350ms)
  late Animation<double> _dimOpacityAnimation;
  late Animation<double> _focusScaleAnimation;
  
  // Phase 2: Morph (350-850ms)
  late Animation<double> _morphProgressAnimation;
  late Animation<double> _morphScaleAnimation;

  // Phase 3: Submerge into the bag icon (last 20% of the morph)
  late Animation<double> _submergeAnimation;

  @override
  void initState() {
    super.initState();

    // Total duration: 150 + 300 = 450ms - fast enough to feel instant while
    // keeping the focus/morph/submerge phases proportionally the same.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    const focusEnd = 150 / 450.0;

    // Dim background fades in then out
    _dimOpacityAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.5).chain(CurveTween(curve: Curves.easeOut)), weight: focusEnd * 100),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: (1 - focusEnd) * 100),
    ]).animate(_controller);

    // Expand Image
    _focusScaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, focusEnd, curve: Curves.easeOutBack),
      ),
    );

    // Morph Position
    _morphProgressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(focusEnd, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    // Morph Scale (from 1.3 down to target size)
    final targetScale = (widget.endSize.width / widget.startSize.width).clamp(0.1, 1.0);
    _morphScaleAnimation = Tween<double>(begin: 1.3, end: targetScale).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(focusEnd, 1.0, curve: Curves.easeInOutCubic),
      ),
    );

    // Fades, shrinks and dips further in the final stretch, as if the item
    // is dropping into and being swallowed by the bag icon.
    _submergeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.82, 1.0, curve: Curves.easeIn),
    );

    _controller.forward().then((_) {
      widget.onComplete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final morphT = _morphProgressAnimation.value;
        final submergeT = _submergeAnimation.value;

        // Track the box's center from startCenter to endCenter. The
        // Container below is always laid out at startSize and scaled via
        // Transform.scale (which pivots on its own center), so deriving
        // left/top from the center keeps it landing dead-on regardless of
        // how much smaller the target icon is than the source image.
        double centerX = widget.startCenter.dx;
        double centerY = widget.startCenter.dy;

        if (morphT > 0) {
          centerX = widget.startCenter.dx + (widget.endCenter.dx - widget.startCenter.dx) * morphT;
          centerY = widget.startCenter.dy + (widget.endCenter.dy - widget.startCenter.dy) * morphT;
          // Extra dip downward as it drops into the bag.
          centerY += 14.0 * submergeT;
        }

        final x = centerX - widget.startSize.width / 2;
        final y = centerY - widget.startSize.height / 2;

        final baseScale = morphT > 0 ? _morphScaleAnimation.value : _focusScaleAnimation.value;
        // Extra shrink beyond the target size, so it looks swallowed rather than just parked on top.
        final currentScale = baseScale * (1.0 - 0.55 * submergeT);
        final opacity = 1.0 - submergeT;
        final isMorphing = morphT > 0;

        return Stack(
          children: [
            // Dark Barrier
            if (_dimOpacityAnimation.value > 0)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: _dimOpacityAnimation.value),
                ),
              ),
              
            // The Morphing Image
            Positioned(
              left: x,
              top: y,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: currentScale,
                  child: Container(
                    width: widget.startSize.width,
                    height: widget.startSize.height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(isMorphing ? 40 * morphT + 20 * (1 - morphT) : 20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isMorphing ? 0.2 : 0.4),
                          blurRadius: isMorphing ? 10 : 30,
                          spreadRadius: isMorphing ? 2 : 10,
                          offset: Offset(0, isMorphing ? 5 : 15),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isMorphing ? 40 * morphT + 20 * (1 - morphT) : 20),
                      child: SmartImage(
                        url: widget.imageUrl,
                        category: ImageCategory.food,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
