import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/veg_filter_provider.dart';

class NearbyRestaurantsList extends ConsumerWidget {
  final List<RestaurantModel> restaurants;

  const NearbyRestaurantsList({super.key, required this.restaurants});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVegOnly = ref.watch(vegFilterProvider);
    final displayList = isVegOnly
        ? restaurants.where((r) => r.isPureVeg).toList()
        : restaurants;

    if (displayList.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 146.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: displayList.length,
        separatorBuilder: (context, index) => SizedBox(width: 14.w),
        itemBuilder: (context, index) {
          final target = displayList[index];
          final infoParts = <String>[
            if (target.priceForOne > 0) '₹${target.priceForOne.toStringAsFixed(0)} for one',
            if (target.isFreeDelivery || target.deliveryFee == 0)
              'Free Delivery'
            else if (target.deliveryFee > 0)
              '₹${target.deliveryFee.toStringAsFixed(0)} Delivery',
            if (target.tags.isNotEmpty) target.tags.first,
          ];
          final info = infoParts.join(' • ');
          return GestureDetector(
            onTap: () {
              Haptics.light();
              context.push(RouteNames.restaurantDetail, extra: target);
            },
            child: SizedBox(
              width: 160.w,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner Image + Brand Logo Badge + Time Tag
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16.r),
                        child: SmartImage(
                          url: target.imageUrl,
                          category: ImageCategory.restaurant,
                          height: 105.h,
                          width: 160.w,
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Time Tag Top Right
                      if (target.deliveryTime.isNotEmpty)
                        Positioned(
                          top: 6.h,
                          right: 6.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              target.deliveryTime,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      // Brand Logo Overlay Bottom Left
                      Positioned(
                        bottom: 6.h,
                        left: 6.w,
                        child: Container(
                          width: 32.w,
                          height: 32.h,
                          padding: EdgeInsets.all(2.r),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: ClipOval(
                            child: SmartImage(
                              url: target.imageUrl,
                              category: ImageCategory.brand,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          target.name,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (target.rating > 0)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.star, color: Colors.white, size: 9.sp),
                              SizedBox(width: 2.w),
                              Text(
                                target.rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    info,
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
