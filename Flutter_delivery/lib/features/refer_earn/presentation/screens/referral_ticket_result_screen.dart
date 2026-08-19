import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:food_user_application/features/refer_earn/application/referral_controller.dart';
import 'package:food_user_application/features/refer_earn/presentation/widgets/referral_ticket_card.dart';
import 'package:food_user_application/features/refer_earn/presentation/widgets/rotating_ticket_border.dart';
import 'package:food_user_application/features/refer_earn/presentation/widgets/fire_particle_share_button.dart';
import 'package:food_user_application/features/refer_earn/presentation/widgets/refer_earn_background.dart';

/// The dedicated "here's your ticket" page shown right after the referral
/// ticket finishes printing — just the ticket, the hand, and the share
/// button, without the printer machine chrome.
class ReferralTicketResultScreen extends ConsumerStatefulWidget {
  const ReferralTicketResultScreen({super.key});

  @override
  ConsumerState<ReferralTicketResultScreen> createState() =>
      _ReferralTicketResultScreenState();
}

class _ReferralTicketResultScreenState extends ConsumerState<ReferralTicketResultScreen>
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
    final stats = ref.read(referralControllerProvider).value;
    if (stats == null) return;

    if (stats.referralLink.isNotEmpty) {
      Share.share('Join Suvio as a delivery partner — we both earn! ${stats.referralLink}');
    } else if (stats.referralCode.isNotEmpty) {
      Share.share('Join Suvio as a delivery partner. Use my referral code: ${stats.referralCode}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Referral code not available right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            onPressed: () {},
          ),
        ],
      ),
      body: ReferEarnBackground(
        child: SafeArea(
          child: statsState.when(
            data: (stats) {
              if (stats == null) return const SizedBox.shrink();
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
                    'Earn ₹${stats.rewardAmount} on every referral',
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
                        if (stats.referralCode.isNotEmpty) ...[
                          SizedBox(height: 8.h),
                          TextButton.icon(
                            onPressed: () {
                              // Optional: copy to clipboard
                              // Clipboard.setData(ClipboardData(text: stats.referralCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Code ${stats.referralCode} copied!')),
                              );
                            },
                            icon: const Icon(Icons.copy, color: Colors.white, size: 16),
                            label: Text('Copy code: ${stats.referralCode}', style: const TextStyle(color: Colors.white)),
                          )
                        ],
                        SizedBox(height: 8.h),
                        Text(
                          'You earn ₹${stats.rewardAmount} & your friend gets\n₹${stats.rewardAmount} on successful referral',
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
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
          ),
        ),
      ),
    );
  }
}
