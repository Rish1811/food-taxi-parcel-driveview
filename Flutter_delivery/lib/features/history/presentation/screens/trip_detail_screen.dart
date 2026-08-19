import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/error/result.dart';
import '../../../orders/data/models/delivery_order.dart';
import '../../../orders/data/orders_repository.dart';

/// A dedicated, receipt-styled detail view for a single Trip History entry
/// (Completed / Pending / Cancelled). Deliberately distinct from
/// [OrderDetailScreen], which models the *live* delivery progress of the
/// one active order — this screen has no timeline, since a historical trip
/// has nothing left to progress through.
class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.trip});

  /// The raw trip-summary map handed over from the Trip History list, used
  /// for an instant paint while the full order is fetched in the background.
  final Map<String, dynamic> trip;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  DeliveryOrder? _order;
  bool _loading = true;

  num _f(String key1, [String? key2, String? key3]) {
    final t = widget.trip;
    final v = t[key1] ?? (key2 != null ? t[key2] : null) ?? (key3 != null ? t[key3] : null);
    return (v is num) ? v : 0;
  }

  String _s(String key1, [String? key2, String? key3]) {
    final t = widget.trip;
    final v = t[key1] ?? (key2 != null ? t[key2] : null) ?? (key3 != null ? t[key3] : null);
    return v?.toString() ?? '';
  }

  String get _status => _s('status');
  String get _restaurantName => _s('restaurantName', 'restaurant').isEmpty
      ? 'Restaurant'
      : _s('restaurantName', 'restaurant');
  num get _earning => _f('deliveryEarning', 'earningAmount', 'amount');
  num get _total => _f('totalAmount', 'orderTotal');
  String get _displayOrderId => _s('orderId', 'id', '_id');
  String get _time => _s('time');
  String get _date => _s('date');

  /// The Mongo `_id` (not the human-readable order code) is what
  /// `GET /orders/:id` expects — prefer it over `orderId` for the fetch.
  String get _fetchId => _s('_id', 'id', 'orderId');

  @override
  void initState() {
    super.initState();
    _loadFullOrder();
  }

  Future<void> _loadFullOrder() async {
    if (_fetchId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    final result = await ref.read(ordersRepositoryProvider).getOrderDetails(_fetchId);
    if (!mounted) return;
    result.when(
      success: (order) => setState(() {
        _order = order;
        _loading = false;
      }),
      // Historical trip couldn't be re-fetched (e.g. endpoint scoped to
      // active orders only) — fall back to whatever the summary map has.
      failure: (_) => setState(() => _loading = false),
    );
  }

  Future<void> _dial(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  _StatusTheme get _statusTheme => switch (_status.toLowerCase()) {
    'completed' => const _StatusTheme(
        color: Color(0xFF1EBE5D),
        darkColor: Color(0xFF0E8A40),
        icon: Icons.check_circle_rounded,
        label: 'Delivered',
      ),
    'cancelled' => const _StatusTheme(
        color: Color(0xFFE5484D),
        darkColor: Color(0xFFAD1F24),
        icon: Icons.cancel_rounded,
        label: 'Cancelled',
      ),
    _ => const _StatusTheme(
        color: Color(0xFFFF9F43),
        darkColor: Color(0xFFC96F0F),
        icon: Icons.schedule_rounded,
        label: 'Pending',
      ),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final subTextColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;
    final scaffoldColor = theme.scaffoldBackgroundColor;
    final st = _statusTheme;
    final order = _order;

    return Scaffold(
      backgroundColor: scaffoldColor,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8.h, bottom: 44.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [st.color, st.darkColor],
                ),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                        Text(
                          'TRIP RECEIPT',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontWeight: FontWeight.w800,
                            fontSize: 13.sp,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    width: 68.w,
                    height: 68.w,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(st.icon, color: st.color, size: 38.sp),
                  ),
                  SizedBox(height: 14.h),
                  Text(
                    st.label,
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20.sp),
                  ),
                  SizedBox(height: 4.h),
                  if (_time.isNotEmpty || _date.isNotEmpty)
                    Text(
                      [_date, _time].where((e) => e.isNotEmpty).join(' · '),
                      style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.sp),
                    ),
                  SizedBox(height: 10.h),
                  if (_displayOrderId.isNotEmpty)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        '#$_displayOrderId',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.sp),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: Offset(0, -28.h),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  children: [
                    _ReceiptTicket(
                      scaffoldColor: scaffoldColor,
                      surfaceColor: theme.colorScheme.surface,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      accentColor: st.color,
                      restaurantName: order?.restaurant.name.isNotEmpty == true
                          ? order!.restaurant.name
                          : _restaurantName,
                      restaurantAddress: order?.restaurant.address ?? '',
                      restaurantPhone: order?.restaurant.phone,
                      onCallRestaurant: order?.restaurant.phone != null && order!.restaurant.phone!.isNotEmpty
                          ? () => _dial(order.restaurant.phone!)
                          : null,
                      items: order?.items ?? const [],
                      total: order?.total ?? _total.toDouble(),
                      earning: order?.riderEarning ?? _earning.toDouble(),
                      paymentLabel: order != null
                          ? (order.isCashOnDelivery
                              ? (order.isPaid ? 'Cash · Collected' : 'Cash on Delivery')
                              : (order.isPaid ? 'Paid Online' : 'Payment Pending'))
                          : null,
                    ),
                    if (_loading) ...[
                      SizedBox(height: 16.h),
                      _LoadingMoreCard(theme: theme, subTextColor: subTextColor),
                    ],
                    if (order != null && (order.customerName.isNotEmpty || order.deliveryAddress.fullAddress.isNotEmpty)) ...[
                      SizedBox(height: 16.h),
                      _InfoCard(
                        theme: theme,
                        title: 'Customer',
                        icon: Icons.person_rounded,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        children: [
                          if (order.customerName.isNotEmpty)
                            _iconLine(Icons.person_outline, order.customerName, textColor, subTextColor, bold: true),
                          if (order.deliveryAddress.fullAddress.isNotEmpty)
                            _iconLine(Icons.place_outlined, order.deliveryAddress.fullAddress, textColor, subTextColor),
                          if (order.customerPhone.isNotEmpty)
                            _iconLine(
                              Icons.call_outlined,
                              order.customerPhone,
                              theme.primaryColor,
                              subTextColor,
                              onTap: () => _dial(order.customerPhone),
                            ),
                          if (order.deliveryInstructions != null && order.deliveryInstructions!.isNotEmpty)
                            _iconLine(Icons.note_outlined, order.deliveryInstructions!, textColor, subTextColor),
                        ],
                      ),
                    ],
                    if (order != null && (order.tripDistanceKm != null || order.tripDurationMins != null || order.pickupDistanceKm != null)) ...[
                      SizedBox(height: 16.h),
                      _InfoCard(
                        theme: theme,
                        title: 'Trip Stats',
                        icon: Icons.route_rounded,
                        textColor: textColor,
                        subTextColor: subTextColor,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              if (order.pickupDistanceKm != null && order.pickupDistanceKm! > 0)
                                _statColumn('Pickup', '${order.pickupDistanceKm!.toStringAsFixed(1)} km', textColor, subTextColor),
                              if (order.tripDistanceKm != null && order.tripDistanceKm! > 0)
                                _statColumn('Trip Distance', '${order.tripDistanceKm!.toStringAsFixed(1)} km', textColor, subTextColor),
                              if (order.tripDurationMins != null && order.tripDurationMins! > 0)
                                _statColumn('Duration', '${order.tripDurationMins!.toStringAsFixed(0)} min', textColor, subTextColor),
                            ],
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconLine(IconData icon, String text, Color color, Color subTextColor, {bool bold = false, VoidCallback? onTap}) {
    final row = Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15.sp, color: bold ? color : subTextColor),
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

  Widget _statColumn(String label, String value, Color textColor, Color subTextColor) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800, color: textColor)),
        SizedBox(height: 2.h),
        Text(label, style: TextStyle(fontSize: 11.sp, color: subTextColor)),
      ],
    );
  }
}

