import 'package:flutter/material.dart';
import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';

class DeliveryDetailsCard extends StatelessWidget {
  final OrderModel order;

  const DeliveryDetailsCard({super.key, required this.order});

  String _maskPhone(String phone) {
    if (phone.length < 4) return phone;
    return '******${phone.substring(phone.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    if (order.deliveryAddress.isEmpty && order.customerName.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: AppColors.shadow1,
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on_rounded, color: textColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Delivery Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (order.customerName.isNotEmpty) ...[
            Text(
              order.customerName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (order.customerPhone.isNotEmpty) ...[
            Text(
              _maskPhone(order.customerPhone),
              style: TextStyle(
                fontSize: 13,
                color: secondaryColor,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            order.deliveryAddress,
            style: TextStyle(
              fontSize: 13,
              color: secondaryColor,
              height: 1.4,
            ),
          ),
          if (order.landmark.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.flag_rounded, color: secondaryColor, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Landmark: ${order.landmark}',
                    style: TextStyle(
                      fontSize: 13,
                      color: secondaryColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
