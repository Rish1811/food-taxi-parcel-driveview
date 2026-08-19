import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
      queryParameters: {'subject': 'Privacy Policy Inquiry - K9 App'},
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

  void _showPolicyDetailModal(BuildContext context, String title, String description, String fullText) {
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
                description,
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
          'Privacy Policy',
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

              // 2. POLICY SECTIONS LIST CARD (8 Items matching screenshot)
              _buildPolicySectionsCard(context, isDark, textColor, secondaryTextColor),

              SizedBox(height: 16.h),

              // 3. CONTACT INFO CARD (Phone & Email with dynamic actions)
              _buildContactCard(context, isDark, textColor, secondaryTextColor),

              SizedBox(height: 16.h),

              // 4. FOOTER & CLOSE BUTTON
              Column(
                children: [
                  Text(
                    '© 2026 K9. All rights reserved.',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    'Your privacy is our priority.',
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

  /// 1. Hero Card: Headline + Description + 3D Shield Illustration
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
                        text: 'Your Privacy\n',
                        style: TextStyle(color: AppColors.primary),
                      ),
                      TextSpan(
                        text: 'Matters',
                        style: TextStyle(color: textColor),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  'At K9, we are committed to protecting your personal information and ensuring a safe and secure experience.',
                  style: TextStyle(
                    fontSize: 11.5.sp,
                    color: secondaryTextColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          SizedBox(
            width: 130.w,
            height: 125.h,
            child: Image.asset(
              'assets/images/privacy_shield.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.shield_rounded,
                color: AppColors.primary,
                size: 64.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Policy Sections List Card (8 Items)
  Widget _buildPolicySectionsCard(
      BuildContext context, bool isDark, Color textColor, Color secondaryTextColor) {
    final sections = [
      {
        'icon': Icons.person_outline_rounded,
        'title': '1. Information We Collect',
        'subtitle': 'We collect information you provide when you use our app, such as name, email, phone number, address, and payment details.',
        'fullText': 'We collect personal details essential to fulfilling your orders securely. This includes phone verification data, delivery coordinates, food preferences, and transaction receipts. We do not store sensitive payment card credentials on our servers.',
      },
      {
        'icon': Icons.shield_outlined,
        'title': '2. How We Use Your Information',
        'subtitle': 'We use your information to provide and improve our services, process orders, communicate updates, and ensure your security.',
        'fullText': 'Your data powers order dispatching, driver route optimization, real-time order tracking, and customer support resolution. We also send transactional SMS and push notifications for active order status updates.',
      },
      {
        'icon': Icons.groups_outlined,
        'title': '3. Information Sharing',
        'subtitle': 'We do not sell your personal information. We may share it with trusted partners for order delivery, payments, and legal compliance.',
        'fullText': 'Strictly necessary order details (such as recipient name, delivery address, and contact number) are shared with restaurant partners and delivery riders to complete fulfillment.',
      },
      {
        'icon': Icons.lock_outline_rounded,
        'title': '4. Data Security',
        'subtitle': 'We use industry-standard security measures to protect your information from unauthorized access, loss, or misuse.',
        'fullText': 'All communications with K9 servers are encrypted via SSL/TLS. Account authentication uses secure OTP tokens, preventing password leakage.',
      },
      {
        'icon': Icons.cookie_outlined,
        'title': '5. Cookies',
        'subtitle': 'We use cookies and similar technologies to enhance your experience and analyze app usage.',
        'fullText': 'We store local device preferences (e.g. dark theme choices, veg mode toggles, and recent search histories) to ensure a seamless app experience.',
      },
      {
        'icon': Icons.description_outlined,
        'title': '6. Your Rights',
        'subtitle': 'You have the right to access, update, or delete your personal data. You can manage your preferences in the app settings.',
        'fullText': 'You may update your profile details or request account data erasure anytime through the profile settings or by contacting support.',
      },
      {
        'icon': Icons.info_outline_rounded,
        'title': '7. Changes to This Policy',
        'subtitle': 'We may update this Privacy Policy from time to time. Changes will be posted on this page with the updated date.',
        'fullText': 'Any policy modifications will be published directly within the app. Continued use of K9 indicates acceptance of the updated terms.',
      },
      {
        'title': '8. Contact Data Protection Officer',
        'subtitle': 'Reach out for data deletion or privacy inquiries',
        'icon': Icons.security_outlined,
        'fullText': 'Our dedicated data protection team is available 24/7 to resolve any privacy queries at support@K9.com or via phone support.',
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
            onTap: () => _showPolicyDetailModal(
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

  /// 3. Contact Info Card: Phone & Email with dynamic actions
  Widget _buildContactCard(
      BuildContext context, bool isDark, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF231A14) : const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF3D2B1F) : const Color(0xFFFFE5D0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Left Column: Phone
          Expanded(
            child: InkWell(
              onTap: () => _makePhoneCall(context, '9301988718'),
              borderRadius: BorderRadius.circular(12.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(7.r),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFECE0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.phone_in_talk_rounded,
                        color: AppColors.primary,
                        size: 16.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phone',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '9301988718',
                            style: TextStyle(
                              fontSize: 10.5.sp,
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
            height: 36.h,
            width: 1,
            color: isDark ? const Color(0xFF3D2B1F) : const Color(0xFFFFE5D0),
          ),

          // Right Column: Email
          Expanded(
            child: InkWell(
              onTap: () => _sendEmail(context, 'tanuchouhan161@gmaim.com'),
              borderRadius: BorderRadius.circular(12.r),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 4.h),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(7.r),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFECE0),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mail_outline_rounded,
                        color: AppColors.primary,
                        size: 16.sp,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Email',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'tanuchouhan161@gmaim.com',
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
        ],
      ),
    );
  }
}
