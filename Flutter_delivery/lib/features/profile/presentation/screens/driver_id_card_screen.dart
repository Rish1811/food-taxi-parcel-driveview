import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/application/auth_state.dart';
import '../../../auth/data/models/delivery_partner.dart';

class DriverIdCardScreen extends ConsumerWidget {
  const DriverIdCardScreen({super.key});

  String _partnerId(DeliveryPartner? user) {
    final id = user?.id ?? '';
    if (id.isEmpty) return '—';
    if (id.length < 8) return 'DP-${id.toUpperCase()}';
    return 'DP-${id.substring(id.length - 8).toUpperCase()}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final bgColor = isDarkMode ? const Color(0xFF161925) : Colors.white;
    final authState = ref.watch(authControllerProvider);
    final user = authState is AuthAuthenticated ? authState.user : null;
    final vehicleLabel = [
      if (user?.vehicleType != null && user!.vehicleType!.isNotEmpty)
        user.vehicleType!.toUpperCase(),
      if (user?.vehicleNumber != null && user!.vehicleNumber!.isNotEmpty) user.vehicleNumber,
    ].join(' – ');

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Orange Header Background
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 360.h,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [theme.primaryColor, const Color(0xFFFF9853)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          // White Fade Overlay
          Positioned(
            top: 250.h,
            left: 0,
            right: 0,
            height: 110.h,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    bgColor.withOpacity(0.0),
                    bgColor,
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Close Button
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.only(right: 20.w, top: 10.h),
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.black, size: 24),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 20.h),

                // Profile Avatar / Graphic
                Container(
                  width: 140.r,
                  height: 140.r,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 70.r,
                    backgroundColor: Colors.white,
                    backgroundImage: user?.profilePhoto != null && user!.profilePhoto!.isNotEmpty
                        ? NetworkImage(AppConstants.resolveMediaUrl(user.profilePhoto))
                        : null,
                    child: user?.profilePhoto == null || user!.profilePhoto!.isEmpty
                        ? Icon(Icons.person, color: theme.primaryColor, size: 60.sp)
                        : null,
                  ),
                ),

                SizedBox(height: 30.h),

                // Typography
                Text(
                  'SUVIO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'PARTNER',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 32.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'ID CARD',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                  ),
                ),

                SizedBox(height: 16.h),

                // Approved Badge
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: (user?.isApproved == true ? Colors.green : Colors.orange)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: (user?.isApproved == true ? Colors.green : Colors.orange)
                          .withOpacity(0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        user?.isApproved == true
                            ? Icons.check_circle_outline
                            : Icons.access_time,
                        color: user?.isApproved == true ? Colors.green : Colors.orange,
                        size: 16.sp,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        (user?.status ?? 'PENDING').toUpperCase(),
                        style: TextStyle(
                          color: user?.isApproved == true ? Colors.green : Colors.orange,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 30.h),

                // Details Cards
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      children: [
                        _buildDataCard(
                          title: user?.name ?? 'Delivery Partner',
                          subtitle: 'FULL NAME',
                          textColor: textColor,
                        ),
                        SizedBox(height: 12.h),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDataCard(
                                title: _partnerId(user),
                                subtitle: 'PARTNER ID',
                                textColor: textColor,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: _buildDataCard(
                                title: user?.phone ?? '—',
                                subtitle: 'MOBILE',
                                textColor: textColor,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 12.h),
                        _buildDataCard(
                          title: vehicleLabel.isNotEmpty ? vehicleLabel : 'Not set',
                          subtitle: 'REGISTERED VEHICLE',
                          textColor: textColor,
                        ),

                        SizedBox(height: 40.h),

                        // Footer Text
                        Text(
                          'THIS ID CARD IS ISSUED FOR ESSENTIAL DELIVERY\nSERVICES ONLY.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: 40.h),
                      ],
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

  Widget _buildDataCard({
    required String title,
    required String subtitle,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: Colors.grey[500],
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
