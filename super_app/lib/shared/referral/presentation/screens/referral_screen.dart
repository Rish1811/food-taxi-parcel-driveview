import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/app/routing/back_navigation.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/core/audio/referral_audio_player.dart';
import 'package:superapp_user/shared/wallet/data/wallet_model.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/skeletons/skeleton_loading.dart';
import 'package:superapp_user/shared/referral/presentation/viewmodels/referral_viewmodel.dart';
import 'package:superapp_user/shared/referral/presentation/widgets/refer_earn_background.dart';
import 'package:superapp_user/shared/referral/presentation/widgets/referral_ticket_card.dart';

class ReferralScreen extends ConsumerStatefulWidget {
  const ReferralScreen({super.key});

  @override
  ConsumerState<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends ConsumerState<ReferralScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _printAnimation;
  late Animation<double> _scaleAnimation;

  bool _isPrintingStarted = false;
  bool _isButtonPressed = false;

  double get _ticketWidth => 260.w;
  double get _ticketHeight => _ticketWidth / ReferralTicketCard.aspectRatio;

  // Ticket feeds out for a steady 4s (like an ATM receipt), then a quick
  // 500ms settle/bounce once it's fully out.
  static const int _printMs = 4000;
  static const int _settleMs = 500;
  static const int _totalMs = _printMs + _settleMs;
  static const double _printEndFraction = _printMs / _totalMs;

  @override
  void initState() {
    super.initState();
    ReferralAudioPlayer().init();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalMs),
    );

    // 1. Ticket feeding out of the slot at a steady mechanical pace.
    _printAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, _printEndFraction, curve: Curves.linear),
      ),
    );

    // 2. Ticket scaling up slightly once it's fully out (settle bounce).
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(_printEndFraction, 1.0, curve: Curves.easeInOut),
      ),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Give the user a beat to see the finished ticket before moving to
        // the dedicated result page.
        Future.delayed(const Duration(milliseconds: 700), () {
          if (mounted) context.push('/refer-earn/ticket');
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    ReferralAudioPlayer().stop();
    super.dispose();
  }

  void _startPrinting(ReferralDetails details) {
    Haptics.medium();
    ReferralAudioPlayer().playOnce();
    setState(() => _isPrintingStarted = true);
    _animationController.forward();
  }

  Widget _buildStatusChip(ReferralInvite partner) {
    Color color;
    String text;

    final statusLower = partner.status.toLowerCase();
    if (statusLower == 'credited') {
      color = Colors.green;
      text = partner.earnedAmount > 0
          ? 'Earned ₹${partner.earnedAmount.toStringAsFixed(0)}'
          : 'Credited';
    } else if (statusLower == 'rejected') {
      color = Colors.grey;
      text = partner.reason?.isNotEmpty == true ? partner.reason! : 'Rejected';
    } else {
      color = Colors.amber;
      text = 'Waiting for order';
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.w600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(referralDetailsProvider);

    return Scaffold(
      backgroundColor: ReferEarnBackground.solid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.backOr(),
        ),
        title: Text(
          'Refer & earn',
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
        ),
        centerTitle: true,
      ),
      body: ReferEarnBackground(
        child: detailsAsync.when(
          data: (details) {
            final rewardAmountStr = details.rewardAmount > 0
                ? details.rewardAmount.toStringAsFixed(0)
                : '100';
            final totalEarnedStr = details.totalEarnings.toStringAsFixed(0);
            final totalInvited = details.totalInvited > 0
                ? details.totalInvited
                : details.referralCount;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  SizedBox(height: 20.h),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_alt_outlined, color: Colors.grey, size: 20),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Invite a friend, earn ₹$rewardAmountStr',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(
                      'Earn ₹$rewardAmountStr when your friend completes their first order!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Earned: ₹$totalEarnedStr',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Text(
                        '$totalInvited referrals',
                        style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                      ),
                    ],
                  ),
                  SizedBox(height: 30.h),

                  // Main printer animation area
                  SizedBox(
                    height: 400.h,
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.topCenter,
                              children: [
                                // 1. The white printer base
                                Container(
                                  width: 320.w,
                                  height: 380.h,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24.r),
                                  ),
                                  child: Column(
                                    children: [
                                      SizedBox(height: 20.h),
                                      Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 20.w,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              width: 12.r,
                                              height: 12.r,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Text(
                                              'K9\nrewards',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontWeight: FontWeight.w600,
                                                height: 1.1,
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 40.h),

                                      // The slot the ticket prints out of
                                      Container(
                                        height: 15.h,
                                        width: 280.w,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(10.r),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Colors.black26,
                                              blurRadius: 5,
                                              offset: Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Container(
                                            height: 4.h,
                                            width: 270.w,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // 2. The animated ticket — stays blurred while it's
                                // still feeding out, then sharpens once fully printed.
                                Positioned(
                                  top: 110.h,
                                  child: ClipRect(
                                    child: Align(
                                      alignment: Alignment.topCenter,
                                      heightFactor: _printAnimation.value,
                                      child: ImageFiltered(
                                        imageFilter: ImageFilter.blur(
                                          sigmaX: (1 - _printAnimation.value) * 10,
                                          sigmaY: (1 - _printAnimation.value) * 10,
                                        ),
                                        child: ReferralTicketCard(
                                          width: _ticketWidth,
                                          height: _ticketHeight,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),

                                // 3. Tap-to-create button (fades out once tapped)
                                if (!_isPrintingStarted)
                                  Positioned(
                                    top: 200.h,
                                    child: GestureDetector(
                                      onTapDown: (_) =>
                                          setState(() => _isButtonPressed = true),
                                      onTapCancel: () =>
                                          setState(() => _isButtonPressed = false),
                                      onTapUp: (_) {
                                        setState(() => _isButtonPressed = false);
                                        _startPrinting(details);
                                      },
                                      child: AnimatedScale(
                                        scale: _isButtonPressed ? 0.88 : 1.0,
                                        duration: const Duration(milliseconds: 120),
                                        curve: Curves.easeOut,
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 120.r,
                                              height: 120.r,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white24,
                                                  width: 10.w,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.touch_app,
                                                color: Colors.white,
                                                size: 50.sp,
                                              ),
                                            ),
                                            SizedBox(height: 20.h),
                                            Text(
                                              'TAP TO CREATE',
                                              style: TextStyle(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 1.2,
                                                fontSize: 13.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Invited Friends List
                  if (details.invitedFriends.isNotEmpty) ...[
                    SizedBox(height: 40.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Row(
                        children: [
                          Text(
                            'Invited Friends',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: details.invitedFriends.length,
                      itemBuilder: (context, index) {
                        final partner = details.invitedFriends[index];
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    partner.name.isNotEmpty ? partner.name : partner.phone,
                                    style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    partner.phone.isNotEmpty ? partner.phone : 'Friend',
                                    style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                                  ),
                                ],
                              ),
                              _buildStatusChip(partner),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  SizedBox(height: 40.h),
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: SkeletonBanner(height: 380),
          ),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }
}
