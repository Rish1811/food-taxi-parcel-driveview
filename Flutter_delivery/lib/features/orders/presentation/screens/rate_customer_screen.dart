import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/features/orders/application/pending_customer_rating_controller.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/data/orders_repository.dart';

/// Full-screen overlay stacked over the app (see main.dart) whenever
/// [pendingCustomerRatingControllerProvider] is non-null — auto-shown right
/// after a delivery completes, regardless of which screen the app lands on
/// afterward.
class RateCustomerScreen extends ConsumerStatefulWidget {
  const RateCustomerScreen({super.key, required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<RateCustomerScreen> createState() => _RateCustomerScreenState();
}

class _RateCustomerScreenState extends ConsumerState<RateCustomerScreen> {
  int _rating = 0;
  bool _submitting = false;
  String? _error;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _cancel() {
    if (_submitting) return;
    ref.read(pendingCustomerRatingControllerProvider.notifier).dismiss();
  }

  Future<void> _submit() async {
    if (_rating == 0 || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final comment = _commentController.text.trim();
    final result = await ref.read(ordersRepositoryProvider).rateCustomer(
          widget.order.id,
          rating: _rating,
          comment: comment.isEmpty ? null : comment,
        );
    if (!mounted) return;
    result.when(
      success: (_) =>
          ref.read(pendingCustomerRatingControllerProvider.notifier).dismiss(),
      failure: (error) => setState(() {
        _error = error.message;
        _submitting = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];

    return Material(
      color: Colors.black.withOpacity(0.5),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _cancel,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: SafeArea(
              top: false,
              child: Container(
                margin: EdgeInsets.all(12.w),
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(28.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rate the Customer',
                      style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: textColor),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      widget.order.customerName.isNotEmpty
                          ? widget.order.customerName
                          : 'How was your delivery experience?',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13.sp, color: subTextColor, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 18.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) {
                        final starIndex = i + 1;
                        return GestureDetector(
                          onTap: () => setState(() => _rating = starIndex),
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4.w),
                            child: Icon(
                              starIndex <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: starIndex <= _rating ? const Color(0xFFFFC107) : subTextColor,
                              size: 38.sp,
                            ),
                          ),
                        );
                      }),
                    ),
                    SizedBox(height: 16.h),
                    TextField(
                      controller: _commentController,
                      maxLines: 2,
                      style: TextStyle(color: textColor, fontSize: 13.sp),
                      decoration: InputDecoration(
                        hintText: 'Add a comment (optional)',
                        hintStyle: TextStyle(color: subTextColor, fontSize: 13.sp),
                        filled: true,
                        fillColor: isDarkMode ? Colors.white10 : Colors.black.withOpacity(0.04),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                      ),
                    ),
                    if (_error != null) ...[
                      SizedBox(height: 8.h),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ],
                    SizedBox(height: 16.h),
                    ElevatedButton(
                      onPressed: _rating == 0 || _submitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size(double.infinity, 48.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                      ),
                      child: _submitting
                          ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Submit Rating'),
                    ),
                    SizedBox(height: 8.h),
                    TextButton(
                      onPressed: _submitting ? null : _cancel,
                      child: Text('Cancel', style: TextStyle(color: subTextColor, fontWeight: FontWeight.w700)),
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
