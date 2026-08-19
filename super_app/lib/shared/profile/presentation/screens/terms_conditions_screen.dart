import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    Haptics.light();
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (context.mounted) {
          AppSnackbar.info(context, 'Calling $phoneNumber...');
        }
      }
    } catch (_) {}
  }

  Future<void> _sendEmail(BuildContext context, String emailAddress) async {
    Haptics.light();
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: emailAddress,
      //queryParameters: {'subject': 'Terms & Conditions Inquiry - K9 App'},
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (context.mounted) {
          AppSnackbar.info(context, 'Opening mail to $emailAddress...');
        }
      }
    } catch (_) {}
  }

  void _showTermsDetailModal(BuildContext context, String title, String summary, String fullText) {
    Haptics.light();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
        final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

        return Container(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 28.h),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.borderDark : const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                summary,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                  height: 1.3,
                ),
              ),
              SizedBox(height: 10.h),
              Text(
                fullText,
                style: TextStyle(
                  fontSize: 12.5.sp,
                  height: 1.45,
                  color: secondaryTextColor,
                ),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                width: double.infinity,
                height: 44.h,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: const Text('Understand & Close', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB);
    final cardBg = isDark ? AppColors.surfaceDark : Colors.white;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.chevron_left_rounded, size: 28.sp, color: textColor),
          onPressed: () {
            Haptics.light();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Terms and Conditions',
          style: TextStyle(
            color: textColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. HERO BANNER CARD
              _buildHeroCard(isDark, textColor, secondaryTextColor),

              SizedBox(height: 16.h),

              // 2. TERMS SECTIONS LIST CARD (9 Items matching screenshot)
              _buildTermsSectionsCard(context, isDark, textColor, secondaryTextColor),

              SizedBox(height: 16.h),

              // 3. NEED HELP? CONTACT CARD (Phone & Email with dynamic actions)
              _buildNeedHelpCard(context, isDark, textColor, secondaryTextColor),

              SizedBox(height: 16.h),

              // 4. FOOTER & CLOSE BUTTON
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: const Color(0xFFFF6D00),
                        size: 15.sp,
                      ),
                      SizedBox(width: 5.w),
                      Flexible(
                        child: Text(
                          'By using K9, you agree to these Terms and Conditions.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    'Thank you for choosing K9!',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: secondaryTextColor,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  SizedBox(
                    width: double.infinity,
                    height: 48.h,
                    child: ElevatedButton(
                      onPressed: () {
                        Haptics.light();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24.r),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  /// 1. Hero Card: Headline + Orange Accent Line + Description + 3D Clipboard Illustration
  Widget _buildHeroCard(bool isDark, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF231A14),
                  const Color(0xFF1E1A16),
                ]
              : [
                  const Color(0xFFFFFBF5),
                  const Color(0xFFFFF4EA),
                ],
        ),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: isDark ? const Color(0xFF3D2B1F) : const Color(0xFFFFE5D0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                    children: [
                      TextSpan(
                        text: 'Terms &\n',
                        style: TextStyle(color: AppColors.primary),
                      ),
                      TextSpan(
                        text: 'Conditions',
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 6.h),
                Container(
                  width: 32.w,
                  height: 2.5.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 10.h),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: secondaryTextColor,
                      height: 1.35,
                    ),
                    children: [
                      TextSpan(text: 'Please read these terms carefully before using the '),
                      TextSpan(
                        text: 'K9',
                        style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                      TextSpan(text: ' app.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          SizedBox(
            width: 130.w,
            height: 130.h,
            child: Image.asset(
              'assets/images/terms_clipboard.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.assignment_rounded,
                color: AppColors.primary,
                size: 64.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Terms Sections List Card (9 Items matching screenshot)
  Widget _buildTermsSectionsCard(
      BuildContext context, bool isDark, Color textColor, Color secondaryTextColor) {
    final sections = [
      {
        'icon': Icons.description_outlined,
        'title': '1. Acceptance of Terms',
        'subtitle': 'By accessing or using the K9 app, you agree to be bound by these Terms and Conditions.',
        'fullText': 'By creating an account, browsing menus, or placing an order on K9, you acknowledge that you have read, understood, and agreed to abide by all operating rules and policies stated herein.',
      },
      {
        'icon': Icons.person_outline_rounded,
        'title': '2. Use of the App',
        'subtitle': 'You agree to use the app only for lawful purposes and in accordance with these terms.',
        'fullText': 'You must be at least 18 years old or under parental supervision to use K9 services. Accounts registered using false information or automated bots are subject to immediate termination.',
      },
      {
        'icon': Icons.shopping_bag_outlined,
        'title': '3. Orders & Payments',
        'subtitle': 'All orders are subject to availability. Prices are as shown in the app and may change without prior notice.',
        'fullText': 'All food item prices are set by merchant restaurant partners. Menu availability is managed in real-time. Payments processed via Razorpay, UPI, or Wallet are authorized at checkout.',
      },
      {
        'icon': Icons.two_wheeler_rounded,
        'title': '4. Delivery',
        'subtitle': 'We strive to deliver your order on time. Delivery times are estimates and may vary due to external factors.',
        'fullText': 'Delivery durations shown during checkout are live estimates calculated based on kitchen prep times, rider availability, weather, and traffic conditions.',
      },
      {
        'icon': Icons.replay_rounded,
        'title': '5. Cancellations & Refunds',
        'subtitle': 'Orders once placed cannot be cancelled. Refunds are issued only in eligible cases as per our Refund Policy.',
        'fullText': 'Because restaurant partners begin food preparation immediately upon order confirmation, placed orders cannot be cancelled. In cases of missing items or damaged packages, refunds are credited to K9 Wallet within 24 hours.',
      },
      {
        'icon': Icons.shield_outlined,
        'title': '6. User Responsibilities',
        'subtitle': 'You are responsible for providing accurate information and maintaining the confidentiality of your account.',
        'fullText': 'You must maintain accurate delivery addresses, valid phone numbers, and secure OTP access credentials. K9 is not responsible for misdeliveries caused by incorrect address coordinates.',
      },
      {
        'icon': Icons.block_rounded,
        'title': '7. Prohibited Activities',
        'subtitle': 'You agree not to misuse the app, interfere with its performance, or engage in any fraudulent activity.',
        'fullText': 'Any attempt to reverse engineer app APIs, exploit promo code vulnerabilities, harass delivery partners, or create fake accounts will lead to permanent IP and account suspension.',
      },
      {
        'icon': Icons.info_outline_rounded,
        'title': '8. Changes to Terms',
        'subtitle': 'We may update these terms at any time. Changes will be posted on this page with the updated date.',
        'fullText': 'K9 reserves the right to modify service fees, delivery charges, or operating guidelines at any time. Continued usage constitutes binding acceptance of modified terms.',
      },
      {
        'icon': Icons.gavel_rounded,
        'title': '9. Governing Law',
        'subtitle': 'These terms are governed by the laws of India. Any disputes shall be subject to the jurisdiction of courts in India.',
        'fullText': 'These Terms and Conditions shall be interpreted under the laws of the Republic of India. Any legal proceedings or dispute arbitrations shall be held within competent courts in Indore, Madhya Pradesh.',
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(sections.length, (index) {
          final item = sections[index];
          final isLast = index == sections.length - 1;

          return InkWell(
            onTap: () => _showTermsDetailModal(
              context,
              item['title'] as String,
              item['subtitle'] as String,
              item['fullText'] as String,
            ),
            borderRadius: BorderRadius.vertical(
              top: index == 0 ? Radius.circular(16.r) : Radius.zero,
              bottom: isLast ? Radius.circular(16.r) : Radius.zero,
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF3E0),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: const Color(0xFFFF6D00),
                          size: 18.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: 3.h),
                            Text(
                              item['subtitle'] as String,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: secondaryTextColor,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                          size: 18.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 14.w,
                    endIndent: 14.w,
                    color: isDark ? AppColors.borderDark : const Color(0xFFF2F2F2),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// 3. Need Help? Contact Card (Phone & Email with dynamic actions)
  Widget _buildNeedHelpCard(
      BuildContext context, bool isDark, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF231A14) : const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF3D2B1F) : const Color(0xFFFFE5D0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFECE0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.headset_mic_rounded,
                  color: AppColors.primary,
                  size: 16.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Need Help?',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'If you have any questions, feel free to contact us.',
                    style: TextStyle(
                      fontSize: 10.5.sp,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 10.h),

          // Inner white card for Phone & Email
          Container(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 8.w),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Left Column: Phone
                Expanded(
                  child: InkWell(
                    onTap: () => _makePhoneCall(context, '9301988718'),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFECE0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.phone_in_talk_rounded,
                              color: AppColors.primary,
                              size: 14.sp,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Phone',
                                  style: TextStyle(
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  '9301988718',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  height: 32.h,
                  width: 1,
                  color: isDark ? AppColors.borderDark : const Color(0xFFEEEEEE),
                ),

                // Right Column: Email
                Expanded(
                  child: InkWell(
                    onTap: () => _sendEmail(context, 'tanuchouhan161@gmaim.com'),
                    borderRadius: BorderRadius.circular(8.r),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6.r),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFECE0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.mail_outline_rounded,
                              color: AppColors.primary,
                              size: 14.sp,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email',
                                  style: TextStyle(
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  'tanuchouhan161@gmaim.com',
                                  style: TextStyle(
                                    fontSize: 9.5.sp,
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
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
        ],
      ),
    );
  }
}
