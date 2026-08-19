import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/app/routing/back_navigation.dart';

import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';

class OrderDetailsHeader extends StatelessWidget implements PreferredSizeWidget {
  final OrderModel order;
  final VoidCallback? onHelpPressed;

  const OrderDetailsHeader({
    super.key,
    required this.order,
    this.onHelpPressed,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    // Capitalize status name e.g., 'Delivered'
    final rawStatus = order.orderStatus.isNotEmpty ? order.orderStatus : 'Completed';
    final statusText = rawStatus[0].toUpperCase() + rawStatus.substring(1).toLowerCase();

    // Item count string (e.g. "1 Item" or "2 Items")
    final totalItems = order.items.fold<int>(0, (sum, i) => sum + i.quantity);
    final itemsCountText = totalItems == 1 ? '1 Item' : '$totalItems Items';

    // Amount text e.g. "₹103"
    final amountText = '₹${order.total.toStringAsFixed(0)}';

    final subtitleText = '$statusText , $itemsCountText , $amountText';

    return AppBar(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.surfaceLight,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_rounded,
          color: primaryTextColor,
          size: 24,
        ),
        onPressed: () => context.backOr(),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'ORDER #${order.orderNumber.isNotEmpty ? order.orderNumber : order.id}',
            style: TextStyle(
              color: primaryTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitleText,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        TextButton(
          onPressed: onHelpPressed ??
              () {
                context.push('/chat');
              },
          child: Text(
            'HELP',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
}
