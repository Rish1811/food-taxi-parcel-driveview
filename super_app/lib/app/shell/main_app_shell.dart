import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/modules/food/application/providers/socket_providers.dart';
import 'package:superapp_user/design_system/theme/theme_color_provider.dart';
import 'package:superapp_user/design_system/components/feedback/offline_banner.dart';
import 'package:superapp_user/modules/food/presentation/orders/viewmodels/active_order_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/orders/widgets/floating_active_order_card.dart';
import 'package:superapp_user/app/shell/widgets/custom_bottom_nav.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';
import 'package:superapp_user/app/routing/route_names.dart';

import 'package:flutter/services.dart';
import 'package:superapp_user/design_system/components/feedback/exit_confirmation_dialog.dart';

class MainAppShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainAppShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keeps the single app-wide socket connection alive for the whole
    // session (order tracking + chat both read it).
    ref.watch(socketConnectionProvider);
    // The bottom nav reads AppColors.primary directly (not Theme.of), so it
    // needs its own dependency on the color provider to repaint instantly —
    // this shell would otherwise only pick up a new theme color the next
    // time something else marks it dirty.
    ref.watch(themeColorProvider);
    final activeOrder = ref.watch(activeOrderViewModelProvider).activeOrder;

    final cartState = ref.watch(cartViewModelProvider);
    final hasCartItems = cartState.items.isNotEmpty;

    final router = GoRouter.of(context);

    final screensWithCartBar = {
      RouteNames.home,
      RouteNames.store99,
      RouteNames.restaurantDetail,
      RouteNames.foodDetail,
      RouteNames.allOffers,
    };

    return AnimatedBuilder(
      animation: router.routerDelegate,
      builder: (context, child) {
        final currentPath = router.routerDelegate.currentConfiguration.uri.path;
        final isCartBarVisible = hasCartItems && screensWithCartBar.contains(currentPath);
        final double bottomOffset = (currentPath == RouteNames.foodDetail) ? 120.0 : 24.0;
        
        final isHome = currentPath == RouteNames.home;
        final double targetBottom = isHome
            ? (isCartBarVisible ? (bottomOffset + 56.0 + 16.0) : 12.0)
            : -120.0;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (navigationShell.currentIndex != 0) {
              navigationShell.goBranch(0);
            } else {
              final shouldExit = await showExitConfirmationDialog(context);
              if (shouldExit == true) {
                SystemNavigator.pop();
              }
            }
          },
          child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              navigationShell,
              if (activeOrder != null)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: 16,
                  right: 16,
                  bottom: targetBottom,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    opacity: isHome ? 1.0 : 0.0,
                    child: IgnorePointer(
                      ignoring: !isHome,
                      child: FloatingActiveOrderCard(
                        order: activeOrder,
                        isCompact: isCartBarVisible,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OfflineBanner(),
              CustomBottomNav(
                currentIndex: navigationShell.currentIndex,
                onTap: (index) {
                  navigationShell.goBranch(
                    index,
                    initialLocation: index == navigationShell.currentIndex,
                  );
                },
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}
