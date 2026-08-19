import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/modules/food/application/providers/catalog_providers.dart';
import 'package:superapp_user/design_system/components/skeletons/skeleton_loading.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/screens/food_detail_screen.dart';

/// Screen responsible for resolving a product from deep link parameters (foodId & restaurantId)
/// and displaying either the resolved product detail screen or an error fallback.
class FoodDetailLoaderScreen extends ConsumerWidget {
  final String foodId;
  final String restaurantId;

  const FoodDetailLoaderScreen({
    super.key,
    required this.foodId,
    required this.restaurantId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (foodId.isEmpty) {
      return _buildErrorState(context, isDark, 'Invalid product link.');
    }

    final foodAsync = ref.watch(
      foodByIdProvider((foodId: foodId, restaurantId: restaurantId)),
    );

    return foodAsync.when(
      loading: () => Scaffold(
        backgroundColor: isDark
            ? AppColors.backgroundDark
            : const Color(0xFFFAFAFA),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: SkeletonRestaurantList(count: 3),
          ),
        ),
      ),
      error: (err, stack) => _buildErrorState(
        context,
        isDark,
        'Unable to load product. Link may be expired.',
      ),
      data: (food) {
        if (food == null) {
          return _buildErrorState(
            context,
            isDark,
            'This dish is currently unavailable.',
          );
        }
        return FoodDetailScreen(food: food);
      },
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark, String message) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.home);
            }
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Product Not Found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                onPressed: () => context.go(RouteNames.home),
                icon: const Icon(Icons.home_rounded, size: 18),
                label: const Text(
                  'GO TO HOME',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
