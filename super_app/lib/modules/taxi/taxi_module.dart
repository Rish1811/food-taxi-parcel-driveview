import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/core/config/backend_ids.dart';
import 'package:superapp_user/design_system/tokens/module_accent.dart';
import 'package:superapp_user/modules/app_module.dart';
import 'package:superapp_user/modules/module_id.dart';
import 'package:superapp_user/modules/taxi/taxi_route_names.dart';
import 'package:superapp_user/modules/taxi/taxi_routes.dart';

/// Ride booking: destination search, vehicle selection, dispatch, live
/// tracking, rating and history.
class TaxiModule extends AppModule {
  const TaxiModule();

  @override
  ModuleId get id => ModuleId.taxi;

  @override
  String get label => 'Rides';

  @override
  String get tagline => 'Book a ride';

  @override
  IconData get icon => Icons.local_taxi_rounded;

  @override
  ModuleAccent get accent => ModuleAccent.taxi;

  @override
  String get endpointId => BackendIds.k9;

  @override
  String get entryRoute => TaxiRoutePaths.home;

  @override
  int get order => 1;

  @override
  List<RouteBase> routes(GlobalKey<NavigatorState> rootNavigatorKey) =>
      taxiRoutes(rootNavigatorKey);

  /// Ride-lifecycle pushes.
  ///
  /// `no_drivers_found` deliberately does not open a tracking screen: the
  /// search was cancelled, so there is no trip to track. It goes somewhere the
  /// rider can actually rebook — a subtlety worth preserving from the original
  /// taxi app, which had a comment explaining exactly this.
  @override
  PushRoute? resolvePush(PushMessage message) {
    if (message.module != null && message.module != ModuleId.taxi) return null;

    final type = message.type;
    final rideId = message.string('rideId') ?? message.string('jobId');

    if (type == 'no_drivers_found' || type == 'rideRequestClosed') {
      return const PushRoute(TaxiRoutePaths.noDriver, replace: true);
    }

    final isRideEvent = type.startsWith('ride') ||
        type == 'driver_arrived' ||
        type == 'trip_started';
    if (!isRideEvent || rideId == null) return null;

    return switch (type) {
      'rideCompleted' || 'ride_completed' =>
        PushRoute(TaxiRoutePaths.rateRide(rideId)),
      _ => PushRoute(TaxiRoutePaths.trackRide(rideId)),
    };
  }
}
