import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/app/routing/route_names.dart';

class EmptyCartView extends ConsumerWidget {
  const EmptyCartView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryColor =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20.h),

              // 1. Custom Basket Artwork & Glow
              SizedBox(
                height: 200.h,
                width: double.infinity,
                child: CustomPaint(
                  painter: _BasketIllustrationPainter(isDark: isDark),
                ),
              ),

              SizedBox(height: 24.h),

              // 2. Title
              Text(
                'Your cart is empty',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 8.h),

              // 3. Subtitle
              Text(
                'Looks like you haven\'t added anything\nto your cart yet.',
                style: TextStyle(
                  fontSize: 13.5.sp,
                  color: secondaryColor,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: 24.h),

              // 4. Start Shopping CTA Button
              SizedBox(
                width: 240.w,
                height: 48.h,
                child: ElevatedButton(
                  onPressed: () {
                    Haptics.medium();
                    context.go(RouteNames.home);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  child: Text(
                    'Start Shopping',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 32.h),

              // 5. Explore Popular Categories Section
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Explore popular categories',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ),

              SizedBox(height: 14.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCategoryCard(
                    context: context,
                    title: 'Meals',
                    icon: Icons.lunch_dining_rounded,
                    bgColor: const Color(0xFFFFF0ED),
                    iconColor: const Color(0xFFEA580C),
                    isDark: isDark,
                  ),
                  _buildCategoryCard(
                    context: context,
                    title: 'Pizza',
                    icon: Icons.local_pizza_rounded,
                    bgColor: const Color(0xFFFFF7ED),
                    iconColor: const Color(0xFFF97316),
                    isDark: isDark,
                  ),
                  _buildCategoryCard(
                    context: context,
                    title: 'Desserts',
                    icon: Icons.cake_rounded,
                    bgColor: const Color(0xFFFFF1F2),
                    iconColor: const Color(0xFFE11D48),
                    isDark: isDark,
                  ),
                  _buildCategoryCard(
                    context: context,
                    title: 'Beverages',
                    icon: Icons.local_drink_rounded,
                    bgColor: const Color(0xFFF0FDF4),
                    iconColor: const Color(0xFF16A34A),
                    isDark: isDark,
                  ),
                ],
              ),

              SizedBox(height: 20.h),

              // 6. Exclusive Offers Banner Card
              GestureDetector(
                onTap: () {
                  Haptics.medium();
                  context.push(RouteNames.store99);
                },
                child: Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A221B)
                        : const Color(0xFFFFF5EE),
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF4A3525)
                          : const Color(0xFFFFE6D5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38.r,
                        height: 38.r,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF3D2B1F)
                              : const Color(0xFFFFEBDC),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.percent_rounded,
                          size: 18.sp,
                          color: const Color(0xFFFF5200),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Exclusive offers!',
                              style: TextStyle(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Grab the best deals and save more.',
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                color: secondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20.sp,
                        color: const Color(0xFFFF5200),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(height: 20.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required bool isDark,
  }) {
    final itemWidth = (1.sw - 40.w - 36.w) / 4;

    return GestureDetector(
      onTap: () {
        Haptics.light();
        context.push('${RouteNames.search}?query=$title');
      },
      child: Container(
        width: itemWidth,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              decoration: BoxDecoration(
                color: isDark ? iconColor.withValues(alpha: 0.2) : bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 22.sp,
                color: iconColor,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _BasketIllustrationPainter extends CustomPainter {
  final bool isDark;

  _BasketIllustrationPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 5);

    // 1. Soft Circular Background Glow
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFFF0E6),
          const Color(0xFFFFF4EC).withValues(alpha: 0.7),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: 90));
    canvas.drawCircle(center, 90, bgPaint);

    // Ambient sparkle lines & dots
    final sparklePaint = Paint()
      ..color = const Color(0xFFFF9E7A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Small ambient circle top-left
    canvas.drawCircle(Offset(center.dx - 55, center.dy - 60), 4, sparklePaint);

    // Sparkle top-right
    final pathSparkle = Path();
    pathSparkle.moveTo(center.dx + 52, center.dy - 62);
    pathSparkle.quadraticBezierTo(center.dx + 52, center.dy - 57, center.dx + 57, center.dy - 57);
    pathSparkle.quadraticBezierTo(center.dx + 52, center.dy - 57, center.dx + 52, center.dy - 52);
    pathSparkle.quadraticBezierTo(center.dx + 52, center.dy - 57, center.dx + 47, center.dy - 57);
    pathSparkle.quadraticBezierTo(center.dx + 52, center.dy - 57, center.dx + 52, center.dy - 62);
    canvas.drawPath(pathSparkle, sparklePaint);

    // Radiating sunburst lines top
    final rayPaint = Paint()
      ..color = const Color(0xFFFF7A00)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(center.dx - 18, center.dy - 65), Offset(center.dx - 10, center.dy - 55), rayPaint);
    canvas.drawLine(Offset(center.dx, center.dy - 68), Offset(center.dx, center.dy - 56), rayPaint);
    canvas.drawLine(Offset(center.dx + 18, center.dy - 65), Offset(center.dx + 10, center.dy - 55), rayPaint);

    // Ground Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(center.dx, center.dy + 38), width: 130, height: 14),
      shadowPaint,
    );

    // Basket Handles (Dual Leaning Handles)
    final handlePaint = Paint()
      ..color = const Color(0xFF2C3E50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    final leftHandle = Path()
      ..moveTo(center.dx - 40, center.dy - 2)
      ..lineTo(center.dx - 20, center.dy - 40);
    final rightHandle = Path()
      ..moveTo(center.dx + 40, center.dy - 2)
      ..lineTo(center.dx + 20, center.dy - 40);

    canvas.drawPath(leftHandle, handlePaint);
    canvas.drawPath(rightHandle, handlePaint);

    // Basket Main Body
    final basketRect = RRect.fromRectAndCorners(
      Rect.fromLTRB(center.dx - 52, center.dy - 5, center.dx + 52, center.dy + 34),
      topLeft: const Radius.circular(6),
      topRight: const Radius.circular(6),
      bottomLeft: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );

    final basketPaint = Paint()
      ..color = const Color(0xFFFF6A00)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(basketRect, basketPaint);

    // Top Rim Bar
    final rimRect = RRect.fromRectAndRadius(
      Rect.fromLTRB(center.dx - 58, center.dy - 12, center.dx + 58, center.dy - 2),
      const Radius.circular(5),
    );
    final rimPaint = Paint()
      ..color = const Color(0xFFFF8533)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rimRect, rimPaint);

    // Basket Front Slots (5 Vertical Slits)
    final slotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95)
      ..style = PaintingStyle.fill;

    for (int i = -2; i <= 2; i++) {
      final slotX = center.dx + (i * 13.5);
      final slotRect = RRect.fromRectAndRadius(
        Rect.fromLTRB(slotX - 2.2, center.dy + 3, slotX + 2.2, center.dy + 25),
        const Radius.circular(3),
      );
      canvas.drawRRect(slotRect, slotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _BasketIllustrationPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
