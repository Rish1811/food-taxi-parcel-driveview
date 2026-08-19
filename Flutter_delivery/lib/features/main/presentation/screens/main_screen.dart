import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/features/feed/presentation/screens/feed_screen.dart';
import 'package:food_user_application/features/history/presentation/screens/history_screen.dart';
import 'package:food_user_application/features/pocket/presentation/screens/pocket_screen.dart';
import 'package:food_user_application/features/profile/presentation/screens/profile_screen.dart';
import '../widgets/custom_bottom_nav_bar.dart';

class MainTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) => state = index;
}

final mainTabIndexProvider = NotifierProvider<MainTabIndexNotifier, int>(
  MainTabIndexNotifier.new,
);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  static const _screens = [
    FeedScreen(),
    PocketScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  Future<bool?> _showExitAppDialog(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28.r)),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 8,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 24.h, 24.w, 20.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Warning Icon
              Container(
                padding: EdgeInsets.all(16.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE4E2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.power_settings_new_rounded,
                  color: const Color(0xFFF04438),
                  size: 32.sp,
                ),
              ),
              SizedBox(height: 16.h),

              // Title
              Text(
                'Exit App?',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20.sp,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              SizedBox(height: 8.h),

              // Description
              Text(
                'Are you sure you want to exit the delivery application?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  height: 1.4,
                ),
              ),
              SizedBox(height: 24.h),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48.h,
                      child: OutlinedButton(
                        onPressed: () {
                          HapticService.light();
                          Navigator.of(ctx).pop(false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDarkMode ? Colors.white24 : Colors.grey[300]!,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: SizedBox(
                      height: 48.h,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticService.medium();
                          Navigator.of(ctx).pop(true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF04438),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        child: Text(
                          'Exit',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(mainTabIndexProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (currentIndex != 0) {
          // If on Wallet, History, or Profile screen, navigate directly back to Home/Orders tab
          HapticService.light();
          ref.read(mainTabIndexProvider.notifier).setIndex(0);
        } else {
          // If already on Home/Orders tab, show Exit App confirmation popup
          final shouldExit = await _showExitAppDialog(context);
          if (shouldExit == true) {
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        // We use a Stack so the bottom nav bar floats over the map (FeedScreen)
        body: Stack(
          children: [
            // IndexedStack preserves the state of the screens (like map position).
            //
            // TickerMode round each child because IndexedStack keeps every tab
            // mounted AND ticking: the feed's pulse animation carried on
            // rebuilding its GoogleMap while the rider sat on Wallet or
            // History, burning frames on a screen nobody could see. Disabling
            // the ticker freezes animations without unmounting anything, so
            // map position and scroll offset are still preserved.
            IndexedStack(
              index: currentIndex,
              children: [
                for (var i = 0; i < _screens.length; i++)
                  TickerMode(enabled: i == currentIndex, child: _screens[i]),
              ],
            ),

            // Floating Custom Navigation Bar
            Positioned(
              bottom: 30, // Distance from the bottom
              left: 20,
              right: 20,
              child: CustomBottomNavBar(
                currentIndex: currentIndex,
                onTap: (index) => ref.read(mainTabIndexProvider.notifier).setIndex(index),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
