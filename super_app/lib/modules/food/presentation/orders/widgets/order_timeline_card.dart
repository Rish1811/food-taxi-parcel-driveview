import 'package:flutter/material.dart';

import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';

class OrderTimelineCard extends StatelessWidget {
  final OrderModel order;

  const OrderTimelineCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final dividerColor = isDark ? AppColors.borderDark : AppColors.dividerLight;

    // Partner name
    final partnerName = order.deliveryPartner?.name.isNotEmpty == true
        ? order.deliveryPartner!.name
        : (order.dispatchStatus.isNotEmpty ? order.dispatchStatus : 'Delivery Partner');

    final statusLower = order.orderStatus.toLowerCase();
    final isDelivered = statusLower == 'delivered' || statusLower == 'completed';

    return Container(
      width: double.infinity,
      color: cardBg,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Restaurant & Drop Address Timeline Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vertical timeline icons + line column
              Column(
                children: [
                  const SizedBox(height: 2),
                  // Pickup Location Pin Icon
                  Icon(
                    Icons.location_on_outlined,
                    size: 22,
                    color: secondaryTextColor,
                  ),
                  // Dotted connecting vertical line
                  const CustomDottedLine(height: 38),
                  // Delivery Home Icon
                  Icon(
                    Icons.home_outlined,
                    size: 22,
                    color: primaryTextColor,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Addresses Text Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Restaurant Name (Orange)
                    Text(
                      order.restaurantName.isNotEmpty
                          ? order.restaurantName
                          : 'Restaurant Name',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Restaurant Address
                    Text(
                      order.restaurantAddress.isNotEmpty
                          ? order.restaurantAddress
                          : 'Restaurant address details',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 13,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 20),
                    // Drop Location Title (Customer Name / Address Tag)
                    Text(
                      order.customerName.isNotEmpty
                          ? order.customerName
                          : 'Delivery Address',
                      style: TextStyle(
                        color: primaryTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Drop Address Details
                    Text(
                      order.deliveryAddress.isNotEmpty
                          ? order.deliveryAddress
                          : 'Delivery address details',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 13,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          Divider(color: dividerColor, height: 1, thickness: 1),
          const SizedBox(height: 16),

          // Status & Delivery Partner Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  isDelivered ? Icons.check_rounded : Icons.access_time_rounded,
                  color: isDelivered ? AppColors.success : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDelivered
                          ? 'Order delivered'
                          : 'Order status: ${order.orderStatus.toUpperCase()}',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (partnerName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'by ${partnerName.toUpperCase()}',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Custom dotted line widget connecting pickup to delivery location
class CustomDottedLine extends StatelessWidget {
  final double height;

  const CustomDottedLine({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dotColor = isDark ? AppColors.textSecondaryDark.withValues(alpha: 0.5) : const Color(0xFFB0B0B0);

    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (_) {
          return Container(
            width: 1.5,
            height: 3,
            decoration: BoxDecoration(
              color: dotColor,
              borderRadius: BorderRadius.circular(1),
            ),
          );
        }),
      ),
    );
  }
}
