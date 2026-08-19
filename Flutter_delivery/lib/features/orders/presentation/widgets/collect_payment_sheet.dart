import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:food_user_application/core/constants/app_constants.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/features/auth/application/auth_controller.dart';
import 'package:food_user_application/features/auth/application/auth_state.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/data/orders_repository.dart';

class CollectPaymentSheet extends ConsumerStatefulWidget {
  const CollectPaymentSheet({super.key, required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<CollectPaymentSheet> createState() => _CollectPaymentSheetState();
}

class _CollectPaymentSheetState extends ConsumerState<CollectPaymentSheet> {
  bool _collecting = false;
  bool _showQr = false;
  bool _completed = false;
  String? _error;

  /// Both "Collect Cash Instead" and "Payment Received" (after showing the
  /// driver's own QR) hit the same cash-collection API — the backend marks a
  /// cash order paid automatically once delivery completes, regardless of how
  /// the money was physically handed over, so there's no separate "QR paid"
  /// endpoint to call here.
  Future<void> _confirmCollected() async {
    setState(() {
      _collecting = true;
      _error = null;
    });
    final result = await ref.read(ordersRepositoryProvider).collectCash(widget.order.id);
    if (!mounted) return;
    await result.when(
      success: (_) async {
        setState(() => _completed = true);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) Navigator.of(context).pop(true);
      },
      failure: (error) async => setState(() {
        _error = error.message;
        _collecting = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final order = widget.order;
    final authState = ref.watch(authControllerProvider);
    final upiQrCode = authState is AuthAuthenticated ? authState.user.upiQrCode : null;

    return SafeArea(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Collect Payment',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: textColor),
                ),
                Text(
                  '₹${order.total.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: theme.primaryColor),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            if (_completed)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24.h),
                child: Column(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 48.sp),
                    SizedBox(height: 12.h),
                    Text(
                      'Delivery Completed',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.sp, color: textColor),
                    ),
                  ],
                ),
              )
            else ...[
              if (_showQr) ...[
                if (upiQrCode != null && upiQrCode.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: CachedNetworkImage(
                      imageUrl: AppConstants.resolveMediaUrl(upiQrCode),
                      width: 200.w,
                      height: 200.w,
                      fit: BoxFit.contain,
                      memCacheWidth: 400,
                      memCacheHeight: 400,
                      placeholder: (_, _) => SizedBox(
                        width: 200.w,
                        height: 200.w,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Icon(Icons.broken_image, size: 50.sp, color: Colors.grey),
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Text(
                      'No UPI QR code uploaded on your profile yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.sp, color: subTextColor),
                    ),
                  ),
                SizedBox(height: 12.h),
                Text(
                  'Ask the customer to scan this QR to pay',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.sp, color: subTextColor),
                ),
                SizedBox(height: 16.h),
                ElevatedButton.icon(
                  onPressed: _collecting ? null : _confirmCollected,
                  icon: _collecting
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('Payment Received'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 48.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  ),
                ),
              ] else
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showQr = true),
                  icon: const Icon(Icons.qr_code_rounded),
                  label: const Text('Show QR to Customer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, 48.h),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                  ),
                ),
              if (_error != null) ...[
                SizedBox(height: 8.h),
                Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ],
              SizedBox(height: 12.h),
              OutlinedButton.icon(
                onPressed: _collecting ? null : _confirmCollected,
                icon: _collecting
                    ? SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: CircularProgressIndicator(strokeWidth: 2, color: theme.primaryColor),
                      )
                    : const Icon(Icons.money_rounded),
                label: const Text('Collect Cash Instead'),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
