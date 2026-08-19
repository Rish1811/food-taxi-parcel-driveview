import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';

class PaymentDetailsCard extends StatelessWidget {
  final OrderModel order;

  const PaymentDetailsCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final isRefunded = order.refundStatus == 'refunded' || order.refundAmount > 0;

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
              Icon(Icons.payment_rounded, color: textColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Payment Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (order.paymentMethod.isNotEmpty)
            _buildRow('Method', order.paymentMethod.toUpperCase(), textColor, secondaryColor),
            
          if (order.paymentStatus.isNotEmpty)
            _buildRow(
              'Status',
              order.paymentStatus.toUpperCase(),
              order.paymentStatus.toLowerCase() == 'paid' || order.paymentStatus.toLowerCase() == 'success'
                  ? Colors.green
                  : Colors.orange,
              secondaryColor,
              isBold: true,
            ),
            
          if (order.transactionId.isNotEmpty)
            _buildRow('Transaction ID', order.transactionId, textColor, secondaryColor),
            
          if (order.paymentTime != null)
            _buildRow(
              'Time',
              DateFormat('dd MMM yyyy, hh:mm a').format(order.paymentTime!.toLocal()),
              textColor,
              secondaryColor,
            ),

          if (isRefunded) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, thickness: 1),
            ),
            if (order.refundAmount > 0)
              _buildRow('Refund Amount', '${order.currency} ${order.refundAmount.toStringAsFixed(2)}', Colors.green, secondaryColor, isBold: true),
            _buildRow('Refund Status', order.refundStatus.toUpperCase(), Colors.green, secondaryColor),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value, Color valColor, Color labelColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: labelColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.w500,
                color: valColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
