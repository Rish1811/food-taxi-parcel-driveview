import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
          'About Us',
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

              SizedBox(height: 14.h),

              // 2. METRICS STATS BAR (1000+ Restaurants, 500K+ Users, etc.)
              _buildMetricsBar(isDark, textColor, secondaryTextColor),

              SizedBox(height: 14.h),

              // 3. OUR MISSION & OUR VISION (2 Side-by-Side Cards)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildMissionCard(isDark, textColor, secondaryTextColor)),
                  SizedBox(width: 12.w),
                  Expanded(child: _buildVisionCard(isDark, textColor, secondaryTextColor)),
                ],
              ),

              SizedBox(height: 20.h),

              // 4. WHY CHOOSE SUVIO? SECTION
              _buildSectionTitle('Why Choose K9?', isDark),
              SizedBox(height: 12.h),
              _buildWhyChooseUsCard(isDark, textColor, secondaryTextColor),

              SizedBox(height: 16.h),

              // 5. COMPANY DETAILS LIST TILE CARD
              _buildCompanyInfoCard(context, isDark, textColor, secondaryTextColor),

              SizedBox(height: 16.h),

              // 6. THANK YOU BANNER CARD
              _buildThankYouCard(isDark, textColor, secondaryTextColor),

              SizedBox(height: 20.h),

              // 7. FOOTER & CLOSE BUTTON
              Column(
                children: [
                  Text(
                    'Version 1.2.0',
                    style: TextStyle(
                      fontSize: 11.5.sp,
                      color: secondaryTextColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    '© 2026 K9. All Rights Reserved.',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: secondaryTextColor,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Fresh Food. Fast Delivery. Anytime.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(Icons.favorite_rounded, color: AppColors.primary, size: 14.sp),
                    ],
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

  /// 1. Hero Card: K9 Logo + Subtitle + Headline + Description + 3D Illustration
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
          // Left Content Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Logo & Category Subtitle
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'K9',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Container(
                      padding: EdgeInsets.all(3.r),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: Colors.white,
                        size: 10.sp,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Food & Drink',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 3.h),
                Container(
                  width: 32.w,
                  height: 2.5.h,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),

                SizedBox(height: 12.h),

                // Headline
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                    children: [
                      TextSpan(
                        text: 'Good Food. Great Moments.\n',
                        style: TextStyle(color: textColor),
                      ),
                      TextSpan(
                        text: 'Delivered to You.',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8.h),

                // Description
                Text(
                  'K9 is your trusted multi-service platform, connecting you with the best restaurants, rides and services. Fresh meals, quick delivery and delightful experiences – all at your fingertips.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    height: 1.35,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 12.w),

          // Right 3D Illustration Asset
          SizedBox(
            width: 135.w,
            height: 150.h,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Image.asset(
                'assets/images/about_hero.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.fastfood_rounded, color: AppColors.primary, size: 48.sp),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 2. Metrics Bar: 1000+ Restaurants | 500K+ Happy Users | Fast Delivery | Secure Payments | Best Offers
  Widget _buildMetricsBar(bool isDark, Color textColor, Color secondaryTextColor) {
    final metrics = [
      {'icon': Icons.storefront_rounded, 'stat': '1000+', 'label': 'Restaurants'},
      {'icon': Icons.groups_rounded, 'stat': '500K+', 'label': 'Happy Users'},
      {'icon': Icons.two_wheeler_rounded, 'stat': 'Fast', 'label': 'Delivery'},
      {'icon': Icons.shield_outlined, 'stat': 'Secure', 'label': 'Payments'},
      {'icon': Icons.percent_rounded, 'stat': 'Best', 'label': 'Offers'},
    ];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(metrics.length, (index) {
          final m = metrics[index];
          final showDivider = index < metrics.length - 1;

          return Expanded(
            child: Container(
              decoration: showDivider
                  ? BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: isDark ? AppColors.borderDark : const Color(0xFFF0F0F0),
                          width: 1,
                        ),
                      ),
                    )
                  : null,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(7.r),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      m['icon'] as IconData,
                      color: AppColors.primary,
                      size: 16.sp,
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    m['stat'] as String,
                    style: TextStyle(
                      fontSize: 12.5.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    m['label'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 3. Our Mission Card (Orange Tinted with Bullseye Icon)
  Widget _buildMissionCard(bool isDark, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: EdgeInsets.all(14.r),
      constraints: BoxConstraints(minHeight: 165.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF261D18) : const Color(0xFFFFF8F2),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF4A3428) : const Color(0xFFFFE8D6),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF3D271B) : const Color(0xFFFFECE0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.track_changes_rounded,
                  color: AppColors.primary,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Our Mission',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Container(
                      width: 20.w,
                      height: 2.h,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'To make food ordering effortless by delivering quality meals quickly, safely and affordably through smart technology and excellent service.',
            style: TextStyle(
              fontSize: 11.sp,
              height: 1.35,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 3. Our Vision Card (Green Tinted with Eye Icon)
  Widget _buildVisionCard(bool isDark, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: EdgeInsets.all(14.r),
      constraints: BoxConstraints(minHeight: 165.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14241B) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF1C422C) : const Color(0xFFDCFCE7),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1B3B29) : const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.visibility_outlined,
                  color: const Color(0xFF16A34A),
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Our Vision',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Container(
                      width: 20.w,
                      height: 2.h,
                      color: const Color(0xFF16A34A),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Text(
            'To become the most trusted Food & Drink platform, connecting millions of customers with the best local restaurants and creating memorable food experiences.',
            style: TextStyle(
              fontSize: 11.sp,
              height: 1.35,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  /// 4. Section Title Header with Flanking Lines
  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 24.w,
          height: 2.h,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(1.r),
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
        ),
        SizedBox(width: 10.w),
        Container(
          width: 24.w,
          height: 2.h,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(1.r),
          ),
        ),
      ],
    );
  }

  /// 4. Why Choose K9 Card (6 Features Grid)
  Widget _buildWhyChooseUsCard(bool isDark, Color textColor, Color secondaryTextColor) {
    final features = [
      {
        'icon': Icons.lunch_dining_rounded,
        'title': 'Wide Variety',
        'desc': 'Explore diverse restaurants and cuisines.',
      },
      {
        'icon': Icons.electric_bolt_rounded,
        'title': 'Fast Delivery',
        'desc': 'Quick and reliable delivery at your doorstep.',
      },
      {
        'icon': Icons.location_on_rounded,
        'title': 'Live Tracking',
        'desc': 'Track your order in real-time.',
      },
      {
        'icon': Icons.credit_card_rounded,
        'title': 'Secure Payments',
        'desc': 'Multiple secure payment options.',
      },
      {
        'icon': Icons.card_giftcard_rounded,
        'title': 'Exciting Offers',
        'desc': 'Enjoy exclusive deals and discounts.',
      },
      {
        'icon': Icons.thumb_up_alt_rounded,
        'title': 'Easy to Use',
        'desc': 'Simple, smooth and modern experience.',
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 6.w),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = constraints.maxWidth / 6;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(features.length, (index) {
              final f = features[index];
              final showDivider = index < features.length - 1;

              return SizedBox(
                width: itemWidth,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                  decoration: showDivider
                      ? BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: isDark ? AppColors.borderDark : const Color(0xFFF0F0F0),
                              width: 1,
                            ),
                          ),
                        )
                      : null,
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(7.r),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          f['icon'] as IconData,
                          color: AppColors.primary,
                          size: 15.sp,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        f['title'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        f['desc'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9.sp,
                          height: 1.2,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  /// 5. Company Info Card: Company Name, Category, Website, Email, Support
  Widget _buildCompanyInfoCard(
      BuildContext context, bool isDark, Color textColor, Color secondaryTextColor) {
    final items = [
      {'icon': Icons.label_outlined, 'title': 'Company Name', 'value': 'K9', 'isLink': false},
      {'icon': Icons.grid_view_rounded, 'title': 'Category', 'value': 'Super App', 'isLink': false},
      {
        'icon': Icons.language_rounded,
        'title': 'Website',
        'value': 'www.K9.com',
        'isLink': true,
        'url': 'https://www.K9.com'
      },
      {
        'icon': Icons.email_outlined,
        'title': 'Email',
        'value': 'support@K9.com',
        'isLink': false,
        'url': 'mailto:support@K9.com'
      },
      {
        'icon': Icons.phone_outlined,
        'title': 'Customer Support',
        'value': '+91 98765 43210',
        'isLink': false,
        'url': 'tel:+919876543210'
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
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;

          return InkWell(
            onTap: item['url'] != null ? () => _launchUrl(item['url'] as String) : null,
            borderRadius: BorderRadius.vertical(
              top: index == 0 ? Radius.circular(16.r) : Radius.zero,
              bottom: isLast ? Radius.circular(16.r) : Radius.zero,
            ),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  child: Row(
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: AppColors.primary,
                        size: 18.sp,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        item['title'] as String,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item['value'] as String,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                          color: item['isLink'] == true ? AppColors.primary : secondaryTextColor,
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark ? AppColors.borderDark : const Color(0xFFCCCCCC),
                        size: 16.sp,
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

  /// 6. Thank You Banner Card: Heart Icon + Message + Food Bowl Illustration
  Widget _buildThankYouCard(bool isDark, Color textColor, Color secondaryTextColor) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: isDark
              ? [
                  const Color(0xFF231A14),
                  const Color(0xFF1F1A16),
                ]
              : [
                  const Color(0xFFFFFBF0),
                  const Color(0xFFFFF4E5),
                ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? const Color(0xFF3D2B1F) : const Color(0xFFFFE6CC),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.favorite_rounded,
              color: const Color(0xFFFF3B30),
              size: 18.sp,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Thank you for being a part of K9!',
                  style: TextStyle(
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'We are grateful for your trust and support.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          SizedBox(
            width: 80.w,
            height: 55.h,
            child: Image.asset(
              'assets/images/about_thank_you_food.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.local_dining_rounded,
                color: AppColors.primary,
                size: 32.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
