import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/services/haptic_service.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Use opposite theme for background: white for dark mode, dark for light mode
    final bgColor = isDarkMode ? Colors.white : const Color(0xFF161925); // backgroundDark equivalent
    final unselectedColor = isDarkMode ? const Color(0xFF161925) : Colors.white;

    return Container(
      // margin and padding to float and align items
      margin: EdgeInsets.only(left: 24.w, right: 24.w, bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(40.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(
            context: context,
            icon: Icons.home_outlined,
            activeIcon: Icons.home_filled,
            label: 'Home',
            index: 0,
            unselectedColor: unselectedColor,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.account_balance_wallet,
            activeIcon: Icons.account_balance_wallet,
            label: 'Wallet',
            index: 1,
            unselectedColor: unselectedColor,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.receipt_long,
            activeIcon: Icons.receipt_long,
            label: 'History',
            index: 2,
            unselectedColor: unselectedColor,
          ),
          _buildNavItem(
            context: context,
            icon: Icons.person,
            activeIcon: Icons.person,
            label: 'Profile',
            index: 3,
            unselectedColor: unselectedColor,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required Color unselectedColor,
  }) {
    final isActive = currentIndex == index;
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () {
        if (!isActive) {
          HapticService.light(); // Changed to heavy() for maximum strength
        }
        onTap(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,  
        width: isActive ? 52.w : 53.w,
        height: 53.h, 
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? primaryColor : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? Colors.white : unselectedColor,
              size: isActive ? 24.sp : 24.sp,
            ),
            if (!isActive) ...[
              SizedBox(height: 4.h), 
              Text(
                label,
                style: TextStyle(
                  color: unselectedColor,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
