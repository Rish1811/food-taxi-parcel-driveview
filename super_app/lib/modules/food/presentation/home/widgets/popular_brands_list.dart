import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';
import 'package:superapp_user/app/routing/route_names.dart';

class PopularBrandsList extends StatelessWidget {
  final List<RestaurantModel> restaurants;

  const PopularBrandsList({
    super.key,
    required this.restaurants,
  });

  @override
  Widget build(BuildContext context) {
    if (restaurants.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sized to the avatar + two text lines actually rendered — was 88,
    // leaving dead space below every chip before the section gap started.
    return SizedBox(
      height: 82.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: restaurants.length,
        itemBuilder: (context, index) {
          final restaurant = restaurants[index];
          final name = restaurant.name;
          final time = restaurant.deliveryTime;
          final logo = restaurant.imageUrl;

          return GestureDetector(
            onTap: () {
              Haptics.light();
              context.push(RouteNames.restaurantDetail, extra: restaurant);
            },
            child: Container(
              width: 72.w,
              margin: EdgeInsets.only(right: 12.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Circular Brand Logo Avatar Container
                  Container(
                    width: 48.w,
                    height: 48.h,
                    padding: EdgeInsets.all(7.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
                        width: 1.0,
                      ),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: AppColors.shadow1,
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: ClipOval(
                      child: SmartImage(
                        url: logo,
                        category: ImageCategory.restaurant,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),

                  // Brand Title
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 1.h),

                  // Delivery Time
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF757575),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
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
