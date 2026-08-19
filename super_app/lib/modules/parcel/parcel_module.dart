import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/core/config/backend_ids.dart';
import 'package:superapp_user/design_system/tokens/module_accent.dart';
import 'package:superapp_user/app/shell/module_home_shell.dart';
import 'package:superapp_user/modules/app_module.dart';
import 'package:superapp_user/modules/module_id.dart';
import 'package:superapp_user/modules/parcel/presentation/delivery_address_screen.dart';
import 'package:superapp_user/modules/parcel/presentation/delivery_category_vehicles_screen.dart';
import 'package:superapp_user/modules/parcel/presentation/delivery_vehicle_screen.dart';
import 'package:superapp_user/modules/parcel/presentation/finding_captain_screen.dart';
import 'package:superapp_user/modules/parcel/presentation/new_delivery_screen.dart';
import 'package:superapp_user/modules/parcel/presentation/parcel_home_screen.dart';

class ParcelRoutePaths {
  const ParcelRoutePaths._();

  static const String home = '/parcel';
  static const String vehicles = '/parcel/vehicles';
  static const String categoryVehicles = '/parcel/vehicles/:categoryId';
  static const String addresses = '/parcel/addresses';
  static const String searching = '/parcel/searching/:jobId';

  static String categoryOf(String id) => '/parcel/vehicles/$id';
  static String searchingFor(String jobId) => '/parcel/searching/$jobId';
}

class ParcelRouteNames {
  const ParcelRouteNames._();

  static const String home = 'parcel.home';
  static const String vehicles = 'parcel.vehicles';
  static const String categoryVehicles = 'parcel.vehicles.category';
  static const String addresses = 'parcel.addresses';
  static const String searching = 'parcel.searching';
}

/// Parcel delivery — send a package by bike, auto or truck.
///
/// Was `features/delivery` in the ride app. Renamed to "parcel" deliberately:
/// food already uses `delivery_*` for *food* delivery in its push payloads and
/// order states, and two different meanings of the same word across modules is
/// exactly the ambiguity the module discriminator exists to remove.
class ParcelModule extends AppModule {
  const ParcelModule();

  @override
  ModuleId get id => ModuleId.parcel;

  @override
  String get label => 'Parcel';

  @override
  String get tagline => 'Send anything';

  @override
  IconData get icon => Icons.inventory_2_rounded;

  @override
  ModuleAccent get accent => ModuleAccent.parcel;

  @override
  String get endpointId => BackendIds.k9;

  @override
  String get entryRoute => ParcelRoutePaths.home;

  @override
  int get order => 2;

  @override
  List<RouteBase> routes(GlobalKey<NavigatorState> rootNavigatorKey) => [
        GoRoute(
          name: ParcelRouteNames.home,
          path: ParcelRoutePaths.home,
          builder: (context, state) => const ModuleHomeShell(
            moduleId: ModuleId.parcel,
            child: ParcelHomeScreen(),
          ),
        ),
        GoRoute(
          name: 'parcel.new',
          path: '/parcel/new',
          builder: (context, state) => const NewDeliveryScreen(),
        ),
        GoRoute(
          name: ParcelRouteNames.vehicles,
          path: ParcelRoutePaths.vehicles,
          builder: (context, state) => const DeliveryVehicleScreen(),
          routes: [
            GoRoute(
              name: ParcelRouteNames.categoryVehicles,
              path: ':categoryId',
              parentNavigatorKey: rootNavigatorKey,
              builder: (context, state) => DeliveryCategoryVehiclesScreen(
                categoryId: state.pathParameters['categoryId']!,
              ),
            ),
          ],
        ),
        GoRoute(
          name: ParcelRouteNames.addresses,
          path: ParcelRoutePaths.addresses,
          builder: (context, state) => const DeliveryAddressScreen(),
        ),
        GoRoute(
          name: ParcelRouteNames.searching,
          path: ParcelRoutePaths.searching,
          builder: (context, state) =>
              FindingCaptainScreen(rideId: state.pathParameters['jobId']!),
        ),
      ];

  @override
  PushRoute? resolvePush(PushMessage message) {
    // Only claims messages explicitly addressed to parcel. Without the
    // backend's `data.module` field, matching on a `delivery_` type prefix
    // would steal food's delivery notifications — so this module stays silent
    // rather than guessing.
    if (message.module != ModuleId.parcel) return null;
    final jobId = message.string('jobId') ?? message.string('deliveryId');
    if (jobId == null) return null;
    return PushRoute(ParcelRoutePaths.searchingFor(jobId));
  }
}
