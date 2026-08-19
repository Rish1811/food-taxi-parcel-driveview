import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/features/splash/presentation/screens/splash_screen.dart';
import 'package:food_user_application/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:food_user_application/features/main/presentation/screens/main_screen.dart';
import 'package:food_user_application/features/profile/presentation/screens/driver_details_screen.dart';
import 'package:food_user_application/features/profile/presentation/screens/driver_id_card_screen.dart';
import 'package:food_user_application/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:food_user_application/features/refer_earn/presentation/screens/refer_earn_screen.dart';
import 'package:food_user_application/features/refer_earn/presentation/screens/referral_ticket_result_screen.dart';
import 'package:food_user_application/features/store99/presentation/screens/store99_screen.dart';
import 'package:food_user_application/features/restaurant/presentation/screens/restaurant_screen.dart';
import 'package:food_user_application/features/auth/presentation/screens/phone_login_screen.dart';
import 'package:food_user_application/features/auth/presentation/screens/otp_verify_screen.dart';
import 'package:food_user_application/features/auth/presentation/screens/registration_screen.dart';
import 'package:food_user_application/features/auth/presentation/screens/account_status_screen.dart';
import 'package:food_user_application/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:food_user_application/features/history/presentation/screens/trip_detail_screen.dart';
import 'package:food_user_application/features/rides/presentation/screens/active_ride_screen.dart';
import 'package:food_user_application/features/support/presentation/screens/help_screen.dart';
import 'package:food_user_application/features/support/presentation/screens/chat_admin_screen.dart';
import 'package:food_user_application/features/support/presentation/screens/support_ticket_screen.dart';
import 'router_notifier.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ref.watch(routerNotifierProvider);
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: true,
    refreshListenable: routerNotifier,
    redirect: routerNotifier.redirect,
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(path: '/main', builder: (context, state) => const MainScreen()),
      GoRoute(
        path: '/driver-details',
        builder: (context, state) => const DriverDetailsScreen(),
      ),
      GoRoute(
        path: '/driver-id-card',
        builder: (context, state) => const DriverIdCardScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/refer-earn',
        builder: (context, state) => const ReferEarnScreen(),
        routes: [
          GoRoute(
            path: 'ticket',
            builder: (context, state) => const ReferralTicketResultScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/store99',
        builder: (context, state) => const Store99Screen(),
      ),
      GoRoute(
        path: '/restaurant',
        builder: (context, state) => const RestaurantScreen(),
      ),
      GoRoute(
        path: '/phone-login',
        builder: (context, state) => const PhoneLoginScreen(),
      ),
      GoRoute(
        path: '/otp-verify',
        builder: (context, state) =>
            OtpVerifyScreen(phone: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) =>
            RegistrationScreen(phone: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/account-status',
        builder: (context, state) => const AccountStatusScreen(),
      ),
      // The trip screen is normally stacked over everything by main.dart, so
      // this route exists only for deep links — an FCM tap on a ride
      // notification — and reads the same controller either way.
      GoRoute(
        path: '/active-ride',
        builder: (context, state) => const ActiveRideScreen(),
      ),
      GoRoute(
        path: '/order-details',
        builder: (context, state) => const OrderDetailScreen(),
      ),
      GoRoute(
        path: '/trip-details',
        builder: (context, state) => TripDetailScreen(
          trip: state.extra as Map<String, dynamic>? ?? const {},
        ),
      ),
      GoRoute(
        path: '/help',
        builder: (context, state) => const HelpScreen(),
        routes: [
          GoRoute(
            path: 'chat',
            builder: (context, state) => const ChatAdminScreen(),
          ),
          GoRoute(
            path: 'ticket',
            builder: (context, state) => const SupportTicketScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) =>
        Scaffold(body: Center(child: Text('Route not found: ${state.error}'))),
  );
});
