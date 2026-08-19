import 'package:flutter/material.dart';
import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/modules/food/presentation/orders/widgets/gst_label.dart';

class PriceDetailsCard extends StatelessWidget {
  final OrderModel order;

  const PriceDetailsCard({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final primaryTextColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final dividerColor = isDark ? AppColors.borderDark : AppColors.dividerLight;
    const greenColor = Color(0xFF39C96B);

    final computedItemTotal = order.effectiveItemTotal;

    // walletUsed is deliberately excluded: paying from the wallet is a payment
    // METHOD, not a reduction in what the order cost. Counting it here showed it as
    // "Discount Applied" and meant the itemised rows no longer summed to the total.
    final totalDiscounts = order.couponDiscount + order.rewardDiscount;

    final paymentMethodText = order.paymentMethod.isNotEmpty
        ? 'Paid Via ${order.paymentMethod.toUpperCase()}'
        : 'Paid Via Online';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header Title
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            'BILL DETAILS',
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ),

        // Bill Details Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(0),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Food Items List Section
              ...order.items.map((item) {
                final itemName = item.variants.isEmpty
                    ? item.name
                    : '${item.name} (${item.variants.join(', ')})';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Veg/Non-Veg Badge
                      _VegNonVegBadge(isVeg: item.isVeg),
                      const SizedBox(width: 10),
                      // Item Name, Variant, Add-ons & Quantity
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$itemName x ${item.quantity}',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            for (final addon in item.addons)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '+ $addon',
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Item Price
                      Text(
                        '₹${item.lineTotal.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              if (order.items.isNotEmpty) ...[
                const SizedBox(height: 4),
                Divider(color: dividerColor, height: 1, thickness: 1),
                const SizedBox(height: 14),
              ],

              // 2. Financial Itemized Breakdown
              // Item Total
              _buildBillRow('Item Total', '₹${computedItemTotal.toStringAsFixed(0)}', primaryTextColor, secondaryTextColor),

              // Restaurant Packaging
              if (order.packingCharge > 0)
                _buildBillRow('Restaurant Packaging', '₹${order.packingCharge.toStringAsFixed(0)}', primaryTextColor, secondaryTextColor)
              else
                // No fabricated strike-through. The order records what WAS charged,
                // never what it would otherwise have been, so a struck-out "10"
                // claimed a saving of a number that exists nowhere in the order.
                _buildBillRowWithBadge('Restaurant Packaging', '', 'FREE', secondaryTextColor, greenColor),

              // Platform fee
              if (order.platformFee > 0)
                _buildBillRow('Platform fee with GST', '₹${order.platformFee.toStringAsFixed(2)}', primaryTextColor, secondaryTextColor),

              // Discount Applied
              if (totalDiscounts > 0)
                _buildBillRow('Discount Applied', '-₹${totalDiscounts.toStringAsFixed(0)}', greenColor, greenColor),

              // Delivery Fee
              if (order.deliveryCharge > 0)
                _buildBillRow('Delivery Fee', '₹${order.deliveryCharge.toStringAsFixed(0)}', primaryTextColor, secondaryTextColor)
              else
                _buildBillRowWithBadge('Delivery Fee', '', 'FREE', secondaryTextColor, greenColor),

              // Two GST rows, not one merged "Taxes": the food and the delivery
              // fee are charged at different rates, so a single figure cannot be
              // labelled with the rate behind it.
              if (order.hasSplitGst) ...[
                if (order.itemGst > 0)
                  _buildBillRow(gstLabel('GST', order.itemGstRate),
                      '₹${order.itemGst.toStringAsFixed(2)}', primaryTextColor, secondaryTextColor),
                if (order.deliveryFeeGst > 0)
                  _buildBillRow(gstLabel('GST on Delivery Fee', order.deliveryFeeGstRate),
                      '₹${order.deliveryFeeGst.toStringAsFixed(2)}', primaryTextColor, secondaryTextColor),
              ] else if (order.taxes > 0)
                _buildBillRow('Taxes', '₹${order.taxes.toStringAsFixed(2)}', primaryTextColor, secondaryTextColor),

              const SizedBox(height: 12),
              Divider(color: dividerColor, height: 1, thickness: 1),
              const SizedBox(height: 14),

              // 3. Paid Via & Bill Total Footer Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    paymentMethodText,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Bill Total',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '₹${order.total.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBillRow(String label, String value, Color valColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: valColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBillRowWithBadge(String label, String strikePrice, String badgeText, Color labelColor, Color badgeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          Row(
            children: [
              // Skipped when empty: callers pass '' when the order does not record
              // an original price, and an empty Text plus its gap left a visible
              // notch beside the badge.
              if (strikePrice.isNotEmpty) ...[
                Text(
                  strikePrice,
                  style: TextStyle(
                    color: labelColor.withValues(alpha: 0.6),
                    fontSize: 12,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VegNonVegBadge extends StatelessWidget {
  final bool isVeg;
  const _VegNonVegBadge({required this.isVeg});

  @override
  Widget build(BuildContext context) {
    final borderColor = isVeg ? const Color(0xFF0F8A4B) : const Color(0xFFE53935);
    final dotColor = isVeg ? const Color(0xFF0F8A4B) : const Color(0xFFE53935);

    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      padding: const EdgeInsets.all(2.5),
      child: Container(
        decoration: BoxDecoration(
          color: dotColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
