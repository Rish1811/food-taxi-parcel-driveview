import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Animated gradient shimmer container for skeleton loading state.
class ShimmerContainer extends StatefulWidget {
  final Widget child;

  const ShimmerContainer({super.key, required this.child});

  @override
  State<ShimmerContainer> createState() => _ShimmerContainerState();
}

class _ShimmerContainerState extends State<ShimmerContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFEBEBF4);
    final highlightColor = isDark ? const Color(0xFF334155) : const Color(0xFFF8F8FC);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + (_controller.value * 3.0), -0.3),
              end: Alignment(1.0 + (_controller.value * 3.0), 0.3),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Simple rounded skeleton placeholder block.
class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEBEBF4),
        borderRadius: BorderRadius.circular(borderRadius.r),
      ),
    );
  }
}

/// Pre-built skeleton layout for restaurant cards (Home & Search).
class SkeletonRestaurantCard extends StatelessWidget {
  const SkeletonRestaurantCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerContainer(
      child: Container(
        margin: EdgeInsets.only(bottom: 16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: double.infinity, height: 160.h, borderRadius: 16),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonBox(width: 180.w, height: 18.h, borderRadius: 4),
                SkeletonBox(width: 44.w, height: 18.h, borderRadius: 4),
              ],
            ),
            SizedBox(height: 6.h),
            SkeletonBox(width: 130.w, height: 14.h, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Pre-built list of skeleton restaurant cards.
class SkeletonRestaurantList extends StatelessWidget {
  final int count;

  const SkeletonRestaurantList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: List.generate(
          count,
          (index) => const SkeletonRestaurantCard(),
        ),
      ),
    );
  }
}

/// Pre-built skeleton layout for food item cards (Restaurant Menu).
class SkeletonFoodItemCard extends StatelessWidget {
  const SkeletonFoodItemCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerContainer(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 20.w, height: 20.h, borderRadius: 4),
                  SizedBox(height: 8.h),
                  SkeletonBox(width: 160.w, height: 18.h, borderRadius: 4),
                  SizedBox(height: 6.h),
                  SkeletonBox(width: 70.w, height: 16.h, borderRadius: 4),
                  SizedBox(height: 8.h),
                  SkeletonBox(width: 200.w, height: 12.h, borderRadius: 4),
                ],
              ),
            ),
            SizedBox(width: 16.w),
            SkeletonBox(width: 110.w, height: 110.h, borderRadius: 16),
          ],
        ),
      ),
    );
  }
}

/// Pre-built skeleton layout for Banners & Offer Promos.
class SkeletonBanner extends StatelessWidget {
  final double height;

  const SkeletonBanner({super.key, this.height = 140});

  @override
  Widget build(BuildContext context) {
    return ShimmerContainer(
      child: SkeletonBox(
        width: double.infinity,
        height: height.h,
        borderRadius: 20,
      ),
    );
  }
}

/// Pre-built skeleton layout for Order Cards (My Orders).
class SkeletonOrderCard extends StatelessWidget {
  const SkeletonOrderCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerContainer(
      child: Container(
        margin: EdgeInsets.only(bottom: 14.h),
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SkeletonBox(width: 50.w, height: 50.h, borderRadius: 12),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140.w, height: 16.h, borderRadius: 4),
                      SizedBox(height: 6.h),
                      SkeletonBox(width: 100.w, height: 12.h, borderRadius: 4),
                    ],
                  ),
                ),
                SkeletonBox(width: 60.w, height: 22.h, borderRadius: 12),
              ],
            ),
            SizedBox(height: 12.h),
            SkeletonBox(width: double.infinity, height: 1.h),
            SizedBox(height: 12.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonBox(width: 80.w, height: 14.h, borderRadius: 4),
                SkeletonBox(width: 90.w, height: 32.h, borderRadius: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Pre-built list of order skeleton cards.
class SkeletonOrderList extends StatelessWidget {
  final int count;

  const SkeletonOrderList({super.key, this.count = 3});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: List.generate(
          count,
          (index) => const SkeletonOrderCard(),
        ),
      ),
    );
  }
}

/// Pre-built skeleton for Order Tracking Screen.
class SkeletonOrderTracking extends StatelessWidget {
  const SkeletonOrderTracking({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerContainer(
      child: Padding(
        padding: EdgeInsets.all(20.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: double.infinity, height: 220.h, borderRadius: 24),
            SizedBox(height: 20.h),
            SkeletonBox(width: 180.w, height: 20.h, borderRadius: 4),
            SizedBox(height: 8.h),
            SkeletonBox(width: 120.w, height: 14.h, borderRadius: 4),
            SizedBox(height: 24.h),
            SkeletonBox(width: double.infinity, height: 120.h, borderRadius: 18),
          ],
        ),
      ),
    );
  }
}

/// Pre-built skeleton for Notifications.
class SkeletonNotificationList extends StatelessWidget {
  final int count;

  const SkeletonNotificationList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ShimmerContainer(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: List.generate(
            count,
            (index) => Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(14.r),
              child: Row(
                children: [
                  SkeletonBox(width: 44.w, height: 44.h, borderRadius: 22),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 150.w, height: 16.h, borderRadius: 4),
                        SizedBox(height: 6.h),
                        SkeletonBox(width: 220.w, height: 12.h, borderRadius: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pre-built skeleton for Chat Screen.
class SkeletonChatList extends StatelessWidget {
  const SkeletonChatList({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerContainer(
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SkeletonBox(width: 200.w, height: 40.h, borderRadius: 16),
            ),
            SizedBox(height: 12.h),
            Align(
              alignment: Alignment.centerRight,
              child: SkeletonBox(width: 160.w, height: 40.h, borderRadius: 16),
            ),
            SizedBox(height: 12.h),
            Align(
              alignment: Alignment.centerLeft,
              child: SkeletonBox(width: 240.w, height: 50.h, borderRadius: 16),
            ),
          ],
        ),
      ),
    );
  }
}
