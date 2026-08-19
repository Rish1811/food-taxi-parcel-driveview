import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/skeletons/skeleton_loading.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/veg_filter_provider.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/viewmodels/restaurant_detail_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/widgets/food_detail_sheet.dart';
import 'package:superapp_user/modules/food/presentation/cart/animations/add_to_cart_animation.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';

class CartRecommendationsSection extends ConsumerStatefulWidget {
  final String restaurantId;
  final GlobalKey? targetCartKey;

  const CartRecommendationsSection({
    super.key,
    required this.restaurantId,
    this.targetCartKey,
  });

  @override
  ConsumerState<CartRecommendationsSection> createState() => _CartRecommendationsSectionState();
}

class _CartRecommendationsSectionState extends ConsumerState<CartRecommendationsSection> {
  int _selectedTabIndex = 0;

  final List<String> _categories = const ['Popular', 'Beverages', 'Sides'];

  List<FoodModel> _filterItemsForTab(List<FoodModel> items, int tabIndex) {
    if (items.isEmpty) return [];

    switch (tabIndex) {
      case 0: // Popular
        final popular = items.where((f) => f.isPopular).toList();
        return popular.isNotEmpty ? popular : items.take(6).toList();

      case 1: // Beverages
        final drinksKeywords = [
          'drink', 'beverage', 'coffee', 'tea', 'frappuccino', 'mojito', 
          'soda', 'shake', 'juice', 'cold', 'coke', 'pepsi', 'lassi', 'water', 'chai'
        ];
        final beverages = items.where((f) {
          final text = '${f.name} ${f.description}'.toLowerCase();
          return drinksKeywords.any((keyword) => text.contains(keyword));
        }).toList();

        return beverages;

      case 2: // Sides
        final sidesKeywords = [
          'fries', 'side', 'roti', 'paratha', 'bread', 'muffin', 'sandwich',
          'dosa', 'starter', 'snack', 'sauce', 'dip', 'nuggets', 'wedges', 'salad', 'khichdi'
        ];
        final sides = items.where((f) {
          final text = '${f.name} ${f.description}'.toLowerCase();
          return sidesKeywords.any((keyword) => text.contains(keyword));
        }).toList();

        return sides;

      default:
        return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;

    final menuAsync = ref.watch(restaurantMenuProvider(widget.restaurantId));
    final isVegOnly = ref.watch(vegFilterProvider);

    return menuAsync.when(
      data: (items) {
        final rawItems = isVegOnly ? items.where((f) => f.isVeg).toList() : items;
        final filteredItems = _filterItemsForTab(rawItems, _selectedTabIndex);
        if (filteredItems.isEmpty && rawItems.isEmpty) {
          return const SizedBox.shrink();
        }
        final displayItems = filteredItems.isNotEmpty ? filteredItems : rawItems;
        if (displayItems.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row with circular icon and section title
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.grid_view_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : const Color(0xFF344054),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Complete your meal with',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Category Tabs Row (Popular, Beverages, Sides)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF262626) : const Color(0xFFF2F4F7),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: List.generate(_categories.length, (index) {
                    final isSelected = _selectedTabIndex == index;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Haptics.light();
                          setState(() => _selectedTabIndex = index);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark ? const Color(0xFF383838) : Colors.white)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: isSelected && !isDark
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.06),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Text(
                              _categories[index],
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected
                                    ? (isDark ? Colors.white : const Color(0xFF1D2939))
                                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 14),

              // Horizontal Scrollable Products List
              SizedBox(
                height: 222,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: displayItems.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final food = displayItems[index];
                    return _RecommendationProductCard(
                      food: food,
                      targetCartKey: widget.targetCartKey,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                      isDark: isDark,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        height: 220,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const SkeletonFoodItemCard(),
      ),
      error: (error, stackTrace) => const SizedBox.shrink(),
    );
  }
}

class _RecommendationProductCard extends ConsumerStatefulWidget {
  final FoodModel food;
  final GlobalKey? targetCartKey;
  final Color textColor;
  final Color secondaryTextColor;
  final bool isDark;

  const _RecommendationProductCard({
    required this.food,
    required this.targetCartKey,
    required this.textColor,
    required this.secondaryTextColor,
    required this.isDark,
  });

  @override
  ConsumerState<_RecommendationProductCard> createState() => _RecommendationProductCardState();
}

class _RecommendationProductCardState extends ConsumerState<_RecommendationProductCard> {
  final GlobalKey _imageKey = GlobalKey();

  void _onAddToCart() {
    Haptics.light();
    final targetKey = widget.targetCartKey;
    if (targetKey == null || targetKey.currentContext == null) {
      ref.read(cartViewModelProvider.notifier).addItem(widget.food);
      Haptics.medium();
      return;
    }

    AddToCartAnimation.run(
      context: context,
      startKey: _imageKey,
      endKey: targetKey,
      imageUrl: widget.food.imageUrl,
      onAnimationComplete: () {
        ref.read(cartViewModelProvider.notifier).addItem(widget.food);
        Haptics.medium();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final vegColor = food.isVeg ? const Color(0xFF2E8B57) : const Color(0xFFB33A3A);

    return GestureDetector(
      onTap: () {
        Haptics.light();
        FoodDetailSheet.show(context, food);
      },
      child: SizedBox(
        width: 125,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Food Image with Veg/Non-Veg badge and floating "+" button
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Image container
                ClipRRect(
                  key: _imageKey,
                  borderRadius: BorderRadius.circular(14),
                  child: SmartImage(
                    url: food.imageUrl,
                    category: ImageCategory.food,
                    width: 125,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),

                // Veg / Non-Veg Indicator at Bottom Left
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        border: Border.all(color: vegColor, width: 1.5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Center(
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: vegColor,
                            shape: food.isVeg ? BoxShape.circle : BoxShape.rectangle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Floating Plus / Add Button at Bottom Right
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 2,
                    shadowColor: Colors.black26,
                    child: InkWell(
                      onTap: _onAddToCart,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.add_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // Product Name
            Text(
              food.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: widget.textColor,
                height: 1.15,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 3),

            // Price
            Text(
              '₹${food.price.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
