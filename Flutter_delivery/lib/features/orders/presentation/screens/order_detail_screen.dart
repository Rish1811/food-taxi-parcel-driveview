import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../application/orders_controller.dart';
import '../../application/orders_state.dart';
import '../../data/models/delivery_order.dart';

enum _StepState { done, current, pending }

class _TimelineStep {
  const _TimelineStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.state,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final _StepState state;
}

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key});

  List<_TimelineStep> _buildSteps(DeliveryOrder order) {
    const phases = [
      'en_route_to_pickup',
      'at_pickup',
      'en_route_to_delivery',
      'at_drop',
    ];
    final phaseIndex = phases.indexOf(order.currentPhase);

    final otpDone = !order.dropOtpRequired || order.dropOtpVerified;
    final paymentDone = order.isPaid;
    final atDrop = phaseIndex >= 3;

    final steps = <_TimelineStep>[
      _TimelineStep(
        title: 'Order Accepted',
        subtitle: 'You accepted this delivery',
        icon: Icons.check_circle_outline,
        state: _StepState.done,
      ),
      _TimelineStep(
        title: 'Reached Restaurant',
        subtitle: 'Arrived at pickup location',
        icon: Icons.storefront_outlined,
        state: phaseIndex >= 1 ? _StepState.done : _StepState.pending,
      ),
      _TimelineStep(
        title: 'Order Picked Up',
        subtitle: 'Collected order from restaurant',
        icon: Icons.shopping_bag_outlined,
        state: phaseIndex >= 2 ? _StepState.done : _StepState.pending,
      ),
      _TimelineStep(
        title: 'Reached Customer',
        subtitle: 'Arrived at delivery location',
        icon: Icons.location_on_outlined,
        state: atDrop ? _StepState.done : _StepState.pending,
      ),
      if (order.dropOtpRequired)
        _TimelineStep(
          title: 'OTP Verified',
          subtitle: otpDone
              ? 'Delivery OTP confirmed'
              : 'Ask customer for the OTP',
          icon: Icons.password_outlined,
          state: otpDone
              ? _StepState.done
              : (atDrop ? _StepState.current : _StepState.pending),
        ),
      _TimelineStep(
        title: 'Payment Collected',
        subtitle: paymentDone
            ? 'Payment received'
            : (order.isCashOnDelivery ? 'Collect cash from customer' : 'Awaiting payment'),
        icon: Icons.payments_outlined,
        state: paymentDone
            ? _StepState.done
            : (atDrop && otpDone ? _StepState.current : _StepState.pending),
      ),
      _TimelineStep(
        title: 'Delivery Completed',
        subtitle: 'Mark the order as delivered',
        icon: Icons.flag_outlined,
        state: atDrop && otpDone && paymentDone
            ? _StepState.current
            : _StepState.pending,
      ),
    ];

    return steps;
  }

  Future<void> _dial(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    final order = ref.watch(
      ordersControllerProvider.select(
        (s) => s is OrdersLoaded ? s.currentOrder : null,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          order != null ? 'Order #${order.orderCode}' : 'Order Details',
          style: TextStyle(color: textColor, fontWeight: FontWeight.w800, fontSize: 16.sp),
        ),
      ),
      body: order == null
          ? Center(
              child: Text(
                'No active order',
                style: TextStyle(color: subTextColor, fontSize: 14.sp),
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionCard(
                    theme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery Progress',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: textColor),
                        ),
                        SizedBox(height: 12.h),
                        ..._buildSteps(order).asMap().entries.map((entry) {
                          final steps = _buildSteps(order);
                          final isLast = entry.key == steps.length - 1;
                          return _TimelineTile(
                            step: entry.value,
                            isLast: isLast,
                            theme: theme,
                            textColor: textColor,
                            subTextColor: subTextColor,
                          );
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _sectionCard(
                    theme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Restaurant', textColor),
                        SizedBox(height: 8.h),
                        _infoRow(Icons.storefront_outlined, order.restaurant.name, textColor, bold: true),
                        if (order.restaurant.address.isNotEmpty)
                          _infoRow(Icons.place_outlined, order.restaurant.address, subTextColor),
                        if (order.restaurant.phone != null && order.restaurant.phone!.isNotEmpty)
                          _infoRow(
                            Icons.call_outlined,
                            order.restaurant.phone!,
                            subTextColor,
                            onTap: () => _dial(order.restaurant.phone!),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _sectionCard(
                    theme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Customer', textColor),
                        SizedBox(height: 8.h),
                        _infoRow(Icons.person_outline, order.customerName, textColor, bold: true),
                        if (order.deliveryAddress.fullAddress.isNotEmpty)
                          _infoRow(Icons.place_outlined, order.deliveryAddress.fullAddress, subTextColor),
                        if (order.customerPhone.isNotEmpty)
                          _infoRow(
                            Icons.call_outlined,
                            order.customerPhone,
                            subTextColor,
                            onTap: () => _dial(order.customerPhone),
                          ),
                        if (order.deliveryInstructions != null && order.deliveryInstructions!.isNotEmpty)
                          _infoRow(Icons.note_outlined, order.deliveryInstructions!, subTextColor),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _sectionCard(
                    theme,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Items', textColor),
                        SizedBox(height: 8.h),
                        ...order.items.map(
                          (item) => Padding(
                            padding: EdgeInsets.symmetric(vertical: 6.h),
                            child: Row(
                              children: [
                                Icon(
                                  item.isVeg ? Icons.circle_outlined : Icons.change_history_outlined,
                                  size: 14.sp,
                                  color: item.isVeg ? Colors.green : Colors.red,
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item.quantity} x ${item.name}',
                                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: textColor),
                                      ),
                                      if (item.variantName != null && item.variantName!.isNotEmpty)
                                        Text(
                                          item.variantName!,
                                          style: TextStyle(fontSize: 11.sp, color: subTextColor),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (order.cookingNote != null && order.cookingNote!.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          _infoRow(Icons.restaurant_menu_outlined, order.cookingNote!, subTextColor),
                        ],
                        Divider(height: 24.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: textColor)),
                            Text(
                              '₹${order.total.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: theme.primaryColor),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Payment', style: TextStyle(fontSize: 12.sp, color: subTextColor)),
                            Text(
                              order.isCashOnDelivery
                                  ? (order.isPaid ? 'Cash · Collected' : 'Cash on Delivery')
                                  : (order.isPaid ? 'Paid Online' : 'Payment Pending'),
                              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: subTextColor),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Your Earning', style: TextStyle(fontSize: 12.sp, color: subTextColor)),
                            Text(
                              '₹${order.riderEarning.toStringAsFixed(0)}',
                              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: subTextColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (order.pickupDistanceKm != null || order.tripDistanceKm != null) ...[
                    SizedBox(height: 16.h),
                    _sectionCard(
                      theme,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          if (order.pickupDistanceKm != null)
                            _statColumn(
                              'Pickup Distance',
                              '${order.pickupDistanceKm!.toStringAsFixed(1)} km',
                              textColor,
                              subTextColor,
                            ),
                          if (order.tripDistanceKm != null)
                            _statColumn(
                              'Trip Distance',
                              '${order.tripDistanceKm!.toStringAsFixed(1)} km',
                              textColor,
                              subTextColor,
                            ),
                          if (order.tripDurationMins != null)
                            _statColumn(
                              'Est. Duration',
                              '${order.tripDurationMins!.toStringAsFixed(0)} min',
                              textColor,
                              subTextColor,
                            ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(height: 24.h),
                ],
              ),
            ),
    );
  }

  Widget _sectionCard(ThemeData theme, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, Color textColor) {
    return Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: textColor));
  }

  Widget _infoRow(IconData icon, String text, Color? color, {bool bold = false, VoidCallback? onTap}) {
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15.sp, color: color),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.sp,
                color: color,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                decoration: onTap != null ? TextDecoration.underline : null,
              ),
            ),
          ),
        ],
      ),
    );
    return onTap != null ? GestureDetector(onTap: onTap, child: row) : row;
  }

  Widget _statColumn(String label, String value, Color textColor, Color? subTextColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: textColor)),
        SizedBox(height: 2.h),
        Text(label, style: TextStyle(fontSize: 11.sp, color: subTextColor)),
      ],
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.step,
    required this.isLast,
    required this.theme,
    required this.textColor,
    required this.subTextColor,
  });

  final _TimelineStep step;
  final bool isLast;
  final ThemeData theme;
  final Color textColor;
  final Color? subTextColor;

  @override
  Widget build(BuildContext context) {
    final Color circleColor;
    final Color iconColor;
    switch (step.state) {
      case _StepState.done:
        circleColor = Colors.green;
        iconColor = Colors.white;
        break;
      case _StepState.current:
        circleColor = theme.primaryColor;
        iconColor = Colors.white;
        break;
      case _StepState.pending:
        circleColor = Colors.grey[300]!;
        iconColor = Colors.grey[600]!;
        break;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28.w,
                height: 28.w,
                decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
                child: Icon(step.icon, size: 14.sp, color: iconColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: EdgeInsets.symmetric(vertical: 2.h),
                    color: step.state == _StepState.done ? Colors.green : Colors.grey[300],
                  ),
                ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: step.state == _StepState.pending ? FontWeight.w600 : FontWeight.w800,
                      color: step.state == _StepState.pending ? subTextColor : textColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(step.subtitle, style: TextStyle(fontSize: 11.sp, color: subTextColor)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
