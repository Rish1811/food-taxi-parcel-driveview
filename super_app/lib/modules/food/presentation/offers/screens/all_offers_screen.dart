import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/app/routing/back_navigation.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/modules/food/presentation/cart/widgets/floating_view_cart_bar.dart';
import 'package:superapp_user/design_system/components/media/empty_state_widget.dart';
import 'package:superapp_user/design_system/components/skeletons/skeleton_loading.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/home_viewmodel.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/widgets/food_item_card.dart';

/// Full listing behind the 99 Store rail's "View All" — same
/// [homeViewModelProvider.popularFoods] the rail itself shows dynamically,
/// just as a scrollable vertical list instead of a horizontal peek.
class AllOffersScreen extends ConsumerStatefulWidget {
  const AllOffersScreen({super.key});

  @override
  ConsumerState<AllOffersScreen> createState() => _AllOffersScreenState();
}

class _AllOffersScreenState extends ConsumerState<AllOffersScreen> {
  final GlobalKey<FloatingViewCartBarState> _cartBarKey =
      GlobalKey<FloatingViewCartBarState>();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final foodsAsync = ref.watch(homeViewModelProvider).popularFoods;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => context.backOr(),
        ),
        title: Text(
          '99 Store',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          foodsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: SkeletonRestaurantList(count: 3),
            ),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (foods) {
              final eligibleFoods =
                  foods.where((f) => f.price <= 99.0).toList();
              if (eligibleFoods.isEmpty) {
                return const EmptyStateWidget(
                  title: 'No ₹99 Store deals available right now.',
                  subtitle: 'Check back soon for meals at ₹99 with free delivery.',
                  icon: Icons.local_offer_outlined,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                itemCount: eligibleFoods.length,
                itemBuilder: (context, index) {
                  final food = eligibleFoods[index];
                  return GestureDetector(
                    onTap: () {
                      Haptics.light();
                      context.push(RouteNames.foodDetail, extra: food);
                    },
                    child: FoodItemCard(food: food, cartBarKey: _cartBarKey),
                  );
                },
              );
            },
          ),

          // Floating View Cart bar (primary cart entry point on this screen).
          FloatingViewCartBar(
            key: _cartBarKey,
            onTap: () {
              Haptics.light();
              context.go(RouteNames.cart);
            },
          ),
        ],
      ),
    );
  }
}
