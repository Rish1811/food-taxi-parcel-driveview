import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/order_model.dart';

class FloatingActiveOrderCard extends StatefulWidget {
  final OrderModel order;
  final bool isCompact;

  const FloatingActiveOrderCard({
    super.key,
    required this.order,
    this.isCompact = false,
  });

  @override
  State<FloatingActiveOrderCard> createState() => _FloatingActiveOrderCardState();
}

class _FloatingActiveOrderCardState extends State<FloatingActiveOrderCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint('[HOME] Widget inserted into UI');
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    ));
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    );

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final etaText = order.etaLabel;

    // Responsive design dimensions
    final double cardWidth = widget.isCompact ? 280.0 : MediaQuery.of(context).size.width - 32;
    final double iconContainerSize = widget.isCompact ? 32.0 : 42.0;
    final double iconSize = widget.isCompact ? 16.0 : 22.0;
    final double titleFontSize = widget.isCompact ? 13.0 : 15.0;
    final double statusFontSize = widget.isCompact ? 11.5 : 13.0;
    final double chipPaddingHorizontal = widget.isCompact ? 10.0 : 14.0;
    final double chipPaddingVertical = widget.isCompact ? 6.0 : 8.0;
    final double chipFontSize = widget.isCompact ? 11.0 : 12.0;
    final double spacingWidth = widget.isCompact ? 10.0 : 12.0;
    final double itemSpacingHeight = widget.isCompact ? 2.0 : 4.0;
    final double innerPaddingHorizontal = widget.isCompact ? 12.0 : 16.0;
    final double innerPaddingVertical = widget.isCompact ? 10.0 : 12.0;

    return SlideTransition(
      position: _slideAnim,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 12.0), // Extra padding from bottom nav
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Haptics.medium();
                  if (kDebugMode) {
                    debugPrint('[HOME] Widget clicked');
                    debugPrint('[TRACKING] Tracking page opened');
                  }
                  context.push('/food/orders/${order.id}/track');
                },
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: cardWidth,
                  padding: EdgeInsets.symmetric(
                    horizontal: innerPaddingHorizontal,
                    vertical: innerPaddingVertical,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF013621), Color(0xFF0C2B1C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF38B255).withValues(alpha: 0.3),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF013621).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Premium Icon
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: iconContainerSize,
                        height: iconContainerSize,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.2),
                              Colors.white.withValues(alpha: 0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          order.isOutForDelivery
                              ? Icons.two_wheeler_rounded
                              : Icons.soup_kitchen_rounded,
                          color: const Color(0xFF38B255),
                          size: iconSize,
                        ),
                      ),
                      SizedBox(width: spacingWidth),

                      // Restaurant & Status Column
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: Text(
                                order.restaurantName.isNotEmpty
                                    ? order.restaurantName
                                    : 'Food Order',
                              ),
                            ),
                            SizedBox(height: itemSpacingHeight),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                    style: TextStyle(
                                      fontSize: statusFontSize,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    child: Text(order.statusLabel),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 10,
                                  color: Color(0xFF38B255),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Vibrant ETA Pill
                      if (etaText != null && etaText.isNotEmpty)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 120),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              padding: EdgeInsets.symmetric(
                                horizontal: chipPaddingHorizontal,
                                vertical: chipPaddingVertical,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (order.compactEtaLabel == null)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: SizedBox(
                                        width: 10,
                                        height: 10,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(const Color(0xFF013621)),
                                        ),
                                      ),
                                    ),
                                  Flexible(
                                    child: Text(
                                      order.compactEtaLabel ?? 'Calculating...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: const Color(0xFF013621),
                                        fontSize: chipFontSize,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
