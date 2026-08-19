import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/app/shell/main_app_shell.dart';
import 'package:superapp_user/app/shell/module_home_shell.dart';
import 'package:superapp_user/modules/module_id.dart';
import 'package:superapp_user/modules/food/data/models/cart_item_model.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/modules/food/food_route_names.dart';
import 'package:superapp_user/modules/food/presentation/cart/cart_screen.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/checkout/viewmodels/checkout_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/favorites/favorites_screen.dart';
import 'package:superapp_user/modules/food/presentation/home/home_screen.dart';
import 'package:superapp_user/modules/food/presentation/home/screens/home_filter_screen.dart';
import 'package:superapp_user/modules/food/presentation/offers/screens/all_offers_screen.dart';
import 'package:superapp_user/modules/food/presentation/orders/screens/order_delivered_screen.dart';
import 'package:superapp_user/modules/food/presentation/orders/screens/order_details_screen.dart';
import 'package:superapp_user/modules/food/presentation/orders/screens/order_success_screen.dart';
import 'package:superapp_user/modules/food/presentation/orders/screens/order_tracking_screen.dart';
import 'package:superapp_user/modules/food/presentation/orders/screens/orders_screen.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/screens/food_detail_loader_screen.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/screens/food_detail_screen.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/screens/restaurant_detail_loader_screen.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/screens/restaurant_screen.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/screens/store99_screen.dart';
import 'package:superapp_user/shared/profile/presentation/profile_screen.dart';

final _shellHomeKey = GlobalKey<NavigatorState>(debugLabel: 'foodShellHome');
final _shellCartKey = GlobalKey<NavigatorState>(debugLabel: 'foodShellCart');
final _shellStore99Key = GlobalKey<NavigatorState>(debugLabel: 'foodShellStore99');
final _shellProfileKey = GlobalKey<NavigatorState>(debugLabel: 'foodShellProfile');

/// The food module's route subtree.
///
/// Two conventions worth keeping when this file grows:
///  * routes that must cover the bottom-nav shell set
///    `parentNavigatorKey: rootNavigatorKey`
///  * every `:id` route falls back to a loader screen when `state.extra` is
///    absent, because a push notification, a shared link and a cold start all
///    arrive with no `extra`
List<RouteBase> foodRoutes(GlobalKey<NavigatorState> rootNavigatorKey) => [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainAppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellHomeKey,
            routes: [
              GoRoute(
                name: FoodRouteNames.home,
                path: FoodRoutePaths.home,
                builder: (context, state) => const ModuleHomeShell(
                  moduleId: ModuleId.food,
                  child: HomeScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellCartKey,
            routes: [
              GoRoute(
                name: FoodRouteNames.cart,
                path: FoodRoutePaths.cart,
                builder: (context, state) => const CartScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellStore99Key,
            routes: [
              GoRoute(
                name: FoodRouteNames.store99,
                path: FoodRoutePaths.store99,
                builder: (context, state) => const Store99Screen(),
              ),
            ],
          ),
          // Profile lives in the food shell for now so the existing 4-tab UX is
          // preserved exactly. Phase 7 promotes it to a genuinely shared screen
          // composed from each module's ProfileSection contributions; at that
          // point this branch and the /profile redirect both go away.
          StatefulShellBranch(
            navigatorKey: _shellProfileKey,
            routes: [
              GoRoute(
                name: FoodRouteNames.profile,
                path: FoodRoutePaths.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Two forms, exactly as the original router had: callers that already
      // hold the model push the id-less path with `extra` (warm, no refetch),
      // while shared links and pushes carry only an id. Dropping the id-less
      // form would silently break eight call sites.
      GoRoute(
        name: FoodRouteNames.restaurantRoot,
        path: FoodRoutePaths.restaurantRoot,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _restaurantScreen(
          state,
          state.uri.queryParameters['id'] ??
              state.uri.queryParameters['restaurantId'] ??
              '',
        ),
        routes: [
          GoRoute(
            name: FoodRouteNames.restaurant,
            path: ':id',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                _restaurantScreen(state, state.pathParameters['id'] ?? ''),
          ),
        ],
      ),

      GoRoute(
        name: FoodRouteNames.dishRoot,
        path: FoodRoutePaths.dishRoot,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _dishScreen(
          state,
          state.uri.queryParameters['id'] ??
              state.uri.queryParameters['productId'] ??
              '',
        ),
        routes: [
          GoRoute(
            name: FoodRouteNames.dish,
            path: ':id',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                _dishScreen(state, state.pathParameters['id'] ?? ''),
          ),
        ],
      ),

      GoRoute(
        name: FoodRouteNames.filter,
        path: FoodRoutePaths.filter,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          // Guarded: the original route cast `state.extra` unconditionally and
          // threw whenever this was reached without arguments.
          final args = state.extra;
          if (args is HomeFilterArgs) return HomeFilterScreen(args: args);
          return const HomeScreen();
        },
      ),

      GoRoute(
        name: FoodRouteNames.favorites,
        path: FoodRoutePaths.favorites,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const FavoritesScreen(),
      ),

      GoRoute(
        name: FoodRouteNames.offers,
        path: FoodRoutePaths.offers,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AllOffersScreen(),
      ),

      GoRoute(
        name: FoodRouteNames.orders,
        path: FoodRoutePaths.orders,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const OrdersScreen(),
        routes: [
          GoRoute(
            name: FoodRouteNames.orderTracking,
            path: ':id/track',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                OrderTrackingScreen(orderId: state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            name: FoodRouteNames.orderSuccess,
            path: ':id/success',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                OrderSuccessScreen(orderId: state.pathParameters['id'] ?? ''),
          ),
          GoRoute(
            name: FoodRouteNames.orderDelivered,
            path: ':id/delivered',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                OrderDeliveredScreen(orderId: state.pathParameters['id'] ?? ''),
          ),
          // Registered last so the more specific ':id/<verb>' routes above win.
          GoRoute(
            name: FoodRouteNames.orderDetails,
            path: ':id',
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) =>
                OrderDetailsScreen(orderId: state.pathParameters['id'] ?? ''),
          ),
        ],
      ),

      GoRoute(
        name: FoodRouteNames.reorder,
        path: FoodRoutePaths.reorder,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final items = state.extra;
          if (items is! List<CartItemModel>) return const CartScreen();
          // A scoped cart: pre-filled from a past order and deliberately not
          // synced to the server until the user commits.
          return ProviderScope(
            overrides: [
              cartViewModelProvider.overrideWith(
                () => CartViewModel(initialItems: items, syncEnabled: false),
              ),
              checkoutViewModelProvider.overrideWith(CheckoutViewModel.new),
            ],
            child: const CartScreen(),
          );
        },
      ),
    ];

/// Shared by the id-less and `:id` restaurant routes.
Widget _restaurantScreen(GoRouterState state, String fallbackId) {
  final restaurant =
      state.extra is RestaurantModel ? state.extra as RestaurantModel : null;
  if (restaurant != null) return RestaurantScreen(restaurant: restaurant);
  return RestaurantDetailLoaderScreen(restaurantId: fallbackId);
}

/// Shared by the id-less and `:id` dish routes.
Widget _dishScreen(GoRouterState state, String fallbackId) {
  final food = state.extra is FoodModel ? state.extra as FoodModel : null;
  if (food != null) return FoodDetailScreen(food: food);
  return FoodDetailLoaderScreen(
    foodId: fallbackId,
    restaurantId: state.uri.queryParameters['restaurantId'] ??
        state.uri.queryParameters['rId'] ??
        '',
  );
}
