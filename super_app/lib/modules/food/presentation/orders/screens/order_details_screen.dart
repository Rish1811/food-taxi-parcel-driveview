import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/app/routing/back_navigation.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/modules/food/presentation/cart/utils/cart_restaurant_guard.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';
import 'package:superapp_user/design_system/components/skeletons/skeleton_loading.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/modules/food/presentation/orders/utils/reorder.dart';
import 'package:superapp_user/modules/food/presentation/orders/viewmodels/orders_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/orders/widgets/order_details_header.dart';
import 'package:superapp_user/modules/food/presentation/orders/widgets/order_timeline_card.dart';
import 'package:superapp_user/modules/food/presentation/orders/widgets/price_details_card.dart';
import 'package:superapp_user/modules/food/presentation/orders/widgets/previous_conversations_card.dart';

class OrderDetailsScreen extends ConsumerWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancel Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Are you sure you want to cancel this order?'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for cancellation (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('NO, KEEP ORDER'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final err = await ref
                    .read(ordersViewModelProvider.notifier)
                    .cancelOrder(orderId, reason: reasonController.text);
                if (context.mounted) {
                  if (err != null) {
                    AppSnackbar.error(context, err);
                  } else {
                    AppSnackbar.success(
                      context,
                      'Order cancelled successfully.',
                    );
                  }
                }
              },
              child: const Text(
                'CANCEL ORDER',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleReorder(BuildContext context, WidgetRef ref, OrderModel order) async {
    final allowed = await ensureCartRestaurant(
      context,
      ref,
      order.restaurantId,
    );
    if (!allowed || !context.mounted) return;

    Haptics.medium();
    final items = await resolveReorderItems(ref, order);
    if (!context.mounted) return;
    final cartNotifier = ref.read(cartViewModelProvider.notifier);
    for (final item in items) {
      cartNotifier.addItem(
        item.food,
        quantity: item.quantity,
        selectedVariant: item.selectedVariant,
        selectedVariantPrice: item.selectedVariantPrice,
        selectedAddons: item.selectedAddons,
        selectedAddonsPrice: item.selectedAddonsPrice,
      );
    }
    context.go(RouteNames.cart);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderAsync = ref.watch(orderDetailProvider(orderId));

    final scaffoldBg = isDark ? AppColors.backgroundDark : const Color(0xFFF4F5F7);

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: orderAsync.when(
        loading: () => Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.backgroundDark : AppColors.surfaceLight,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.textPrimaryLight),
              onPressed: () => context.backOr(),
            ),
          ),
          body: const SkeletonOrderTracking(),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: isDark ? AppColors.backgroundDark : AppColors.surfaceLight,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppColors.textPrimaryLight),
              onPressed: () => context.backOr(),
            ),
          ),
          body: Center(
            child: Text(
              'Could not load order details.',
              style: TextStyle(color: isDark ? Colors.white : AppColors.textPrimaryLight),
            ),
          ),
        ),
        data: (order) {
          return Scaffold(
            backgroundColor: scaffoldBg,
            appBar: OrderDetailsHeader(order: order),
            body: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Restaurant & Delivery Address Timeline Card
                  OrderTimelineCard(order: order),

                  const SizedBox(height: 16),

                  // Bill Details Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PriceDetailsCard(order: order),
                  ),

                  const SizedBox(height: 16),

                  // Previous Conversations Threads Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PreviousConversationsCard(orderId: order.id),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),

            // Bottom Action Bar
            bottomNavigationBar: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                child: order.isActive
                    ? Row(
                        children: [
                          if (order.canCancel)
                            Expanded(
                              flex: 1,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () => _showCancelDialog(context, ref),
                                child: const Text(
                                  'CANCEL',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          if (order.canCancel) const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                elevation: 0,
                              ),
                              onPressed: () {
                                Haptics.medium();
                                context.push('/orders/track/${order.id}');
                              },
                              child: const Text(
                                'TRACK LIVE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => _handleReorder(context, ref, order),
                          child: Text(
                            'REORDER',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}
