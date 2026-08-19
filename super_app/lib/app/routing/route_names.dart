import 'package:superapp_user/app/routing/app_route_names.dart';
import 'package:superapp_user/modules/food/food_route_names.dart';

/// Compatibility shim for the pre-namespacing route constants.
///
/// Around 110 call sites across the food module still refer to these. Rather
/// than rewriting all of them in the same change that introduced namespacing —
/// which would have made the diff unreviewable — the constants now simply
/// *point at* the new paths. Every existing `context.push(RouteNames.cart)`
/// lands on `/food/cart` with no redirect hop and no edit.
///
/// Migrate call sites to [AppRoutePaths] / [FoodRoutePaths] opportunistically,
/// then delete this file. The deprecation annotation counts them down for you.
@Deprecated('Use AppRoutePaths (shared) or FoodRoutePaths (food module).')
class RouteNames {
  const RouteNames._();

  // ── session ───────────────────────────────────────────────────────
  static const String splash = AppRoutePaths.splash;
  static const String hub = AppRoutePaths.hub;
  static const String login = AppRoutePaths.authPhone;
  static const String otp = AppRoutePaths.authOtp;

  /// Not yet routed — no onboarding screen exists in the merged app until
  /// taxi's lands in Phase 5.
  static const String onboarding = '/onboarding';
  static const String signup = AppRoutePaths.authPhone;
  static const String forgotPassword = AppRoutePaths.authPhone;

  // ── food module ───────────────────────────────────────────────────
  static const String home = FoodRoutePaths.home;
  static const String cart = FoodRoutePaths.cart;
  static const String store99 = FoodRoutePaths.store99;
  static const String profile = FoodRoutePaths.profile;
  static const String orders = FoodRoutePaths.orders;
  static const String favorites = FoodRoutePaths.favorites;
  static const String allOffers = FoodRoutePaths.offers;
  static const String buyAgain = FoodRoutePaths.reorder;
  static const String homeFilter = FoodRoutePaths.filter;

  /// Base paths. Call sites use these both bare (with `extra`) and with an id
  /// appended — both forms are routed. See `food_routes.dart`.
  static const String restaurantDetail = FoodRoutePaths.restaurantRoot;
  static const String foodDetail = FoodRoutePaths.dishRoot;

  static const String orderDetails = FoodRoutePaths.orderDetails;
  static const String orderTracking = FoodRoutePaths.orderTracking;
  static const String orderDelivered = FoodRoutePaths.orderDelivered;

  // ── shared ────────────────────────────────────────────────────────
  static const String search = AppRoutePaths.search;
  static const String wallet = AppRoutePaths.wallet;
  static const String notifications = AppRoutePaths.notifications;
  static const String addAddress = AppRoutePaths.addresses;
  static const String editProfile = AppRoutePaths.editProfile;
  static const String referral = AppRoutePaths.referral;
  static const String referralTicket = AppRoutePaths.referralTicket;
  static const String chat = AppRoutePaths.supportChat;
  static const String helpSupport = AppRoutePaths.support;
  static const String about = AppRoutePaths.settingsAbout;
  static const String privacyPolicy = AppRoutePaths.legalPrivacy;
  static const String termsConditions = AppRoutePaths.legalTerms;
  static const String webView = AppRoutePaths.webView;
}
