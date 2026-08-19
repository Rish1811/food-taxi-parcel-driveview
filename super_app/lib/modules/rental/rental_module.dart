import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/core/config/backend_ids.dart';
import 'package:superapp_user/design_system/tokens/module_accent.dart';
import 'package:superapp_user/modules/app_module.dart';
import 'package:superapp_user/modules/module_id.dart';
import 'package:superapp_user/modules/rental/data/models/rental_vehicle_model.dart';
import 'package:superapp_user/modules/rental/presentation/rental_booking_screen.dart';
import 'package:superapp_user/modules/rental/presentation/rental_vehicles_screen.dart';

class RentalRoutePaths {
  const RentalRoutePaths._();

  static const String home = '/rental';
  static const String book = '/rental/vehicles/:vehicleId/book';

  static String bookVehicle(String id) => '/rental/vehicles/$id/book';
}

class RentalRouteNames {
  const RentalRouteNames._();

  static const String home = 'rental.home';
  static const String book = 'rental.book';
}

/// Vehicle rental — self-drive and chauffeur packages.
class RentalModule extends AppModule {
  const RentalModule();

  @override
  ModuleId get id => ModuleId.rental;

  @override
  String get label => 'Rentals';

  @override
  String get tagline => 'Rent a vehicle';

  @override
  IconData get icon => Icons.car_rental_rounded;

  @override
  ModuleAccent get accent => ModuleAccent.rental;

  @override
  String get endpointId => BackendIds.k9;

  @override
  String get entryRoute => RentalRoutePaths.home;

  @override
  int get order => 3;

  /// Off until k9 serves the rental routes.
  ///
  /// Every one of them is commented out in
  /// `modules/taxi/user/routes/userRoutes.js` — catalogue, quote requests,
  /// bookings, active booking, end-ride, location updates and all three
  /// advance-payment paths. Verified live: `/taxi/users/rental-vehicles`,
  /// `/rental-bookings` and `/rental-quote-requests` all return 404.
  ///
  /// The screens are ported and ready, so this is a one-line flip once the
  /// backend uncomments them. Shipping the tile now would advertise a service
  /// whose every screen can only render an error.
  @override
  bool get isEnabled => false;

  @override
  List<RouteBase> routes(GlobalKey<NavigatorState> rootNavigatorKey) => [
        GoRoute(
          name: RentalRouteNames.home,
          path: RentalRoutePaths.home,
          builder: (context, state) => const RentalVehiclesScreen(),
        ),
        GoRoute(
          name: RentalRouteNames.book,
          path: RentalRoutePaths.book,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            // The original route did `state.extra as RentalVehicleModel`
            // unconditionally, which throws on any cold entry — a push, a
            // shared link, or a process restart. Falling back to the list is
            // not ideal, but it is not a crash; a loader screen that fetches
            // the vehicle by id is the proper fix once the endpoint is wired.
            final vehicle = state.extra;
            if (vehicle is RentalVehicleModel) {
              return RentalBookingScreen(vehicle: vehicle);
            }
            return const RentalVehiclesScreen();
          },
        ),
      ];

  @override
  PushRoute? resolvePush(PushMessage message) {
    if (message.module != ModuleId.rental) return null;
    return const PushRoute(RentalRoutePaths.home);
  }
}
