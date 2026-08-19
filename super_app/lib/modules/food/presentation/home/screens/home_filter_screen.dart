import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/app/routing/back_navigation.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/layout/app_refresh_indicator.dart';
import 'package:superapp_user/design_system/components/skeletons/skeleton_loading.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/home_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/near_you_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/home/widgets/restaurant_card.dart';

/// Filter screen arguments passed when opening from quick filter pills.
class HomeFilterArgs {
  final String title;
  final String emptyMessage;
  final IconData emptyIcon;
  final bool Function(RestaurantModel) matches;

  const HomeFilterArgs({
    required this.title,
    required this.emptyMessage,
    required this.matches,
    this.emptyIcon = Icons.restaurant_menu_rounded,
  });
}

class HomeFilterScreen extends ConsumerWidget {
  final HomeFilterArgs args;
  const HomeFilterScreen({super.key, required this.args});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final bool isNearYou = args.title.trim().toLowerCase() == 'near you';

    // Select provider based on whether this is the dedicated Near You screen
    final AsyncValue<List<RestaurantModel>> restaurantsAsync;
    if (isNearYou) {
      restaurantsAsync = ref.watch(nearYouViewModelProvider).restaurants;
    } else {
      restaurantsAsync = ref.watch(homeViewModelProvider).nearbyRestaurants;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => context.backOr(),
        ),
        title: Text(
          args.title,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 17.sp,
          ),
        ),
      ),
      body: AppRefreshIndicator(
        onRefresh: () async {
          if (isNearYou) {
            await ref.read(nearYouViewModelProvider.notifier).loadNearbyRestaurants(isRefresh: true);
          } else {
            await ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);
          }
        },
        child: restaurantsAsync.when(
          loading: () => Padding(
            padding: EdgeInsets.all(20.r),
            child: const SkeletonRestaurantList(count: 3),
          ),
          error: (err, stack) => _buildErrorState(
            context,
            ref,
            isDark: isDark,
            textColor: textColor,
            secondaryTextColor: secondaryTextColor,
            isNearYou: isNearYou,
          ),
          data: (restaurants) {
            final matched = isNearYou ? restaurants : restaurants.where(args.matches).toList();

            if (matched.isEmpty) {
              return _buildEmptyState(
                context,
                ref,
                isDark: isDark,
                textColor: textColor,
                secondaryTextColor: secondaryTextColor,
                isNearYou: isNearYou,
              );
            }

            return ListView.builder(
              padding: EdgeInsets.only(top: 12.h, bottom: 28.h),
              itemCount: matched.length,
              itemBuilder: (context, index) => RestaurantCard(
                restaurant: matched[index],
                index: index,
              ),
            );
          },
        ),
      ),
    );
  }

  /// Redesigned Empty State UI
  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref, {
    required bool isDark,
    required Color textColor,
    required Color secondaryTextColor,
    required bool isNearYou,
  }) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 48.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 20.h),
            // Premium Gradient Illustration Avatar
            Container(
              width: 120.r,
              height: 120.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    const Color(0xFFFF9E80).withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Container(
                  width: 80.r,
                  height: 80.r,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    args.emptyIcon,
                    color: AppColors.primary,
                    size: 42.sp,
                  ),
                ),
              ),
            ),
            SizedBox(height: 28.h),

            // Heading
            Text(
              isNearYou ? 'No restaurants nearby' : args.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
            SizedBox(height: 12.h),

            // Subtitle
            Text(
              isNearYou
                  ? "We couldn't find any restaurants delivering to your current location. Try changing your delivery address or check back later."
                  : args.emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5.sp,
                color: secondaryTextColor,
                height: 1.45,
              ),
            ),
            SizedBox(height: 32.h),

            // Primary Button: Change Address
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton.icon(
                onPressed: () {
                  Haptics.light();
                  context.push(RouteNames.addAddress);
                },
                icon: Icon(Icons.location_on_rounded, size: 20.sp, color: Colors.white),
                label: Text(
                  'Change Address',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
              ),
            ),
            SizedBox(height: 14.h),

            // Secondary Button: Refresh
            TextButton.icon(
              onPressed: () {
                Haptics.light();
                if (isNearYou) {
                  ref.read(nearYouViewModelProvider.notifier).loadNearbyRestaurants(isRefresh: true);
                } else {
                  ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);
                }
              },
              icon: Icon(Icons.refresh_rounded, size: 18.sp, color: AppColors.primary),
              label: Text(
                'Refresh',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  /// Friendly Error State UI
  Widget _buildErrorState(
    BuildContext context,
    WidgetRef ref, {
    required bool isDark,
    required Color textColor,
    required Color secondaryTextColor,
    required bool isNearYou,
  }) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 48.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 20.h),
            Container(
              width: 100.r,
              height: 100.r,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: Colors.redAccent,
                size: 46.sp,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              "Couldn't load nearby restaurants",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              'Please check your connection and location settings and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5.sp,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
            SizedBox(height: 28.h),
            ElevatedButton(
              onPressed: () {
                Haptics.light();
                if (isNearYou) {
                  ref.read(nearYouViewModelProvider.notifier).loadNearbyRestaurants(isRefresh: true);
                } else {
                  ref.read(homeViewModelProvider.notifier).loadHomeData(isRefresh: true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
              ),
              child: Text(
                'Try Again',
                style: TextStyle(
                  fontSize: 14.5.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