class _StatusTheme {
  const _StatusTheme({required this.color, required this.darkColor, required this.icon, required this.label});
  final Color color;
  final Color darkColor;
  final IconData icon;
  final String label;
}

/// The receipt-look card: a rounded ticket with punch-hole notches cut into
/// its sides at the divider between the item list and the price summary,
/// like a real till receipt torn off a roll.
class _ReceiptTicket extends StatelessWidget {
  const _ReceiptTicket({
    required this.scaffoldColor,
    required this.surfaceColor,
    required this.textColor,
    required this.subTextColor,
    required this.accentColor,
    required this.restaurantName,
    required this.restaurantAddress,
    required this.restaurantPhone,
    required this.onCallRestaurant,
    required this.items,
    required this.total,
    required this.earning,
    required this.paymentLabel,
  });

  final Color scaffoldColor;
  final Color surfaceColor;
  final Color textColor;
  final Color subTextColor;
  final Color accentColor;
  final String restaurantName;
  final String restaurantAddress;
  final String? restaurantPhone;
  final VoidCallback? onCallRestaurant;
  final List<OrderItem> items;
  final double total;
  final double earning;
  final String? paymentLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      padding: EdgeInsets.all(20.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.storefront_rounded, color: accentColor, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      restaurantName,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15.sp, color: textColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (restaurantAddress.isNotEmpty)
                      Text(
                        restaurantAddress,
                        style: TextStyle(fontSize: 11.sp, color: subTextColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (onCallRestaurant != null)
                IconButton(
                  onPressed: onCallRestaurant,
                  icon: Icon(Icons.call_rounded, color: accentColor, size: 20.sp),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          _Notched(scaffoldColor: scaffoldColor),
          SizedBox(height: 16.h),
          if (items.isNotEmpty)
            ...items.map(
              (item) => Padding(
                padding: EdgeInsets.symmetric(vertical: 5.h),
                child: Row(
                  children: [
                    Icon(
                      item.isVeg ? Icons.circle_outlined : Icons.change_history_outlined,
                      size: 12.sp,
                      color: item.isVeg ? Colors.green : Colors.red,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        '${item.quantity} x ${item.name}',
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '₹${(item.price * item.quantity).toStringAsFixed(0)}',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: textColor),
                    ),
                  ],
                ),
              ),
            )
          else
            Text(
              'Itemized bill unavailable for this trip',
              style: TextStyle(fontSize: 12.sp, color: subTextColor, fontStyle: FontStyle.italic),
            ),
          SizedBox(height: 12.h),
          _DashedLine(color: subTextColor.withOpacity(0.4)),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order Total', style: TextStyle(fontSize: 13.sp, color: subTextColor, fontWeight: FontWeight.w600)),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900, color: textColor),
              ),
            ],
          ),
          if (paymentLabel != null) ...[
            SizedBox(height: 6.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Payment', style: TextStyle(fontSize: 12.sp, color: subTextColor)),
                Text(paymentLabel!, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: subTextColor)),
              ],
            ),
          ],
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              children: [
                Text(
                  'YOUR EARNING',
                  style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold, color: accentColor, letterSpacing: 1.2),
                ),
                SizedBox(height: 4.h),
                Text(
                  '+₹${earning.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w900, color: accentColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two half-circle "punch holes" on the ticket's left/right edges, painted
/// in the scaffold color so they read as cutouts, plus the dashed tear-line
/// between them.
class _Notched extends StatelessWidget {
  const _Notched({required this.scaffoldColor});
  final Color scaffoldColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14.h,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: _DashedLine(color: Colors.grey.withOpacity(0.4)),
          ),
          Positioned(
            left: -20.r,
            child: _Circle(size: 20.r, color: scaffoldColor),
          ),
          Positioned(
            right: -20.r,
            child: _Circle(size: 20.r, color: scaffoldColor),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _DashedLine extends StatelessWidget {
  const _DashedLine({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const dashWidth = 6.0;
        const dashGap = 4.0;
        final count = (constraints.maxWidth / (dashWidth + dashGap)).floor();
        return Row(
          children: List.generate(
            count,
            (_) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: dashGap / 2),
              child: Container(width: dashWidth, height: 1.5, color: color),
            ),
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.theme,
    required this.title,
    required this.icon,
    required this.textColor,
    required this.subTextColor,
    required this.children,
  });

  final ThemeData theme;
  final String title;
  final IconData icon;
  final Color textColor;
  final Color subTextColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.r),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16.sp, color: theme.primaryColor),
              SizedBox(width: 8.w),
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.sp, color: textColor)),
            ],
          ),
          SizedBox(height: 10.h),
          ...children,
        ],
      ),
    );
  }
}

class _LoadingMoreCard extends StatelessWidget {
  const _LoadingMoreCard({required this.theme, required this.subTextColor});
  final ThemeData theme;
  final Color subTextColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16.w,
            height: 16.w,
            child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
          ),
          SizedBox(width: 10.w),
          Text('Loading full trip details…', style: TextStyle(fontSize: 12.sp, color: subTextColor)),
        ],
      ),
    );
  }
}
