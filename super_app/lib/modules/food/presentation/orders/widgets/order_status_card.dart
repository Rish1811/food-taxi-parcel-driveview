import 'package:flutter/material.dart';
import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';

class OrderStatusCard extends StatelessWidget {
  final OrderModel order;

  const OrderStatusCard({super.key, required this.order});

  (Color, IconData, String, Color) _getStatusTheme(String status) {
    switch (status) {
      case 'created':
      case 'pending':
        return (Colors.orange, Icons.access_time_filled_rounded, 'Order Placed', Colors.orange.withValues(alpha: 0.1));
      case 'confirmed':
      case 'accepted':
        return (Colors.blue, Icons.thumb_up_rounded, 'Order Accepted', Colors.blue.withValues(alpha: 0.1));
      case 'preparing':
        return (Colors.deepOrange, Icons.restaurant_menu_rounded, 'Preparing', Colors.deepOrange.withValues(alpha: 0.1));
      case 'ready_for_pickup':
      case 'ready':
        return (Colors.amber, Icons.room_service_rounded, 'Ready for Pickup', Colors.amber.withValues(alpha: 0.1));
      case 'reached_pickup':
        return (Colors.indigo, Icons.storefront_rounded, 'Rider at Restaurant', Colors.indigo.withValues(alpha: 0.1));
      case 'picked_up':
      case 'out_for_delivery':
      case 'en_route_to_delivery':
      case 'reached_drop':
      case 'at_drop':
      case 'arriving_soon':
        return (const Color(0xFFFF7A00), Icons.delivery_dining_rounded, 'On The Way', const Color(0xFFFF7A00).withValues(alpha: 0.1));
      case 'delivered':
      case 'completed':
        return (Colors.green, Icons.check_circle_rounded, 'Delivered', Colors.green.withValues(alpha: 0.1));
      case 'cancelled':
      case 'cancelled_by_user':
      case 'cancelled_by_restaurant':
      case 'cancelled_by_admin':
      case 'rejected':
      case 'failed':
      case 'expired':
        return (Colors.red, Icons.cancel_rounded, 'Cancelled', Colors.red.withValues(alpha: 0.1));
      default:
        return (Colors.grey, Icons.info_rounded, order.statusLabel, Colors.grey.withValues(alpha: 0.1));
    }
  }

  String _getSubTitle(String status) {
    if (order.isDelivered) return 'Your order was delivered successfully.';
    if (order.isCancelled) return 'Your order has been cancelled.';
    if (order.refundStatus == 'refunded') return 'Refund has been processed.';
    if (order.refundStatus == 'initiated') return 'Refund has been initiated.';
    
    if (order.isAwaitingAcceptance) return 'Waiting for restaurant to confirm.';
    if (status == 'preparing') return 'The restaurant is preparing your food.';
    if (order.isOutForDelivery) return 'Rider is on the way to your location.';
    
    return 'We are processing your order.';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (iconColor, icon, title, bgColor) = _getStatusTheme(order.orderStatus);
    final subtitle = _getSubTitle(order.orderStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              shape: BoxShape.circle,
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : AppColors.textPrimaryLight.withValues(alpha: 0.8),
                    height: 1.3,
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
