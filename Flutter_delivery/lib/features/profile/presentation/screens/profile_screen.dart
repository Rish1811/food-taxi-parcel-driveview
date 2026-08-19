import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/result.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../../auth/data/models/delivery_partner.dart';
import '../../../main/presentation/screens/main_screen.dart';
import '../../../profile/data/profile_repository.dart';
import '../../../wallet/data/wallet_repository.dart';
import '../../../../core/theme/theme_mode_provider.dart';
import 'delivery_readiness_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  int? _totalDeliveries;

  @override
  void initState() {
    super.initState();
    _loadTotalDeliveries();
  }

  Future<void> _loadTotalDeliveries() async {
    final result = await ref
        .read(walletRepositoryProvider)
        .getEarnings(period: 'all');
    if (!mounted) return;
    result.when(
      success: (data) {
        final summary = data['summary'] as Map<String, dynamic>? ?? data;
        setState(() {
          _totalDeliveries = (summary['totalOrders'] as num?)?.toInt();
        });
      },
      failure: (_) {},
    );
  }

  void _goToTab(int index) {
    ref.read(mainTabIndexProvider.notifier).setIndex(index);
    context.go('/main');
  }

  void _showSettingsSheet(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12.h),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.redAccent),
              title: const Text('Log Out'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await ref.read(authControllerProvider.notifier).logout();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete Account'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                _confirmDeleteAccount(context);
              },
            ),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final result = await ref
                  .read(profileRepositoryProvider)
                  .deleteAccount();
              if (!mounted) return;
              result.when(
                success: (_) => ref.read(authControllerProvider.notifier).logout(),
                failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message)),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showAppearanceSheet(BuildContext context) {
    final theme = Theme.of(context);
    final currentMode = ref.watch(themeModeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16.h),
              _buildAppearanceOption(
                sheetContext: sheetContext,
                title: 'System Default',
                icon: Icons.brightness_auto,
                value: ThemeMode.system,
                groupValue: currentMode,
              ),
              _buildAppearanceOption(
                sheetContext: sheetContext,
                title: 'Light',
                icon: Icons.light_mode,
                value: ThemeMode.light,
                groupValue: currentMode,
              ),
              _buildAppearanceOption(
                sheetContext: sheetContext,
                title: 'Dark',
                icon: Icons.dark_mode,
                value: ThemeMode.dark,
                groupValue: currentMode,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppearanceOption({
    required BuildContext sheetContext,
    required String title,
    required IconData icon,
    required ThemeMode value,
    required ThemeMode groupValue,
  }) {
    final isSelected = value == groupValue;
    final theme = Theme.of(sheetContext);
    
    return ListTile(
      leading: Icon(icon, color: isSelected ? theme.primaryColor : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? theme.primaryColor : null,
        ),
      ),
      trailing: isSelected 
          ? Icon(Icons.check_circle, color: theme.primaryColor)
          : const Icon(Icons.circle_outlined, color: Colors.grey),
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(value);
        Navigator.pop(sheetContext);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: theme.appBarTheme.iconTheme?.color,
          ),
          onPressed: () => ref.read(mainTabIndexProvider.notifier).setIndex(0),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.notifications_outlined,
              color: theme.appBarTheme.iconTheme?.color,
            ),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: theme.appBarTheme.iconTheme?.color,
            ),
            onPressed: () => _showSettingsSheet(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 4.h,
          bottom: 120.h,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeaderCard(context, theme, user),
            SizedBox(height: 20.h),
            _buildMenuCard(context, theme, textColor, subTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeaderCard(
    BuildContext context,
    ThemeData theme,
    DeliveryPartner? user,
  ) {
    final rating = user?.rating;
    final vehicleLabel = user?.vehicleName?.trim().isNotEmpty == true
        ? user!.vehicleName!
        : (user?.vehicleType ?? '');

    return GestureDetector(
      onTap: () {
        context.push('/driver-details');
      },
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.primaryColor, const Color(0xFFFF9853)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 34.r,
                  backgroundColor: Colors.white,
                  backgroundImage:
                      user?.profilePhoto != null && user!.profilePhoto!.isNotEmpty
                          ? NetworkImage(AppConstants.resolveMediaUrl(user.profilePhoto))
                          : null,
                  child: user?.profilePhoto == null || user!.profilePhoto!.isEmpty
                      ? Icon(Icons.person, color: theme.primaryColor, size: 32.sp)
                      : null,
                ),
                if (user?.isApproved == true)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      padding: EdgeInsets.all(3.r),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.verified,
                        color: theme.primaryColor,
                        size: 16.sp,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? 'Delivery Partner',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18.sp,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: Colors.white,
                        size: 16.sp,
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        rating != null 
                            ? '${rating.toStringAsFixed(1)}${user?.totalRatings != null && user!.totalRatings! > 0 ? ' (${user.totalRatings})' : ''}' 
                            : 'New',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.sp,
                        ),
                      ),
                      if (vehicleLabel.isNotEmpty) ...[
                        SizedBox(width: 12.w),
                        Icon(
                          Icons.two_wheeler_rounded,
                          color: Colors.white,
                          size: 16.sp,
                        ),
                        SizedBox(width: 2.w),
                        Flexible(
                          child: Text(
                            vehicleLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.sp,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          _totalDeliveries != null
                              ? '$_totalDeliveries Deliveries'
                              : '— Deliveries',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.sp,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'View Details',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 12.sp,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    ThemeData theme,
    Color textColor,
    Color? subTextColor,
  ) {
    final items = [
      (
        Icons.access_time_rounded,
        'Trips History',
        'View your all deliveries',
        () => _goToTab(2),
      ),
      (
        Icons.account_balance_wallet_outlined,
        'Earnings',
        'Track your earnings',
        () => _goToTab(1),
      ),
      (
        Icons.description_outlined,
        'Documents',
        'Manage your documents',
        () => context.push('/driver-details'),
      ),
      (
        Icons.two_wheeler_outlined,
        'Vehicle Details',
        'Manage your vehicle info',
        () => context.push('/driver-details'),
      ),
      (
        Icons.headset_mic_outlined,
        'Support',
        'Help & support center',
        () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support center coming soon')),
        ),
      ),
      (
        Icons.card_giftcard_outlined,
        'Refer & Earn',
        'Invite friends and earn more',
        () => context.push('/refer-earn'),
      ),
      (
        Icons.shield_moon_outlined,
        'Order delivery settings',
        'Make sure orders always reach you',
        () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DeliveryReadinessScreen()),
        ),
      ),
      (
        Icons.palette_outlined,
        'Appearance',
        'Light, dark, or system default',
        () => _showAppearanceSheet(context),
      ),
      (
        Icons.settings_outlined,
        'Settings',
        'App preferences',
        () => _showSettingsSheet(context),
      ),
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 4.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _buildMenuRow(
              theme: theme,
              textColor: textColor,
              subTextColor: subTextColor,
              icon: items[i].$1,
              title: items[i].$2,
              subtitle: items[i].$3,
              onTap: items[i].$4,
            ),
            if (i != items.length - 1)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: Divider(
                  height: 1,
                  color: (subTextColor ?? Colors.grey).withOpacity(0.15),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuRow({
    required ThemeData theme,
    required Color textColor,
    required Color? subTextColor,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(icon, color: Colors.green, size: 20.sp),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.sp,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.sp, color: subTextColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
