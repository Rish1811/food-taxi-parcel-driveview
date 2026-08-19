/// Session and shared-feature routes.
///
/// Reading rule for the whole app: **a path with no module prefix is shared.**
/// `/wallet` means *the* wallet; `/food/orders` is food's. Anything under
/// `/food`, `/taxi`, `/parcel` or `/rental` belongs to that module and is
/// declared in its own `*_route_names.dart`.
class AppRoutePaths {
  const AppRoutePaths._();

  // Session
  static const String splash = '/';
  static const String hub = '/hub';

  // Auth
  static const String authPhone = '/auth/phone';
  static const String authOtp = '/auth/otp';
  static const String permissionLocation = '/auth/permissions/location';
  static const String permissionNotifications = '/auth/permissions/notifications';

  // Shared features
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String wallet = '/wallet';
  static const String notifications = '/notifications';
  static const String addresses = '/addresses';
  static const String search = '/search';
  static const String referral = '/referral';
  static const String referralTicket = '/referral/ticket';
  static const String support = '/support';
  static const String supportChat = '/support/chat';
  static const String settingsAbout = '/settings/about';
  static const String legalPrivacy = '/settings/legal/privacy';
  static const String legalTerms = '/settings/legal/terms';
  static const String webView = '/webview';
}

class AppRouteNames {
  const AppRouteNames._();

  static const String splash = 'splash';
  static const String hub = 'hub';

  static const String authPhone = 'auth.phone';
  static const String authOtp = 'auth.otp';
  static const String permissionLocation = 'auth.permissions.location';
  static const String permissionNotifications = 'auth.permissions.notifications';

  static const String profile = 'profile';
  static const String editProfile = 'profile.edit';
  static const String wallet = 'wallet';
  static const String notifications = 'notifications';
  static const String addresses = 'addresses';
  static const String search = 'search';
  static const String referral = 'referral';
  static const String referralTicket = 'referral.ticket';
  static const String support = 'support';
  static const String supportChat = 'support.chat';
  static const String settingsAbout = 'settings.about';
  static const String legalPrivacy = 'settings.legal.privacy';
  static const String legalTerms = 'settings.legal.terms';
  static const String webView = 'webview';
}
