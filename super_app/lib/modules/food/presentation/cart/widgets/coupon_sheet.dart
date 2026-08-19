import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/modules/food/presentation/checkout/viewmodels/checkout_viewmodel.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';
import 'package:superapp_user/modules/food/presentation/coupons/viewmodels/coupons_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';

/// Apply/remove a coupon against the server bill.
///
/// Every accept/reject decision comes from `CheckoutViewModel.applyCoupon` →
/// `POST /food/orders/calculate` — this sheet never decides eligibility
/// itself (the min-spend note is a hint only, not a client-side gate).
class CouponSheet {
  const CouponSheet._();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CouponSheetBody(),
    );
  }
}

class _CouponSheetBody extends ConsumerStatefulWidget {
  const _CouponSheetBody();

  @override
  ConsumerState<_CouponSheetBody> createState() => _CouponSheetBodyState();
}

class _CouponSheetBodyState extends ConsumerState<_CouponSheetBody> {
  final _controller = TextEditingController();
  bool _applying = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _apply(String code) async {
    if (code.trim().isEmpty || _applying) return;
    Haptics.light();
    setState(() => _applying = true);

    // ignore: avoid_print
    print('[COUPON] Applying code: ${code.trim().toUpperCase()}');
    await ref.read(checkoutViewModelProvider.notifier).applyCoupon(code);
    if (!mounted) return;

    final result = ref.read(checkoutViewModelProvider);
    final pricing = result.pricing;
    final applied = pricing?.hasCouponApplied ?? false;
    // ignore: avoid_print
    print(
      '[COUPON] Applied: $applied, discount: ${pricing?.discount}, '
      'couponCode echoed: ${pricing?.couponCode}, total: ${pricing?.total}',
    );

    setState(() => _applying = false);
    if (!context.mounted) return;

    if (applied) {
      AppSnackbar.success(
        context,
        'Coupon ${pricing!.couponCode ?? code.trim().toUpperCase()} applied! '
        'You saved ₹${pricing.discount.toStringAsFixed(0)}',
      );
      Navigator.of(context).pop();
    } else {
      AppSnackbar.error(context, 'This coupon is not applicable to your order.');
    }
  }

  Future<void> _remove() async {
    Haptics.light();
    await ref.read(checkoutViewModelProvider.notifier).removeCoupon();
    if (!mounted || !context.mounted) return;
    AppSnackbar.info(context, 'Coupon removed');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    final checkoutState = ref.watch(checkoutViewModelProvider);
    final pricing = checkoutState.pricing;
    final appliedCode =
        (pricing?.hasCouponApplied ?? false) ? checkoutState.couponCode : null;
    final coupons = ref.watch(couponsViewModelProvider);
    final cartSubtotal = ref.watch(cartViewModelProvider).subtotal;

    // Mirrors FoodDetailSheet's proven DraggableScrollableSheet structure.
    //
    // Interactive buttons here are hand-rolled InkWell/Material, never
    // ElevatedButton/TextButton: a ButtonStyleButton's internal
    // _RenderInputPadding throws "BoxConstraints forces an infinite width"
    // when nested this deep inside a ListView item inside this sheet's
    // LayoutBuilder — the exact pattern FoodDetailSheet's own CTA already
    // avoids for the same reason.
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Container(
            color: isDark ? AppColors.backgroundDark : Colors.white,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: secondaryColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    children: [
                      Text(
                        'Apply Coupon',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (appliedCode != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.success),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '$appliedCode applied · You saved ₹${pricing!.discount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              _textPill('REMOVE', AppColors.success, _remove),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: 'Enter coupon code',
                                filled: true,
                                fillColor:
                                    isDark ? AppColors.cardDark : const Color(0xFFF5F6F8),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 14,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          _filledPill(
                            _applying
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'APPLY',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                                  ),
                            _applying ? null : () => _apply(_controller.text),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (coupons.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No eligible coupon found.',
                              style: TextStyle(color: secondaryColor),
                            ),
                          ),
                        )
                      else
                        ...coupons.map(
                          (c) => _couponTile(c, cartSubtotal, textColor, secondaryColor),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A pill-shaped filled button — replaces `ElevatedButton`, which throws
  /// "BoxConstraints forces an infinite width" in this sheet's widget tree.
  Widget _filledPill(Widget child, VoidCallback? onTap) {
    return Material(
      color: onTap == null ? AppColors.primary.withValues(alpha: 0.5) : AppColors.primary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: child,
        ),
      ),
    );
  }

  /// A text-only tap target — replaces `TextButton` for the same reason as
  /// [_filledPill].
  Widget _textPill(String label, Color color, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: onTap == null ? color.withValues(alpha: 0.4) : color,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _couponTile(
    CouponModel c,
    double cartSubtotal,
    Color textColor,
    Color secondaryColor,
  ) {
    final eligible = cartSubtotal >= c.minSpend;
    return Opacity(
      opacity: eligible ? 1 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: secondaryColor.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.code,
                    style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    c.discountText,
                    style: TextStyle(color: secondaryColor, fontSize: 12),
                  ),
                  if (!eligible && c.minSpend > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Min order ₹${c.minSpend.toStringAsFixed(0)}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            _textPill(
              'APPLY',
              AppColors.primary,
              (!eligible || _applying) ? null : () => _apply(c.code),
            ),
          ],
        ),
      ),
    );
  }
}
