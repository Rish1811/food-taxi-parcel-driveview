import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/app/hub/hub_screen.dart';
import 'package:superapp_user/app/routing/app_route_names.dart';
import 'package:superapp_user/design_system/components/layout/webview_screen.dart';
import 'package:superapp_user/modules/food/food_route_names.dart';
import 'package:superapp_user/modules/module_registry.dart';
import 'package:superapp_user/shared/address/presentation/screens/add_address_screen.dart';
import 'package:superapp_user/shared/auth/presentation/screens/login_screen.dart';
import 'package:superapp_user/shared/auth/presentation/screens/otp_screen.dart';
import 'package:superapp_user/shared/notifications/presentation/notifications_screen.dart';
import 'package:superapp_user/shared/profile/presentation/screens/edit_profile_screen.dart';
import 'package:superapp_user/shared/profile/presentation/screens/help_support_screen.dart';
import 'package:superapp_user/shared/profile/presentation/screens/privacy_policy_screen.dart';
import 'package:superapp_user/shared/profile/presentation/screens/terms_conditions_screen.dart';
import 'package:superapp_user/shared/referral/presentation/screens/referral_screen.dart';
import 'package:superapp_user/shared/referral/presentation/screens/referral_ticket_result_screen.dart';
import 'package:superapp_user/shared/search/presentation/screens/search_screen.dart';
import 'package:superapp_user/shared/session/presentation/permissions/location_permission_screen.dart';
import 'package:superapp_user/shared/session/presentation/permissions/notification_permission_screen.dart';
import 'package:superapp_user/shared/session/presentation/splash/splash_screen.dart';
import 'package:superapp_user/shared/settings/presentation/about/screens/about_screen.dart';
import 'package:superapp_user/shared/support/presentation/chat/screens/chat_screen.dart';
import 'package:superapp_user/shared/wallet/presentation/screens/wallet_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app's router.
///
/// Module routes are **not** listed here — they come from
/// [ModuleRegistry.routes]. Adding a module never means editing this file,
/// which is the property the whole module architecture rests on.
final routerProvider = Provider<GoRouter>((ref) {
  final registry = ref.watch(moduleRegistryProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutePaths.splash,
    debugLogDiagnostics: false,
    routes: [
      ..._sessionRoutes(),
      ..._sharedRoutes(),

      // Every enabled module contributes its own namespaced subtree.
      ...registry.routes(rootNavigatorKey),

      // Paths from before namespacing. Links live in the wild (shared
      // restaurant links, and the backend still sends `link: '/food/user/
      // orders/<id>'` in push payloads), so these stay for at least two
      // release cycles. Five lines each, and the alternative is a dead link.
      ..._legacyRedirects(),
    ],
    errorBuilder: (context, state) => _NotFoundScreen(uri: state.uri),
  );
});

// ─────────────────────────────────────────────────────────── session

List<RouteBase> _sessionRoutes() => [
      GoRoute(
        name: AppRouteNames.splash,
        path: AppRoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        name: AppRouteNames.hub,
        path: AppRoutePaths.hub,
        builder: (context, state) => const HubScreen(),
      ),
      GoRoute(
        name: AppRouteNames.authPhone,
        path: AppRoutePaths.authPhone,
        builder: (context, state) {
          // `from` survives the auth flow so a guest who hits a gated screen
          // is returned to it afterwards instead of being dumped on the hub.
          final fromPath = state.uri.queryParameters['from'] ??
              (state.extra is String ? state.extra as String : null);
          return LoginScreen(fromPath: fromPath);
        },
      ),
      GoRoute(
        name: AppRouteNames.authOtp,
        path: AppRoutePaths.authOtp,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OtpScreen(
            phoneNumber: extra?['phone']?.toString() ??
                state.uri.queryParameters['phone'] ??
                '',
            devOtp: extra?['devOtp']?.toString(),
            fromPath:
                extra?['from']?.toString() ?? state.uri.queryParameters['from'],
          );
        },
      ),
      // Permission gates. Ported from the ride app -- food never asked
      // explicitly, it just fired the system prompt on first frame, which is
      // both worse UX and easy to permanently deny by accident.
      GoRoute(
        name: AppRouteNames.permissionLocation,
        path: AppRoutePaths.permissionLocation,
        builder: (context, state) => const LocationPermissionScreen(),
      ),
      GoRoute(
        name: AppRouteNames.permissionNotifications,
        path: AppRoutePaths.permissionNotifications,
        builder: (context, state) => const NotificationPermissionScreen(),
      ),
    ];

// ─────────────────────────────────────────────────────────── shared

