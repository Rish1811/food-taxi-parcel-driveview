import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/modules/taxi/home/presentation/all_services_screen.dart';
import 'package:superapp_user/modules/taxi/home/presentation/confirm_booking_screen.dart';
import 'package:superapp_user/modules/taxi/home/presentation/finding_driver_screen.dart';
import 'package:superapp_user/modules/taxi/home/presentation/home_screen.dart';
import 'package:superapp_user/modules/taxi/home/presentation/map_picker_screen.dart';
import 'package:superapp_user/modules/taxi/home/presentation/no_driver_screen.dart';
import 'package:superapp_user/modules/taxi/home/presentation/promo_screen.dart';
import 'package:superapp_user/modules/taxi/home/presentation/ride_type_screen.dart';
import 'package:superapp_user/modules/taxi/home/presentation/saved_places_screen.dart';
import 'package:superapp_user/modules/taxi/home/presentation/search_destination_screen.dart';
import 'package:superapp_user/modules/taxi/ride/presentation/rating_review_screen.dart';
import 'package:superapp_user/modules/taxi/ride/presentation/ride_chat_screen.dart';
import 'package:superapp_user/modules/taxi/ride/presentation/ride_detail_screen.dart';
import 'package:superapp_user/modules/taxi/ride/presentation/ride_history_screen.dart';
import 'package:superapp_user/modules/taxi/ride/presentation/ride_tracking_screen.dart';
import 'package:superapp_user/app/shell/module_home_shell.dart';
import 'package:superapp_user/modules/module_id.dart';
import 'package:superapp_user/modules/taxi/notifications/presentation/notification_settings_screen.dart';
import 'package:superapp_user/modules/taxi/notifications/presentation/notifications_screen.dart';
import 'package:superapp_user/modules/taxi/profile/presentation/delete_account_screen.dart';
import 'package:superapp_user/modules/taxi/profile/presentation/edit_profile_screen.dart';
import 'package:superapp_user/modules/taxi/profile/presentation/emergency_contacts_screen.dart';
import 'package:superapp_user/modules/taxi/profile/presentation/language_screen.dart';
import 'package:superapp_user/modules/taxi/profile/presentation/theme_screen.dart';
import 'package:superapp_user/modules/taxi/rewards/presentation/rewards_screen.dart';
import 'package:superapp_user/modules/taxi/settings/presentation/security_screen.dart';
import 'package:superapp_user/modules/taxi/settings/presentation/settings_screen.dart';
import 'package:superapp_user/modules/taxi/subscription/presentation/subscription_screen.dart';
import 'package:superapp_user/modules/taxi/support/presentation/new_ticket_screen.dart';
import 'package:superapp_user/modules/taxi/support/presentation/safety_center_screen.dart';
import 'package:superapp_user/modules/taxi/support/presentation/sos_screen.dart';
import 'package:superapp_user/modules/taxi/support/presentation/support_home_screen.dart';
import 'package:superapp_user/modules/taxi/support/presentation/ticket_detail_screen.dart';
import 'package:superapp_user/modules/taxi/taxi_route_names.dart';

