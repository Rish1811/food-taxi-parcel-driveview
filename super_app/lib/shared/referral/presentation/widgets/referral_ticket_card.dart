import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:superapp_user/shared/wallet/data/wallet_model.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:superapp_user/shared/referral/presentation/viewmodels/referral_viewmodel.dart';
import 'package:superapp_user/shared/referral/presentation/widgets/ticket_clipper.dart';

class ReferralTicketCard extends ConsumerWidget {
  final double? width;
  final double? height;

  static const double aspectRatio = 417 / 520;

  const ReferralTicketCard({
    super.key,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(referralDetailsProvider).value ?? const ReferralDetails();
    final user = ref.watch(authViewModelProvider).value;

    final code = details.referralCode.isNotEmpty
        ? details.referralCode
        : (user?.referralCode.isNotEmpty == true ? user!.referralCode : 'SUVO25');
    final rewardStr = details.rewardAmount > 0
        ? '₹${details.rewardAmount.toStringAsFixed(0)}'
        : '₹100';

    final cardWidth = width ?? 260.w;
    final cardHeight = height ?? (cardWidth / aspectRatio);
    final notch = 14.r;

    return Container(
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipPath(
        clipper: TicketCardClipper(notch: notch),
        child: Container(
          width: cardWidth,
          height: cardHeight,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF7A00), Color(0xFFFF9900)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Top Logo Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.fastfood_rounded,
                          color: Colors.white,
                          size: 18.sp,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'SUVIO FOOD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Text(
                      'TICKET',
                      style: TextStyle(
                        color: const Color(0xFFFF7A00),
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              // 2. Dashed Divider Line (Custom Row of small containers)
              Row(
                children: List.generate(
                  24,
                  (index) => Expanded(
                    child: Container(
                      height: 1.5.h,
                      color: index % 2 == 0 ? Colors.white60 : Colors.transparent,
                    ),
                  ),
                ),
              ),

              // 3. Center Reward Amount
              Column(
                children: [
                  Text(
                    'YOU & YOUR FRIEND GET',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    rewardStr,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'On 1st successful order',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),

              // 4. Bottom Referral Code Box
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: [
                    Text(
                      'REFERRAL CODE',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      code,
                      style: TextStyle(
                        color: const Color(0xFFFF7A00),
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
