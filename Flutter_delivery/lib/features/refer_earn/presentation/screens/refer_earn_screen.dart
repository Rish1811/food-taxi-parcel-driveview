import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/services/sound_service.dart';
import 'package:food_user_application/features/refer_earn/application/referral_controller.dart';
import 'package:food_user_application/features/refer_earn/data/models/referral_stats.dart';
import 'package:food_user_application/features/refer_earn/presentation/widgets/referral_ticket_card.dart';
import 'package:food_user_application/features/refer_earn/presentation/widgets/refer_earn_background.dart';

class ReferEarnScreen extends ConsumerStatefulWidget {
  const ReferEarnScreen({super.key});

  @override
  ConsumerState<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends ConsumerState<ReferEarnScreen>
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

    // 2. Ticket scaling up slightly once it's fully out.
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
    SoundService.stopEffect();
    super.dispose();
  }

  void _startPrinting(ReferralStats stats) {
    if (stats.remainingReferrals <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral limit reached')),
      );
      return;
    }
    
    HapticService.medium();
    SoundService.playTap('printtab.mp3');

    // The machine sound starts the instant printing begins, and is capped
    // at 6s regardless of how long the animation/asset actually runs.
    SoundService.playEffect('refferticketcomeout.mp3');
    Future.delayed(const Duration(seconds: 6), () {
      SoundService.stopEffect();
    });

    setState(() => _isPrintingStarted = true);
    _animationController.forward();
  }

  Widget _buildStatusChip(InvitedPartner partner) {
    Color color;
    String text;
    
    if (partner.status == 'credited') {
      color = Colors.green;
      text = 'Earned ₹${partner.earnedAmount}';
    } else if (partner.status == 'rejected') {
      color = Colors.grey;
      text = partner.reason.isNotEmpty ? partner.reason : 'Rejected';
    } else {
      color = Colors.amber;
      if (partner.partnerStatus == 'pending') {
        text = 'Waiting for approval';
      } else {
        text = 'Waiting for first delivery';
      }
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statsState = ref.watch(referralControllerProvider);

    return Scaffold(
      backgroundColor: ReferEarnBackground.solid,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Refer & earn',
          style: TextStyle(color: Colors.white, fontSize: 16.sp),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => context.push('/help'),
          ),
        ],
      ),
      body: ReferEarnBackground(
        child: statsState.when(
          data: (stats) {
            if (stats == null) return const SizedBox.shrink();

            return SingleChildScrollView(
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
                    'Invite a rider, earn ₹${stats.rewardAmount}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Text(
                      stats.rewardCondition,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Earned: ₹${stats.totalReferralEarnings}',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 14.sp, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(width: 16.w),
                      Text(
                        '${stats.referralCount}/${stats.referralLimit} used',
                        style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                      ),
                    ],
                  ),
                  SizedBox(height: 30.h),

                  // Main animation area
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
                                                color: theme.primaryColor,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            Text(
                                              'foodie\nrewards',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontWeight: FontWeight.bold,
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
                                        _startPrinting(stats);
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
                                                color: stats.remainingReferrals <= 0 
                                                    ? Colors.grey 
                                                    : theme.primaryColor,
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
                                              stats.remainingReferrals <= 0 
                                                  ? 'LIMIT REACHED' 
                                                  : 'TAP TO CREATE',
                                              style: TextStyle(
                                                color: stats.remainingReferrals <= 0 
                                                    ? Colors.grey 
                                                    : theme.primaryColor,
                                                fontWeight: FontWeight.bold,
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

                  // Invited Partners List
                  if (stats.invitedPartners.isNotEmpty) ...[
                    SizedBox(height: 40.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Row(
                        children: [
                          Text(
                            'Invited Partners',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: stats.invitedPartners.length,
                      itemBuilder: (context, index) {
                        final partner = stats.invitedPartners[index];
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
                          padding: EdgeInsets.all(12.r),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
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
                                    style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'Joined: ${partner.invitedAt.split('T').first}',
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
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
        ),
      ),
    );
  }
}
