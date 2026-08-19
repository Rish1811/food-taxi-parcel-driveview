import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';
import 'package:superapp_user/modules/food/presentation/orders/viewmodels/orders_viewmodel.dart';

/// Bottom sheet for rating a delivered order — food, delivery partner (if
/// any), and individual items, submitted together in one PATCH call.
class RateOrderSheet extends ConsumerStatefulWidget {
  const RateOrderSheet({super.key, required this.order});

  final OrderModel order;

  @override
  ConsumerState<RateOrderSheet> createState() => _RateOrderSheetState();
}

class _RateOrderSheetState extends ConsumerState<RateOrderSheet> {
  int _restaurantRating = 0;
  int _deliveryRating = 0;
  final _restaurantComment = TextEditingController();
  final _deliveryComment = TextEditingController();
  final Map<String, int> _itemRatings = {};
  final Map<String, TextEditingController> _itemComments = {};
  bool _isSubmitting = false;
  String? _error;

  bool get _hasDeliveryPartner => widget.order.deliveryPartner != null;

  bool get _canSubmit =>
      _restaurantRating > 0 && (!_hasDeliveryPartner || _deliveryRating > 0);

  @override
  void dispose() {
    _restaurantComment.dispose();
    _deliveryComment.dispose();
    for (final controller in _itemComments.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _commentControllerFor(String itemId) =>
      _itemComments.putIfAbsent(itemId, TextEditingController.new);

  Future<void> _submit() async {
    if (!_canSubmit) {
      setState(
        () => _error = _hasDeliveryPartner
            ? 'Please rate both the food and the delivery partner.'
            : 'Please rate your food.',
      );
      return;
    }

    Haptics.light();
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final itemRatings = _itemRatings.entries
        .where((e) => e.value > 0)
        .map(
          (e) => {
            'itemId': e.key,
            'rating': e.value,
            if (_commentControllerFor(e.key).text.trim().isNotEmpty)
              'comment': _commentControllerFor(e.key).text.trim(),
          },
        )
        .toList();

    final error = await ref
        .read(ordersViewModelProvider.notifier)
        .submitRating(
          widget.order.id,
          restaurantRating: _restaurantRating,
          deliveryPartnerRating: _hasDeliveryPartner ? _deliveryRating : null,
          restaurantComment: _restaurantComment.text.trim().isEmpty
              ? null
              : _restaurantComment.text.trim(),
          deliveryPartnerComment: _deliveryComment.text.trim().isEmpty
              ? null
              : _deliveryComment.text.trim(),
          itemRatings: itemRatings.isEmpty ? null : itemRatings,
        );

    if (!mounted) return;

    if (error == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _isSubmitting = false;
        _error = error;
      });
      AppSnackbar.error(context, error);
    }
  }

  Widget _starPicker(int value, ValueChanged<int> onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < value;
        return GestureDetector(
          onTap: () {
            Haptics.light();
            onChanged(index + 1);
          },
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.w),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: filled ? AppColors.rating : const Color(0xFFD1D5DB),
              size: 30.sp,
            ),
          ),
        );
      }),
    );
  }

  Widget _commentField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      maxLines: 2,
      maxLength: 500,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        counterText: '',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final order = widget.order;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 10.h),
              Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.borderDark
                      : const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.r, 16.r, 20.r, 24.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rate Your Order',
                        style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        order.restaurantName.isNotEmpty
                            ? order.restaurantName
                            : 'Your order',
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          color: secondaryColor,
                        ),
                      ),
                      SizedBox(height: 20.h),

                      Text(
                        'Food Rating',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      _starPicker(
                        _restaurantRating,
                        (v) => setState(() => _restaurantRating = v),
                      ),
                      SizedBox(height: 10.h),
                      _commentField(
                        _restaurantComment,
                        'Add a comment about the food (optional)',
                      ),

                      if (_hasDeliveryPartner) ...[
                        SizedBox(height: 20.h),
                        Text(
                          'Delivery Partner Rating',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        _starPicker(
                          _deliveryRating,
                          (v) => setState(() => _deliveryRating = v),
                        ),
                        SizedBox(height: 10.h),
                        _commentField(
                          _deliveryComment,
                          'Add a comment about the delivery (optional)',
                        ),
                      ],

                      if (order.items.isNotEmpty) ...[
                        SizedBox(height: 20.h),
                        Text(
                          'Rate Items',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        ...order.items.map(
                          (item) => Padding(
                            padding: EdgeInsets.only(bottom: 14.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 12.5.sp,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 6.h),
                                _starPicker(
                                  _itemRatings[item.itemId] ?? 0,
                                  (v) => setState(
                                    () => _itemRatings[item.itemId] = v,
                                  ),
                                ),
                                SizedBox(height: 8.h),
                                _commentField(
                                  _commentControllerFor(item.itemId),
                                  'Comment on this item (optional)',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      if (_error != null) ...[
                        SizedBox(height: 8.h),
                        Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.error,
                          ),
                        ),
                      ],

                      SizedBox(height: 20.h),
                      SizedBox(
                        width: double.infinity,
                        height: 48.h,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: _isSubmitting
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Submit Rating',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
