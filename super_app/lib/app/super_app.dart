import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:superapp_user/design_system/theme/app_theme.dart';
import 'package:superapp_user/design_system/theme/theme_color_provider.dart';
import 'package:superapp_user/design_system/theme/theme_provider.dart';
import 'package:superapp_user/app/routing/app_router.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:superapp_user/core/push/push_providers.dart';
import 'package:superapp_user/core/push/push_service.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';

class SuperApp extends ConsumerStatefulWidget {
  const SuperApp({super.key});

  @override
  ConsumerState<SuperApp> createState() => _SuperAppState();
}

class _SuperAppState extends ConsumerState<SuperApp> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    // Push listeners are wired once for the app's lifetime. Deep links are
    // handed to the router rather than the service touching navigation itself.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final pushService = ref.read(pushServiceProvider);
      await pushService.initialize(
        onDeepLink: _handleDeepLink,
        onPermanentlyDenied: _showPermissionExplanationDialog,
      );

      final user = ref.read(authViewModelProvider).value;
      await pushService.performAppStartCheck(
        isLoggedIn: user != null,
        user: user,
      );
    });
  }

  void _showPermissionExplanationDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notifications Disabled'),
        content: const Text(
          'Notifications are required to receive real-time updates about your food orders (Order Accepted, Out for Delivery, Delivered, etc.). Please enable notifications in App Settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Later'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5700),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Routes an order push to the tracking screen.
  void _handleDeepLink(PushDeepLink link) {
    final orderId = link.trackableOrderId;
    if (!link.isOrderEvent || orderId == null || orderId.isEmpty) return;
    // Route is declared as /orders/track/:id — a path param, not a query.
    ref.read(routerProvider).push('/orders/track/$orderId');
  }

  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(routerProvider);

    // Register the device against the account on login; unregister on logout so
    // the next user of the device is not targeted.
    ref.listen(authViewModelProvider, (previous, next) {
      final was = previous?.value?.id;
      final now = next.value?.id;
      if (was == now && now != null) return;
      final push = ref.read(pushServiceProvider);
      if (now != null) {
        push.registerToken(user: next.value);
      } else if (previous?.value != null && now == null) {
        push.unregisterToken();
      }
    });

    // Rebuilds MaterialApp (and therefore every widget under it) whenever the
    // user picks a different app theme color — the single trigger that makes
    // the centralized ThemeColorNotifier's change reach the whole app.
    ref.watch(themeColorProvider);

    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp.router(
        title: 'K9',
        scaffoldMessengerKey: _scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: ref.watch(themeProvider),
        routerConfig: goRouter,
      ),
    );
  }
}

