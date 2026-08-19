import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:superapp_user/app/routing/back_navigation.dart';
import 'package:share_plus/share_plus.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';
import 'package:superapp_user/design_system/components/skeletons/skeleton_loading.dart';
import 'package:superapp_user/shared/referral/presentation/viewmodels/referral_viewmodel.dart';
import 'package:superapp_user/shared/referral/presentation/widgets/fire_particle_share_button.dart';
import 'package:superapp_user/shared/referral/presentation/widgets/refer_earn_background.dart';
import 'package:superapp_user/shared/referral/presentation/widgets/referral_ticket_card.dart';
import 'package:superapp_user/shared/referral/presentation/widgets/rotating_ticket_border.dart';

/// The dedicated "here's your ticket" page shown right after the referral
/// ticket finishes printing — just the ticket and the share button.
class ReferralTicketResultScreen extends ConsumerStatefulWidget {
  const ReferralTicketResultScreen({super.key});

  @override
  ConsumerState<ReferralTicketResultScreen> createState() =>
      _ReferralTicketResultScreenState();
}

class _ReferralTicketResultScreenState
    extends ConsumerState<ReferralTicketResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entryController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  double get _ticketWidth => 240.w;
  double get _ticketHeight => _ticketWidth / ReferralTicketCard.aspectRatio;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeIn));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _shareTicket() {
    final details = ref.read(referralDetailsProvider).value;
    final user = ref.read(authViewModelProvider).value;
    final code = details?.referralCode.isNotEmpty == true
        ? details!.referralCode
        : (user?.referralCode ?? '');
    final rewardStr = (details != null && details.rewardAmount > 0)
        ? '₹${details.rewardAmount.toStringAsFixed(0)}'
        : '₹100';

    final msg = details?.shareText.isNotEmpty == true
        ? details!.shareText
        : (details?.referralLink.isNotEmpty == true
            ? 'Join me on K9 and get $rewardStr off on your first order! ${details!.referralLink}'
            : 'Join K9 as a user. Use my referral code: $code');

    Haptics.medium();
    SharePlus.instance.share(ShareParams(text: msg));
  }

  @override
  Widget build(BuildContext context) {
    final detailsAsync = ref.watch(referralDetailsProvider);
    final user = ref.watch(authViewModelProvider).value;

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
        child: SafeArea(
          child: detailsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: SkeletonBanner(height: 300),
            ),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
            data: (details) {
              final code = details.referralCode.isNotEmpty
                  ? details.referralCode
                  : (user?.referralCode ?? 'SUVO25');
              final rewardAmountStr = details.rewardAmount > 0
                  ? details.rewardAmount.toStringAsFixed(0)
                  : '100';

              return Column(
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
                    'Earn ₹$rewardAmountStr on every referral',
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
                      'Earn credits when your friend completes their first order!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
                    ),
                  ),

                  // Ticket — tilted, with a rotating glow tracing its edge.
                  Expanded(
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _entryController,
                        builder: (context, child) => Opacity(
                          opacity: _fadeAnimation.value,
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: child,
                          ),
                        ),
                        child: Transform.rotate(
                          angle: -0.09,
                          child: RotatingTicketBorder(
                            width: _ticketWidth,
                            height: _ticketHeight,
                            notch: 14.r,
                            child: ReferralTicketCard(
                              width: _ticketWidth,
                              height: _ticketHeight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Share button
                  Padding(
                    padding: EdgeInsets.only(bottom: 24.h),
                    child: Column(
                      children: [
                        FireParticleShareButton(onPressed: _shareTicket),
                        if (code.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          TextButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: code));
                              Haptics.light();
                              AppSnackbar.success(context, 'Code $code copied!');
                            },
                            icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                            label: Text('Copy code: $code', style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                        SizedBox(height: 8.h),
                        Text(
                          'You earn ₹$rewardAmountStr & your friend gets\n₹$rewardAmountStr on successful referral',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
