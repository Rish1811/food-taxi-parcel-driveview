import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/modules/food/presentation/orders/utils/reorder.dart';
import 'package:superapp_user/modules/food/presentation/orders/widgets/gst_label.dart';
import 'package:superapp_user/modules/food/presentation/orders/viewmodels/active_order_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/orders/viewmodels/orders_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/orders/widgets/celebration_painter.dart';

class OrderSuccessScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderSuccessScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends ConsumerState<OrderSuccessScreen> with TickerProviderStateMixin {
  Timer? _pollTimer;
  Timer? _countdownTimer;
  bool _navigatedAway = false;
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Precise Haptics on Entry
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Haptics.medium();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) Haptics.success();
      });
      _staggerController.forward();
      ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder(isRefresh: true);
      ref.read(ordersViewModelProvider.notifier).refresh(isRefresh: true);
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      ref.invalidate(orderDetailProvider(widget.orderId));
      ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder(isRefresh: true);
      ref.read(ordersViewModelProvider.notifier).refresh(isRefresh: true);
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _staggerController.dispose();
    super.dispose();
  }

  void _continueShopping() {
    Haptics.light();
    context.go(RouteNames.home);
  }

  void _trackOrder() {
    Haptics.light();
    context.push('/orders/track/${widget.orderId}');
  }

  void _handleStatus(OrderModel order) {
    if (_navigatedAway || !mounted) return;

    if (order.isCancelled) {
      _navigatedAway = true;
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      Haptics.error();
      final reason = order.cancellationReason.isNotEmpty
          ? order.cancellationReason
          : 'The restaurant was unable to accept this order.';
      context.go(RouteNames.home);
      AppSnackbar.error(context, reason, duration: const Duration(seconds: 4));
      return;
    }

    if (!order.isAwaitingAcceptance) {
      _navigatedAway = true;
      _pollTimer?.cancel();
      _countdownTimer?.cancel();
      Haptics.success();
      context.go('/orders/track/${widget.orderId}');
    }
  }

  Animation<double> _getInterval(double start, double end) {
    return CurvedAnimation(
      parent: _staggerController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(orderDetailProvider(widget.orderId));

    async.whenData((order) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handleStatus(order));
    });

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _continueShopping();
      },
      child: Scaffold(
        body: async.when(
          loading: () => const _SuccessScaffold(
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _SuccessScaffold(
            child: _MinimalSuccess(
              orderId: widget.orderId,
              onContinue: _continueShopping,
              onTrack: _trackOrder,
            ),
          ),
          data: (order) => CelebrationEffect(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [AppColors.backgroundDark, AppColors.backgroundDark]
                      : [AppColors.primary.withValues(alpha: 0.08), const Color(0xFFF4F5F7)],
                  stops: const [0.0, 0.4],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 500),
                              transitionBuilder: (child, animation) => FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(scale: animation, child: child),
                              ),
                              child: order.isAwaitingAcceptance
                                  ? const _WaitingAnimation(key: ValueKey('waiting'))
                                  : const _SuccessBadge(key: ValueKey('success')),
                            ),
                            const SizedBox(height: 24),
                            _StaggeredWidget(
                              animation: _getInterval(0.1, 0.4),
                              child: Text(
                                order.isAwaitingAcceptance ? 'Order placed!' : 'Order confirmed!',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _StaggeredWidget(
                              animation: _getInterval(0.2, 0.5),
                              child: Text(
                                order.isAwaitingAcceptance
                                    ? 'Waiting for restaurant confirmation...'
                                    : (order.etaLabel ?? 'Your food is being prepared'),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            if (order.isAwaitingAcceptance && order.confirmationEtaLabel != null) ...[
                              const SizedBox(height: 6),
                              _StaggeredWidget(
                                animation: _getInterval(0.3, 0.6),
                                child: Text(
                                  order.confirmationEtaLabel!,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
                            _StaggeredWidget(
                              animation: _getInterval(0.4, 0.7),
                              child: _OrderInfoCard(order: order),
                            ),
                            const SizedBox(height: 16),
                            _StaggeredWidget(
                              animation: _getInterval(0.5, 0.8),
                              child: _ItemsCard(order: order),
                            ),
                            const SizedBox(height: 16),
                            _StaggeredWidget(
                              animation: _getInterval(0.6, 0.9),
                              child: _ReorderButton(order: order),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _StaggeredWidget(
                      animation: _getInterval(0.7, 1.0),
                      beginOffset: 0.5,
                      child: _BottomActions(
                        onContinue: _continueShopping,
                        onTrack: _trackOrder,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StaggeredWidget extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final double beginOffset;

  const _StaggeredWidget({
    required this.child,
    required this.animation,
    this.beginOffset = 30.0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, beginOffset * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _WaitingAnimation extends StatefulWidget {
  const _WaitingAnimation({super.key});

  @override
  State<_WaitingAnimation> createState() => _WaitingAnimationState();
}

class _WaitingAnimationState extends State<_WaitingAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                Builder(
                  builder: (context) {
                    final t = (_controller.value + i / 3) % 1.0;
                    final scale = 0.4 + t * 0.6;
                    final opacity = (1 - t).clamp(0.0, 1.0);
                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 34),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SuccessBadge extends StatelessWidget {
  const _SuccessBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.elasticOut,
      builder: (_, t, _) {
        return Transform.scale(
          scale: t,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12 * t.clamp(0.0, 1.0)),
              shape: BoxShape.circle,
              boxShadow: [
                if (t > 0.8)
                  BoxShadow(
                    color: AppColors.success.withValues(alpha: 0.3 * (t - 0.8).clamp(0.0, 1.0)),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
              ],
            ),
            child: Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OrderInfoCard extends StatelessWidget {
  final OrderModel order;
  const _OrderInfoCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (order.orderNumber.isNotEmpty)
        _row(context, Icons.receipt_long_outlined, 'Order ID', '#${order.orderNumber}'),
      if (order.restaurantName.isNotEmpty)
        _row(context, Icons.storefront_outlined, 'Restaurant', order.restaurantName),
      if (order.paymentMethod.isNotEmpty)
        _row(context, Icons.payments_outlined, 'Payment', _paymentLabel(order.paymentMethod)),
      if (order.deliveryAddress.isNotEmpty)
        _row(context, Icons.location_on_outlined, 'Delivering to', order.deliveryAddress),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return _card(context, Column(children: rows));
  }

  Widget _row(BuildContext context, IconData icon, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: secondary)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
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

class _ItemsCard extends StatelessWidget {
  final OrderModel order;
  const _ItemsCard({required this.order});

  String _fmt(double val) {
    if (val % 1 == 0) {
      return '₹${val.toInt()}';
    }
    return '₹${val.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    if (order.items.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final itemTotalVal = order.effectiveItemTotal;

    return _card(
      context,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR ORDER',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: secondary,
            ),
          ),
          const SizedBox(height: 16),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${item.quantity}×',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.variants.isEmpty
                              ? item.name
                              : '${item.name} (${item.variants.join(', ')})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        for (final addon in item.addons) ...[
                          const SizedBox(height: 2),
                          Text(
                            '+ $addon',
                            style: TextStyle(fontSize: 12, color: secondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    _fmt(item.lineTotal),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          Text(
            'Bill Details',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),
          _billRow('Item Total', _fmt(itemTotalVal), textColor, secondary),
          if (order.addonTotal > 0)
            _billRow('Add-ons', _fmt(order.addonTotal), textColor, secondary),
          if (order.packingCharge > 0)
            _billRow('Packing Charges', _fmt(order.packingCharge), textColor, secondary),
          if (order.deliveryCharge > 0)
            _billRow('Delivery Fee', _fmt(order.deliveryCharge), textColor, secondary),
          if (order.platformFee > 0)
            _billRow('Platform Fee', _fmt(order.platformFee), textColor, secondary),
          // Split when the order carries it. "Taxes (18%)" sitting under a
          // "GST (5%)" row read as being taxed twice — the 18% is GST on the
          // delivery fee, and the label has to say so.
          if (order.hasSplitGst) ...[
            if (order.itemGst > 0)
              _billRow(
                gstLabel('GST', order.itemGstRate),
                _fmt(order.itemGst),
                textColor,
                secondary,
              ),
            if (order.deliveryFeeGst > 0)
              _billRow(
                gstLabel('GST on Delivery Fee', order.deliveryFeeGstRate),
                _fmt(order.deliveryFeeGst),
                textColor,
                secondary,
              ),
          ] else if (order.taxes > 0)
            _billRow('GST / Taxes', _fmt(order.taxes), textColor, secondary),
          if (order.rewardDiscount > 0)
            _billRow('Discount', '-${_fmt(order.rewardDiscount)}', AppColors.success, secondary),
          if (order.couponDiscount > 0)
            _billRow('Coupon Discount', '-${_fmt(order.couponDiscount)}', AppColors.success, secondary),
          if (order.walletUsed > 0)
            _billRow('Wallet Discount', '-${_fmt(order.walletUsed)}', AppColors.success, secondary),
          if (order.driverTip > 0)
            _billRow('Tip', _fmt(order.driverTip), textColor, secondary),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Paid',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              Text(
                _fmt(order.total),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billRow(String label, String value, Color valueColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: labelColor,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReorderButton extends ConsumerStatefulWidget {
  final OrderModel order;
  const _ReorderButton({required this.order});

  @override
  ConsumerState<_ReorderButton> createState() => _ReorderButtonState();
}

class _ReorderButtonState extends ConsumerState<_ReorderButton> {
  bool _isPressed = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    if (widget.order.items.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: _isLoading
          ? null
          : () async {
              Haptics.medium();
              setState(() => _isLoading = true);
              final buyAgainItems = await resolveReorderItems(
                ref,
                widget.order,
              );
              if (!mounted || !context.mounted) return;
              setState(() => _isLoading = false);
              context.push(RouteNames.buyAgain, extra: buyAgainItems);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _isPressed ? AppColors.primary.withValues(alpha: 0.05) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
        ),
        child: _isLoading
            ? Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.replay_rounded, color: AppColors.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Reorder these items',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PulseButton extends StatefulWidget {
  final Widget child;
  const _PulseButton({required this.child});

  @override
  State<_PulseButton> createState() => _PulseButtonState();
}

class _PulseButtonState extends State<_PulseButton> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + (_ctrl.value * 0.03),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _BottomActions extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onTrack;
  const _BottomActions({required this.onContinue, required this.onTrack});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : AppColors.shadow1,
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.borderLight, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: onContinue,
              child: Text(
                'Continue Shopping',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PulseButton(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: onTrack,
                child: const Text(
                  'Track Order',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalSuccess extends StatelessWidget {
  final String orderId;
  final VoidCallback onContinue;
  final VoidCallback onTrack;

  const _MinimalSuccess({
    required this.orderId,
    required this.onContinue,
    required this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(),
          const _SuccessBadge(),
          const SizedBox(height: 24),
          const Text(
            'Order placed!',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your order was placed successfully.',
            style: TextStyle(fontSize: 15, color: AppColors.textSecondaryLight),
          ),
          const Spacer(),
          _BottomActions(onContinue: onContinue, onTrack: onTrack),
        ],
      ),
    );
  }
}

class _SuccessScaffold extends StatelessWidget {
  final Widget child;
  const _SuccessScaffold({required this.child});

  @override
  Widget build(BuildContext context) => SafeArea(child: child);
}

Widget _card(BuildContext context, Widget child) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: isDark ? AppColors.cardDark : Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: AppColors.shadow1,
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
    ),
    child: child,
  );
}

String _paymentLabel(String method) {
  switch (method) {
    case 'cash':
      return 'Cash on Delivery';
    case 'razorpay':
      return 'UPI / Card';
    case 'razorpay_qr':
      return 'Pay on delivery (QR)';
    case 'wallet':
      return 'K9 Wallet';
    default:
      return method;
  }
}
