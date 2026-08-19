import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/modules/food/presentation/cart/utils/cart_restaurant_guard.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/cart/widgets/floating_view_cart_bar.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/widgets/food_detail_sheet.dart';

class PopularItemsList extends ConsumerWidget {
  final List<FoodModel> foods;
  final List<RestaurantModel> restaurants;
  final GlobalKey<FloatingViewCartBarState>? cartBarKey;
  final VoidCallback? onAddToCartAnimationComplete;

  const PopularItemsList({
    super.key,
    required this.foods,
    this.restaurants = const [],
    this.cartBarKey,
    this.onAddToCartAnimationComplete,
  });

  /// Card width and total card height — sized to match content cleanly.
  static const double _cardWidth = 132;
  static const double _cardHeight = 162;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eligibleFoods = foods.where((f) => f.price <= 99.0).toList();
    if (eligibleFoods.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Logo 99 STORE + Subtitle + View All
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Row(
            children: [
              Container(
                width: 32.w,
                height: 32.h,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Text(
                    '99',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.sp,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '99 STORE',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                        size: 12.sp,
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        'Meals at ₹99 + Free Delivery',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  Haptics.light();
                  context.push(RouteNames.store99);
                },
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5.sp,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.primary,
                      size: 16.sp,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),

        // 2-row horizontal-scrolling grid
        SizedBox(
          height: _cardHeight.h * 2 + 10.h,
          child: GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: eligibleFoods.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10.w,
              crossAxisSpacing: 10.h,
              mainAxisExtent: _cardWidth.w,
            ),
            itemBuilder: (context, index) {
              final food = eligibleFoods[index];
              return _Home99ProductCard(
                food: food,
                isDark: isDark,
                cartBarKey: cartBarKey,
                onAddToCartAnimationComplete: onAddToCartAnimationComplete,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Home99ProductCard extends ConsumerStatefulWidget {
  final FoodModel food;
  final bool isDark;
  final GlobalKey<FloatingViewCartBarState>? cartBarKey;
  final VoidCallback? onAddToCartAnimationComplete;

  const _Home99ProductCard({
    required this.food,
    required this.isDark,
    this.cartBarKey,
    this.onAddToCartAnimationComplete,
  });

  @override
  ConsumerState<_Home99ProductCard> createState() => _Home99ProductCardState();
}

class _Home99ProductCardState extends ConsumerState<_Home99ProductCard> {
  final GlobalKey _imageKey = GlobalKey();

  Future<void> _handleFirstAddToCart() async {
    Haptics.light();
    await addFoodToCart(context, ref, widget.food);
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartViewModelProvider);

    // Find quantity and cart item ID for this food
    int quantity = 0;
    String? cartItemId;
    for (final item in cartState.items) {
      if (item.food.id == widget.food.id) {
        quantity = item.quantity;
        cartItemId = item.id;
        break;
      }
    }

    final secondary = widget.isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final hasQty = quantity > 0;

    return GestureDetector(
      onTap: () {
        Haptics.light();
        FoodDetailSheet.show(context, widget.food);
      },
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.surfaceDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: widget.isDark
              ? []
              : [
                  BoxShadow(
                    color: AppColors.shadow1,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image + rating badge (bottom-left) + animated add/counter button (bottom-right).
            SizedBox(
              height: 92.h,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16.r),
                    ),
                    child: SmartImage(
                      key: _imageKey,
                      url: widget.food.imageUrl,
                      category: ImageCategory.food,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (widget.food.rating > 0)
                    Positioned(
                      bottom: 6.h,
                      left: 6.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: Colors.white,
                              size: 11.sp,
                            ),
                            SizedBox(width: 2.w),
                            Text(
                              widget.food.rating.toStringAsFixed(1),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Animated Morphing Add / Counter Button matching design 100%
                  Positioned(
                    bottom: 6.h,
                    right: 6.w,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      width: hasQty ? 68.w : 28.r,
                      height: 28.r,
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? AppColors.surfaceDark
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14.r),
                        border: Border.all(
                          color: hasQty
                              ? AppColors.primary
                              : (widget.isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight),
                          width: hasQty ? 1.2 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: widget.isDark ? 0.3 : 0.15,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, anim) => ScaleTransition(
                            scale: anim,
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: !hasQty
                              ? InkWell(
                                  key: const ValueKey('home_99_add_btn'),
                                  onTap: _handleFirstAddToCart,
                                  borderRadius: BorderRadius.circular(14.r),
                                  child: Center(
                                    child: Icon(
                                      Icons.add,
                                      color: AppColors.primary,
                                      size: 18.sp,
                                    ),
                                  ),
                                )
                              : Row(
                                  key: const ValueKey('home_99_stepper'),
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    InkWell(
                                      onTap: cartItemId == null
                                          ? null
                                          : () {
                                              Haptics.light();
                                              ref
                                                  .read(
                                                    cartViewModelProvider
                                                        .notifier,
                                                  )
                                                  .updateQuantity(
                                                    cartItemId!,
                                                    quantity - 1,
                                                  );
                                            },
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(14.r),
                                        bottomLeft: Radius.circular(14.r),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 4.w,
                                        ),
                                        child: Icon(
                                          Icons.remove,
                                          color: AppColors.primary,
                                          size: 14.sp,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '$quantity',
                                      style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5.sp,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        Haptics.light();
                                        // Through the shared helper, not
                                        // addItem directly: for a dish with
                                        // sizes this must ask again rather than
                                        // silently adding a sizeless unit that
                                        // checkout will reject.
                                        addFoodToCart(context, ref, widget.food);
                                      },
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(14.r),
                                        bottomRight: Radius.circular(14.r),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 4.w,
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          color: AppColors.primary,
                                          size: 14.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details — name, time, price.
            Padding(
              padding: EdgeInsets.fromLTRB(8.r, 6.r, 8.r, 6.r),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.food.name,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: widget.isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.food.deliveryTime.isNotEmpty) ...[
                    SizedBox(height: 3.h),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 10.5.sp,
                          color: secondary,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          widget.food.deliveryTime,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: 3.h),
                  Text(
                    '₹${widget.food.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
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
