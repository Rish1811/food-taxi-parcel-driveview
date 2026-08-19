import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBgColor = isDark ? TaxiColors.darkCard : Colors.white;
    // viewPadding always gives the real physical system inset (gesture bar /
    // 3-button nav) regardless of whether this widget is placed inside a
    // Scaffold.bottomNavigationBar or a Positioned Stack.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    // Clear the system gesture area without donating the whole inset to empty
    // colour. 3-button-nav devices report upwards of 48dp, which rendered as a
    // tall blank band under the labels; a gesture pill needs far less than
    // that. Still fully responsive — devices reporting 0 get 0.
    final safeBottom = bottomInset > 12 ? 12.0 : bottomInset;

    return Container(
      // Height grows: 60 for the bar content + the trimmed system inset.
      padding: EdgeInsets.only(bottom: safeBottom),
      decoration: BoxDecoration(
        color: navBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _BottomNavItem(
              icon: currentIndex == 0 ? Icons.home_rounded : Icons.home_outlined,
              label: 'Home',
              isActive: currentIndex == 0,
              onTap: () {
                if (currentIndex != 0) context.go('/taxi');
              },
            ),
            _BottomNavItem(
              icon: Icons.navigation_outlined,
              label: 'All Services',
              isActive: currentIndex == 1,
              onTap: () {
                if (currentIndex != 1) context.go('/taxi/services');
              },
            ),
            _BottomNavItem(
              icon: currentIndex == 2 ? Icons.access_time_rounded : Icons.access_time_outlined,
              label: 'History',
              isActive: currentIndex == 2,
              onTap: () {
                if (currentIndex != 2) context.go('/taxi/rides');
              },
            ),
          ],
        ),
      ),
    );
  }
}


class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = TaxiColors.primary; // Brand orange
    final inactiveColor = isDark ? TaxiColors.darkTextSecondary : const Color(0xFF94A3B8);
    final color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: () {
        Haptics.light();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
