import 'package:superapp_user/core/config/api_config.dart';

/// A promotional banner shown in the home carousel, uploaded by an admin.
class PromoBannerModel {
  const PromoBannerModel({
    required this.id,
    required this.imageUrl,
    this.title = '',
    this.ctaLink = '',
  });

  final String id;
  final String imageUrl;
  final String title;

  /// Optional destination. Empty means the banner is decorative and should not
  /// react to taps at all — showing a pressed state for a banner that goes
  /// nowhere reads as a broken link.
  final String ctaLink;

  /// In-app routes a banner is allowed to open.
  ///
  /// Whitelisted rather than pushed blindly because the router has no
  /// errorBuilder: an unknown path shows go_router's raw "page not found"
  /// screen. Admins type these by hand, and some existing banners point at web
  /// paths (/food/user/offers) that only exist on the website — those must be
  /// inert, not a broken screen.
  static const _appRoutePrefixes = <String>{
    '/home',
    '/search',
    '/cart',
    '/orders',
    '/all-offers',
    '/store-99',
    '/favorites',
    '/wallet',
    '/referral',
    '/refer-earn',
    '/restaurant-detail',
    '/food-detail',
    '/notifications',
    '/buy-again',
  };

  /// Where a tap should go, or null when the banner is decorative.
  ///
  /// Returns the link itself for a valid in-app route, or an http(s) URL to be
  /// opened externally. Anything else resolves to null so the banner simply
  /// does not respond.
  String? get destination {
    final link = ctaLink.trim();
    if (link.isEmpty) return null;

    if (link.startsWith('/')) {
      final matches = _appRoutePrefixes.any(
        (p) => link == p || link.startsWith('$p/') || link.startsWith('$p?'),
      );
      return matches ? link : null;
    }

    final uri = Uri.tryParse(link);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return link;
    }
    return null;
  }

  bool get isTappable => destination != null;

  factory PromoBannerModel.fromApi(Map<String, dynamic> json) {
    return PromoBannerModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      // Stored as `imageUrl` on this model, unlike dishes which use `image`.
      // resolveMedia handles both absolute URLs and upload-relative paths.
      imageUrl: ApiConfig.resolveMedia(
        (json['imageUrl'] ?? json['image']) as String?,
      ),
      title: (json['title'] ?? '').toString(),
      ctaLink: (json['ctaLink'] ?? '').toString(),
    );
  }
}