List<RouteBase> _sharedRoutes() => [
      GoRoute(
        name: AppRouteNames.wallet,
        path: AppRoutePaths.wallet,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        name: AppRouteNames.notifications,
        path: AppRoutePaths.notifications,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        name: AppRouteNames.search,
        path: AppRoutePaths.search,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => SearchScreen(
          initialQuery: state.extra is String
              ? state.extra as String
              : state.uri.queryParameters['q'],
        ),
      ),
      GoRoute(
        name: AppRouteNames.addresses,
        path: AppRoutePaths.addresses,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AddAddressScreen(),
      ),
      GoRoute(
        name: AppRouteNames.editProfile,
        path: AppRoutePaths.editProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        name: AppRouteNames.referral,
        path: AppRoutePaths.referral,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReferralScreen(),
      ),
      GoRoute(
        name: AppRouteNames.referralTicket,
        path: AppRoutePaths.referralTicket,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ReferralTicketResultScreen(),
      ),
      GoRoute(
        name: AppRouteNames.support,
        path: AppRoutePaths.support,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HelpSupportScreen(),
      ),
      GoRoute(
        name: AppRouteNames.supportChat,
        path: AppRoutePaths.supportChat,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final args = state.extra as ChatArgs? ??
              const ChatArgs(orderId: '', peerName: 'Support', peerRole: 'ADMIN');
          return ChatScreen(args: args);
        },
      ),
      GoRoute(
        name: AppRouteNames.settingsAbout,
        path: AppRoutePaths.settingsAbout,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        name: AppRouteNames.legalPrivacy,
        path: AppRoutePaths.legalPrivacy,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PrivacyPolicyScreen(),
      ),
      GoRoute(
        name: AppRouteNames.legalTerms,
        path: AppRoutePaths.legalTerms,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TermsConditionsScreen(),
      ),
      GoRoute(
        name: AppRouteNames.webView,
        path: AppRoutePaths.webView,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return WebViewScreen(
            title: extra?['title']?.toString() ??
                state.uri.queryParameters['title'] ??
                'Web View',
            url: extra?['url']?.toString() ??
                state.uri.queryParameters['url'] ??
                '',
          );
        },
      ),
      // Profile currently lives inside the food shell so the 4-tab UX is
      // unchanged. Phase 7 makes it a real shared screen composed from module
      // ProfileSection contributions, at which point this redirect inverts.
      GoRoute(
        name: AppRouteNames.profile,
        path: AppRoutePaths.profile,
        redirect: (context, state) => FoodRoutePaths.profile,
      ),
    ];

// ────────────────────────────────────────────────── legacy redirects

List<RouteBase> _legacyRedirects() => [
      GoRoute(path: '/home', redirect: (c, s) => FoodRoutePaths.home),
      GoRoute(path: '/cart', redirect: (c, s) => FoodRoutePaths.cart),
      GoRoute(path: '/store-99', redirect: (c, s) => FoodRoutePaths.store99),
      GoRoute(path: '/orders', redirect: (c, s) => FoodRoutePaths.orders),
      GoRoute(path: '/favorites', redirect: (c, s) => FoodRoutePaths.favorites),
      GoRoute(path: '/all-offers', redirect: (c, s) => FoodRoutePaths.offers),
      GoRoute(path: '/login', redirect: (c, s) => _withQuery(AppRoutePaths.authPhone, s)),
      GoRoute(path: '/otp', redirect: (c, s) => _withQuery(AppRoutePaths.authOtp, s)),
      GoRoute(path: '/edit-profile', redirect: (c, s) => AppRoutePaths.editProfile),
      GoRoute(path: '/about', redirect: (c, s) => AppRoutePaths.settingsAbout),
      GoRoute(path: '/help-support', redirect: (c, s) => AppRoutePaths.support),
      GoRoute(path: '/privacy-policy', redirect: (c, s) => AppRoutePaths.legalPrivacy),
      GoRoute(path: '/terms-conditions', redirect: (c, s) => AppRoutePaths.legalTerms),
      GoRoute(path: '/chat', redirect: (c, s) => AppRoutePaths.supportChat),
      GoRoute(path: '/add-address', redirect: (c, s) => AppRoutePaths.addresses),
      GoRoute(path: '/refer-earn/ticket', redirect: (c, s) => AppRoutePaths.referralTicket),
      GoRoute(path: '/home-filter', redirect: (c, s) => FoodRoutePaths.filter),
      GoRoute(path: '/buy-again', redirect: (c, s) => FoodRoutePaths.reorder),

      GoRoute(
        path: '/restaurant-detail/:id',
        redirect: (c, s) =>
            FoodRoutePaths.restaurantOf(s.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/restaurant-detail',
        redirect: (c, s) {
          final id = s.uri.queryParameters['id'] ??
              s.uri.queryParameters['restaurantId'] ??
              '';
          return FoodRoutePaths.restaurantOf(id);
        },
      ),
      GoRoute(
        path: '/food-detail',
        redirect: (c, s) => FoodRoutePaths.dishOf(
          s.uri.queryParameters['id'] ?? s.uri.queryParameters['productId'] ?? '',
          restaurantId: s.uri.queryParameters['restaurantId'] ??
              s.uri.queryParameters['rId'],
        ),
      ),
      GoRoute(
        path: '/orders/details/:id',
        redirect: (c, s) => FoodRoutePaths.orderOf(s.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/orders/track/:id',
        redirect: (c, s) => FoodRoutePaths.trackOrder(s.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/orders/success/:id',
        redirect: (c, s) =>
            FoodRoutePaths.orderSuccessOf(s.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/orders/delivered/:id',
        redirect: (c, s) =>
            FoodRoutePaths.orderDeliveredOf(s.pathParameters['id'] ?? ''),
      ),
    ];

String _withQuery(String path, GoRouterState state) {
  final query = state.uri.query;
  return query.isEmpty ? path : '$path?$query';
}

// ───────────────────────────────────────────────────────────── 404

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({required this.uri});

  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.explore_off_rounded, size: 56),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                uri.toString(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppRoutePaths.hub),
                child: const Text('Go to home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
