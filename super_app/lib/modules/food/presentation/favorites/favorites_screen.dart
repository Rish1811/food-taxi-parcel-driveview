import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/media/empty_state_widget.dart';
import 'package:superapp_user/design_system/components/skeletons/skeleton_loading.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/home_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/veg_filter_provider.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/widgets/food_detail_sheet.dart';
import 'package:superapp_user/modules/food/presentation/favorites/viewmodels/favorites_viewmodel.dart';

/// Favorites Screen with tabs for Restaurants & Dishes.
class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final nearbyRestaurants =
        ref.watch(homeViewModelProvider).nearbyRestaurants.asData?.value ??
            const <RestaurantModel>[];
    final favoritesAsync = ref.watch(favoritesViewModelProvider);
    final isVegOnly = ref.watch(vegFilterProvider);

    if (favoritesAsync.isLoading && !favoritesAsync.hasValue) {
      return const Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: SkeletonRestaurantList(count: 3),
          ),
        ),
      );
    }

    final favState = favoritesAsync.value ?? const FavoritesState();

    // 1. Combine restaurants from nearby + backend favorites
    final Map<String, RestaurantModel> restaurantMap = {};
    for (final r in nearbyRestaurants) {
      restaurantMap[r.id] = r;
    }
    for (final r in favState.restaurants) {
      restaurantMap[r.id] = r;
    }

    var favRestaurants = restaurantMap.values
        .where((r) => favState.restaurantIds.contains(r.id))
        .toList();

    if (isVegOnly) {
      favRestaurants = favRestaurants.where((r) => r.isPureVeg).toList();
    }

    // 2. Favorite Foods
    var favFoods = favState.foods;
    if (isVegOnly) {
      favFoods = favFoods.where((f) => f.isVeg).toList();
    }

    final totalCount = favRestaurants.length + favFoods.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Column(
                children: [
                  _buildHeader(context, totalCount, textColor, secondaryColor),
                  const SizedBox(height: 16),
                  Container(
                    height: 42.h,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicator: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: secondaryColor,
                      labelStyle: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: 'Restaurants (${favRestaurants.length})'),
                        Tab(text: 'Dishes (${favFoods.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Restaurants Tab
                  favRestaurants.isEmpty
                      ? const EmptyStateWidget(
                          title: 'No favorite restaurants',
                          subtitle:
                              'Tap the heart on any restaurant to save it here for quick access later.',
                          icon: Icons.favorite_border_rounded,
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          children: [
                            _buildPromoBanner(isDark, textColor),
                            const SizedBox(height: 20),
                            for (final restaurant in favRestaurants)
                              _FavoriteRestaurantCard(
                                restaurant: restaurant,
                                isDark: isDark,
                                onToggleFavorite: () {
                                  Haptics.medium();
                                  ref
                                      .read(favoritesViewModelProvider.notifier)
                                      .toggle(restaurant.id, restaurant);
                                },
                              ),
                          ],
                        ),

                  // Dishes Tab
                  favFoods.isEmpty
                      ? const EmptyStateWidget(
                          title: 'No favorite dishes',
                          subtitle:
                              'Tap the heart on any food item to save it here for fast ordering.',
                          icon: Icons.fastfood_rounded,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: favFoods.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final food = favFoods[index];
                            return _FavoriteFoodCard(
                              food: food,
                              isDark: isDark,
                              onTap: () {
                                Haptics.light();
                                FoodDetailSheet.show(context, food);
                              },
                              onToggleFavorite: () {
                                Haptics.medium();
                                ref
                                    .read(favoritesViewModelProvider.notifier)
                                    .toggleFood(food.id, food);
                              },
                            );
                          },
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, int count, Color textColor, Color secondaryColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Favorites',
                style: TextStyle(
                  fontSize: 26.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    'Your saved favorites',
                    style: TextStyle(fontSize: 13.sp, color: secondaryColor),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFF7A00),
                    size: 14,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF7A00),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromoBanner(bool isDark, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : const Color(0xFFFDF3E7),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.h,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite_rounded,
              color: Color(0xFFFF7A00),
              size: 20,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick re-orders made easy',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Everything you love, all in one place.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FavoriteRestaurantCard extends StatelessWidget {
  final RestaurantModel restaurant;
  final bool isDark;
  final VoidCallback onToggleFavorite;

  const _FavoriteRestaurantCard({
    required this.restaurant,
    required this.isDark,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: InkWell(
        onTap: () {
          Haptics.light();
          context.push('${RouteNames.restaurantDetail}/${restaurant.id}', extra: restaurant);
        },
        borderRadius: BorderRadius.circular(16.r),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(16.r)),
                  child: SmartImage(
                    url: restaurant.imageUrl,
                    category: ImageCategory.restaurant,
                    height: 140.h,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: InkWell(
                    onTap: onToggleFavorite,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Color(0xFFFF7A00),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          restaurant.name,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          restaurant.tags.join(' • '),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: secondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade700,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${restaurant.rating}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteFoodCard extends StatelessWidget {
  final FoodModel food;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _FavoriteFoodCard({
    required this.food,
    required this.isDark,
    required this.onTap,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: SmartImage(
                  url: food.imageUrl,
                  category: ImageCategory.food,
                  width: 80.w,
                  height: 80.h,
                  fit: BoxFit.cover,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.circle,
                          color: food.isVeg ? Colors.green : Colors.red,
                          size: 12,
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            food.name,
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '₹${food.price.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    if (food.description.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        food.description,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: secondaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              InkWell(
                onTap: onToggleFavorite,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFF7A00),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
