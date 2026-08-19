import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/food/data/models/cart_item_model.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';

class FloatingViewCartBar extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  // How far from the bottom the bar sits when shown (hidden position follows
  // the same 144px slide-clear distance). Defaults to the Home Screen's
  // original hardcoded 24.0 so existing behavior there is unchanged; screens
  // with their own sticky bottom bar (e.g. Food Details) can raise this so
  // the two don't overlap.
  final double bottomOffset;

  const FloatingViewCartBar({
    super.key,
    required this.onTap,
    this.bottomOffset = 24.0,
  });

  @override
  ConsumerState<FloatingViewCartBar> createState() => FloatingViewCartBarState();
}

class FloatingViewCartBarState extends ConsumerState<FloatingViewCartBar> with TickerProviderStateMixin {
  late AnimationController _bumpController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowPositionAnimation;
  late Animation<double> _amountScaleAnimation;

  // Stable, always-laid-out anchor marking where the bar sits when shown.
  // Add-to-cart flight animations target this (not the animated pill, whose
  // RenderBox is off-screen while the bar is hidden), so the product always
  // lands on the View Cart button even on the very first add.
  final GlobalKey _flightAnchorKey = GlobalKey();

  /// Flight target for the add-to-cart animation on this screen.
  GlobalKey get flightAnchorKey => _flightAnchorKey;

  @override
  void initState() {
    super.initState();
    _bumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Smooth settle bounce
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.05).chain(CurveTween(curve: Curves.easeOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 0.97).chain(CurveTween(curve: Curves.easeInOut)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 40),
    ]).animate(_bumpController);

    // Glow Sweep moving from left (-0.5) to right (1.5)
    _glowPositionAnimation = Tween<double>(begin: -0.5, end: 1.5).animate(
      CurvedAnimation(
        parent: _bumpController,
        curve: Curves.easeInOut,
      ),
    );

    // Localized 1.0 -> 1.08 -> 1.0 pulse on just the total-amount text,
    // riding the same bump so it fires every time the total changes.
    _amountScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08).chain(CurveTween(curve: Curves.easeOut)), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 50),
    ]).animate(_bumpController);
  }

  @override
  void dispose() {
    _bumpController.dispose();
    super.dispose();
  }

  /// Plays the settle-bounce + glow-sweep animation once. The bar itself
  /// stays visible as long as the cart has items (see [build]); this only
  /// signals that the cart was just updated.
  void bump() {
    _bumpController.forward(from: 0.0);
  }

  // Small overlapping stack of the added-item thumbnails, shown on the
  // right end of the bar. Displays up to 3 thumbnails with a "+N" badge for
  // any remaining distinct items.
  Widget _buildItemStack(List<CartItemModel> items) {
    const double thumbSize = 34;
    const double step = 24; // horizontal shift per icon (10px overlap)

    final visible = items.take(3).toList();
    final extra = items.length - visible.length;
    final int slots = visible.length + (extra > 0 ? 1 : 0);
    final double width = thumbSize + (slots - 1) * step;

    return SizedBox(
      width: width,
      height: thumbSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = 0; i < visible.length; i++)
            Positioned(
              left: i * step,
              child: _squareThumb(visible[i].food.imageUrl),
            ),
          if (extra > 0)
            Positioned(
              left: visible.length * step,
              child: _extraBadge(extra),
            ),
        ],
      ),
    );
  }

  Widget _squareThumb(String url) {
    return Container(
      width: 34,
      height: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SmartImage(
          url: url,
          category: ImageCategory.food,
          fit: BoxFit.cover,
          width: 30,
          height: 30,
        ),
      ),
    );
  }

  Widget _extraBadge(int extra) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Text(
        '+$extra',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartViewModelProvider);

    // Animate the bar on every cart update (new item OR quantity increase),
    // signalling that the cart changed. The bar is not auto-hidden — it stays
    // up as long as the cart has items and only slides away when it empties.
    ref.listen(cartViewModelProvider, (previous, next) {
      final prevQty = previous?.totalQuantity ?? 0;
      if (next.totalQuantity > prevQty) {
        _bumpController.forward(from: 0.0);
      }
    });

    final shouldShow = cartState.items.isNotEmpty;

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Stable invisible flight anchor at the bar's shown position.
          Positioned(
            left: 20,
            right: 20,
            bottom: widget.bottomOffset,
            height: 56,
            child: IgnorePointer(
              child: SizedBox.expand(key: _flightAnchorKey),
            ),
          ),

          AnimatedPositioned(
      duration: const Duration(milliseconds: 500),
      curve: Curves.elasticOut,
      bottom: shouldShow ? widget.bottomOffset : widget.bottomOffset - 144.0,
      left: 20,
      right: 20,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 500),
        curve: Curves.elasticOut,
        scale: shouldShow ? 1.0 : 0.0, // Grows from 0%
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedBuilder(
              animation: _bumpController,
              builder: (context, child) {
                return CustomPaint(
                  foregroundPainter: _GlowSweepPainter(_glowPositionAnimation.value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A00),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF7A00).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Total amount (left) — smooth count-up + a subtle
                        // 1.0 -> 1.08 -> 1.0 pulse every time it changes.
                        Expanded(
                          child: ScaleTransition(
                            scale: _amountScaleAnimation,
                            alignment: Alignment.centerLeft,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOut,
                                  tween: Tween(end: cartState.subtotal),
                                  builder: (context, val, child) {
                                    return Text(
                                      '₹${val.toInt()}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  },
                                ),
                                TweenAnimationBuilder<double>(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutBack,
                                  tween: Tween(end: cartState.items.length.toDouble()),
                                  builder: (context, val, child) {
                                    return Text(
                                      '${val.round()} item${val.round() != 1 ? 's' : ''}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Overlapping stack of added-item thumbnails (right end)
                        if (cartState.items.isNotEmpty) ...[
                          _buildItemStack(cartState.items),
                          const SizedBox(width: 12),
                        ],

                        // View Cart label + chevron (right)
                        const Text(
                          'View Cart',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white, size: 24),
                      ],
                    ),
                  ),
                );
              }
            ),
          ),
        ),
      ),
          ),
        ],
      ),
    );
  }
}

class _GlowSweepPainter extends CustomPainter {
  final double progress; // -0.5 to 1.5

  _GlowSweepPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= -0.5 || progress >= 1.5) return;

    final xPos = size.width * progress;
    
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: 0.6),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTRB(xPos - 40, 0, xPos + 40, size.height))
      ..blendMode = BlendMode.screen;

    // Draw the glow using a rectangle clipped to the rounded border
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)));
    canvas.clipPath(path);
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowSweepPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
