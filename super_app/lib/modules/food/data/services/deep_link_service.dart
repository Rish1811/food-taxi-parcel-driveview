import 'package:superapp_user/core/config/app_constants.dart';

/// Business logic and utility for product deep linking and sharing.
///
/// Follows Clean Architecture guidelines (Domain layer — framework independent).
class DeepLinkService {
  static const String appScheme = 'K9';

  /// The host shared links are built on.
  ///
  /// Shared links MUST be https, not the K9:// custom scheme. WhatsApp, SMS,
  /// Instagram and most other chat apps only turn http(s) URLs into tappable
  /// links — a K9:// URL is delivered as inert plain text, which is exactly
  /// what "the link isn't working" was. https also degrades usefully: a
  /// recipient without the app installed lands on the web page instead of an
  /// error, and the link previews with a title and image.
  ///
  /// Tracks the API host so a staging build shares staging links rather than
  /// silently pointing testers at production.
  static const String webHost = AppConstants.hostUrl;

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.k9bharat.user';
  static const String appStoreUrl =
      'https://apps.apple.com/app/K9/id123456789';

  /// Deep link to a single dish.
  ///
  /// The path and query deliberately mirror the app's existing `/food-detail`
  /// route, so an incoming link resolves through the same builder as in-app
  /// navigation with no separate parsing path to drift out of sync.
  static String generateProductDeepLink({
    required String productId,
    required String restaurantId,
  }) {
    final query = Uri(
      queryParameters: {
        'id': productId,
        if (restaurantId.isNotEmpty) 'restaurantId': restaurantId,
      },
    ).query;
    return '$webHost/food-detail?$query';
  }

  /// Deep link to a restaurant's page.
  static String generateRestaurantDeepLink({required String restaurantId}) {
    return '$webHost/restaurant-detail/$restaurantId';
  }

  /// Generates human-friendly share text containing product info and the deep link.
  ///
  /// The link goes last and on its own line: chat apps link-detect to the end of
  /// the token, so trailing punctuation or text gets swallowed into the URL and
  /// breaks it.
  static String generateProductShareText({
    required String productName,
    String? restaurantName,
    required String productId,
    required String restaurantId,
  }) {
    final link = generateProductDeepLink(
      productId: productId,
      restaurantId: restaurantId,
    );
    final prefix = (restaurantName != null && restaurantName.isNotEmpty)
        ? 'Check out "$productName" from $restaurantName on K9!'
        : 'Check out "$productName" on K9!';
    return '$prefix\n\nOrder now on K9:\n$link';
  }

  /// Generates human-friendly share text for a restaurant.
  static String generateRestaurantShareText({
    required String restaurantName,
    required String restaurantId,
    String? cuisines,
  }) {
    final link = generateRestaurantDeepLink(restaurantId: restaurantId);
    final descriptor = (cuisines != null && cuisines.isNotEmpty)
        ? '$restaurantName ($cuisines)'
        : restaurantName;
    return 'Check out $descriptor on K9!\n\nOrder now on K9:\n$link';
  }

  /// Parses a deep link Uri to extract product ID and restaurant ID.
  ///
  /// Accepts both the https form now shared and the legacy K9:// form, which
  /// links already sent out in the wild still use. In a custom-scheme URI the
  /// first segment lands in `host` rather than `path`, so both are checked.
  static ({String? productId, String? restaurantId}) parseDeepLink(Uri uri) {
    final path = uri.path;
    if (path == '/food' ||
        path == '/food-detail' ||
        uri.host == 'food' ||
        uri.host == 'food-detail') {
      final id = uri.queryParameters['id'] ?? uri.queryParameters['productId'];
      final rId =
          uri.queryParameters['restaurantId'] ?? uri.queryParameters['rId'];
      return (productId: id, restaurantId: rId);
    }
    return (productId: null, restaurantId: null);
  }

  /// Extracts a restaurant id from a restaurant deep link, or null.
  static String? parseRestaurantDeepLink(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length >= 2 && segments.first == 'restaurant-detail') {
      return segments[1].isEmpty ? null : segments[1];
    }
    // Custom-scheme form: K9://restaurant-detail/<id>
    if (uri.host == 'restaurant-detail' && segments.isNotEmpty) {
      return segments.first.isEmpty ? null : segments.first;
    }
    return null;
  }
}