/// The taxi module's route subtree.
///
/// No bottom-nav shell, deliberately. Booking is a linear funnel over a map
/// (home → destination → vehicle → confirm → searching → tracking); a tab bar
/// mid-funnel is how a half-built booking gets lost. The stock taxi app put
/// `AppBottomNavigationBar` on these screens — that is not carried over.
List<RouteBase> taxiRoutes(GlobalKey<NavigatorState> rootNavigatorKey) => [
      GoRoute(
        name: TaxiRouteNames.home,
        path: TaxiRoutePaths.home,
        builder: (context, state) => const ModuleHomeShell(
          moduleId: ModuleId.taxi,
          child: TaxiHomeScreen(),
        ),
      ),
      GoRoute(
        name: TaxiRouteNames.destination,
        path: TaxiRoutePaths.destination,
        builder: (context, state) => const SearchDestinationScreen(),
      ),
      GoRoute(
        name: TaxiRouteNames.pickOnMap,
        path: TaxiRoutePaths.pickOnMap,
        builder: (context, state) => MapPickerScreen(
          type: state.uri.queryParameters['type'] ?? 'pickup',
        ),
      ),
      GoRoute(
        name: TaxiRouteNames.savedPlaces,
        path: TaxiRoutePaths.savedPlaces,
        builder: (context, state) => const SavedPlacesScreen(),
      ),
      GoRoute(
        name: TaxiRouteNames.vehicles,
        path: TaxiRoutePaths.vehicles,
        builder: (context, state) => const RideTypeScreen(),
      ),
      GoRoute(
        name: TaxiRouteNames.confirm,
        path: TaxiRoutePaths.confirm,
        builder: (context, state) => const ConfirmBookingScreen(),
      ),
      GoRoute(
        name: TaxiRouteNames.searching,
        path: TaxiRoutePaths.searching,
        builder: (context, state) => const FindingDriverScreen(),
      ),
      GoRoute(
        name: TaxiRouteNames.noDriver,
        path: TaxiRoutePaths.noDriver,
        builder: (context, state) => const NoDriverScreen(),
      ),
      GoRoute(
        name: TaxiRouteNames.promo,
        path: TaxiRoutePaths.promo,
        builder: (context, state) => const PromoScreen(),
      ),
      GoRoute(
        name: TaxiRouteNames.allServices,
        path: TaxiRoutePaths.allServices,
        builder: (context, state) => const AllServicesScreen(),
      ),
      GoRoute(
        name: TaxiRouteNames.rides,
        path: TaxiRoutePaths.rides,
        builder: (context, state) => const RideHistoryScreen(),
        routes: [
          // More specific children first so ':rideId' does not swallow them.
          GoRoute(
            name: TaxiRouteNames.rideTracking,
            path: ':rideId/track',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                RideTrackingScreen(rideId: state.pathParameters['rideId']!),
          ),
          GoRoute(
            name: TaxiRouteNames.rideRating,
            path: ':rideId/rate',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                RatingReviewScreen(rideId: state.pathParameters['rideId']!),
          ),
          GoRoute(
            name: TaxiRouteNames.rideChat,
            path: ':rideId/chat',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                RideChatScreen(rideId: state.pathParameters['rideId']!),
          ),
          GoRoute(
            name: TaxiRouteNames.rideDetail,
            path: ':rideId',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                RideDetailScreen(rideId: state.pathParameters['rideId']!),
          ),
        ],
      ),

      // ── ride-side screens with no shared counterpart yet ──────────────
      GoRoute(name: TaxiSubRouteNames.support, path: TaxiSubRoutePaths.support,
        builder: (c, s) => const SupportHomeScreen()),
      GoRoute(name: TaxiSubRouteNames.supportSafety, path: TaxiSubRoutePaths.supportSafety,
        builder: (c, s) => const SafetyCenterScreen()),
      GoRoute(name: TaxiSubRouteNames.supportNewTicket, path: TaxiSubRoutePaths.supportNewTicket,
        builder: (c, s) => const NewTicketScreen()),
      GoRoute(name: TaxiSubRouteNames.supportTicket, path: TaxiSubRoutePaths.supportTicket,
        builder: (c, s) => TicketDetailScreen(ticketCode: s.pathParameters['code']!)),
      GoRoute(name: TaxiSubRouteNames.sos, path: TaxiSubRoutePaths.sos,
        builder: (c, s) => SosScreen(rideId: s.uri.queryParameters['rideId'])),
      GoRoute(name: TaxiSubRouteNames.settings, path: TaxiSubRoutePaths.settings,
        builder: (c, s) => const SettingsScreen()),
      GoRoute(name: TaxiSubRouteNames.settingsSecurity, path: TaxiSubRoutePaths.settingsSecurity,
        builder: (c, s) => const SecurityScreen()),
      GoRoute(name: TaxiSubRouteNames.emergencyContacts, path: TaxiSubRoutePaths.emergencyContacts,
        builder: (c, s) => const EmergencyContactsScreen()),
      GoRoute(name: TaxiSubRouteNames.language, path: TaxiSubRoutePaths.language,
        builder: (c, s) => const LanguageScreen()),
      GoRoute(name: TaxiSubRouteNames.theme, path: TaxiSubRoutePaths.theme,
        builder: (c, s) => const ThemeScreen()),
      GoRoute(name: TaxiSubRouteNames.deleteAccount, path: TaxiSubRoutePaths.deleteAccount,
        builder: (c, s) => const DeleteAccountScreen()),
      GoRoute(name: TaxiSubRouteNames.editProfile, path: TaxiSubRoutePaths.editProfile,
        builder: (c, s) => const TaxiEditProfileScreen()),
      GoRoute(name: TaxiSubRouteNames.notifications, path: TaxiSubRoutePaths.notifications,
        builder: (c, s) => const TaxiNotificationsScreen()),
      GoRoute(name: TaxiSubRouteNames.notificationSettings, path: TaxiSubRoutePaths.notificationSettings,
        builder: (c, s) => const NotificationSettingsScreen()),
      GoRoute(name: TaxiSubRouteNames.subscription, path: TaxiSubRoutePaths.subscription,
        builder: (c, s) => const SubscriptionScreen()),
      GoRoute(name: TaxiSubRouteNames.rewards, path: TaxiSubRoutePaths.rewards,
        builder: (c, s) => const RewardsScreen()),
    ];
