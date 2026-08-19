/// Route names and paths for the taxi module.
///
/// Every path starts with `/taxi`. Before namespacing, taxi and food collided
/// on `/home`, `/search`, `/profile`, `/wallet`, `/notifications` and `/` —
/// whichever registered first would silently win.
class TaxiRoutePaths {
  const TaxiRoutePaths._();

  static const String home = '/taxi';
  static const String destination = '/taxi/destination';
  static const String pickOnMap = '/taxi/pick-on-map';
  static const String savedPlaces = '/taxi/saved-places';
  static const String vehicles = '/taxi/vehicles';
  static const String confirm = '/taxi/confirm';
  static const String searching = '/taxi/searching';
  static const String noDriver = '/taxi/no-driver';
  static const String promo = '/taxi/promo';
  static const String allServices = '/taxi/services';

  static const String rides = '/taxi/rides';
  static const String rideDetail = '/taxi/rides/:rideId';
  static const String rideTracking = '/taxi/rides/:rideId/track';
  static const String rideRating = '/taxi/rides/:rideId/rate';
  static const String rideChat = '/taxi/rides/:rideId/chat';

  static String rideOf(String id) => '/taxi/rides/$id';
  static String trackRide(String id) => '/taxi/rides/$id/track';
  static String rateRide(String id) => '/taxi/rides/$id/rate';
  static String chatForRide(String id) => '/taxi/rides/$id/chat';
}

class TaxiRouteNames {
  const TaxiRouteNames._();

  static const String home = 'taxi.home';
  static const String destination = 'taxi.destination';
  static const String pickOnMap = 'taxi.pickOnMap';
  static const String savedPlaces = 'taxi.savedPlaces';
  static const String vehicles = 'taxi.vehicles';
  static const String confirm = 'taxi.confirm';
  static const String searching = 'taxi.searching';
  static const String noDriver = 'taxi.noDriver';
  static const String promo = 'taxi.promo';
  static const String allServices = 'taxi.services';

  static const String rides = 'taxi.rides';
  static const String rideDetail = 'taxi.ride.detail';
  static const String rideTracking = 'taxi.ride.track';
  static const String rideRating = 'taxi.ride.rate';
  static const String rideChat = 'taxi.ride.chat';
}

/// Ride-side screens that have no shared counterpart yet.
///
/// These live under `/taxi/*` rather than at the top level because they are
/// *taxi's* implementations — its own support desk, its own settings, its own
/// notification inbox. Food has parallel versions of several. Promoting them to
/// shared routes is the shared-collapse work; pretending they are already
/// shared by giving them un-prefixed paths would be a lie the router enforces.
class TaxiSubRoutePaths {
  const TaxiSubRoutePaths._();

  static const String support = '/taxi/support';
  static const String supportSafety = '/taxi/support/safety';
  static const String supportNewTicket = '/taxi/support/tickets/new';
  static const String supportTicket = '/taxi/support/tickets/:code';
  static const String sos = '/taxi/sos';

  static const String settings = '/taxi/settings';
  static const String settingsSecurity = '/taxi/settings/security';

  static const String emergencyContacts = '/taxi/emergency-contacts';
  static const String language = '/taxi/language';
  static const String theme = '/taxi/theme';
  static const String deleteAccount = '/taxi/delete-account';
  static const String editProfile = '/taxi/profile/edit';

  static const String notifications = '/taxi/notifications';
  static const String notificationSettings = '/taxi/notifications/settings';

  static const String subscription = '/taxi/subscription';
  static const String rewards = '/taxi/rewards';

  static String ticketOf(String code) => '/taxi/support/tickets/$code';
  static String sosFor(String? rideId) =>
      rideId == null ? sos : '/taxi/sos?rideId=$rideId';
}

class TaxiSubRouteNames {
  const TaxiSubRouteNames._();

  static const String support = 'taxi.support';
  static const String supportSafety = 'taxi.support.safety';
  static const String supportNewTicket = 'taxi.support.ticket.new';
  static const String supportTicket = 'taxi.support.ticket';
  static const String sos = 'taxi.sos';
  static const String settings = 'taxi.settings';
  static const String settingsSecurity = 'taxi.settings.security';
  static const String emergencyContacts = 'taxi.emergencyContacts';
  static const String language = 'taxi.language';
  static const String theme = 'taxi.theme';
  static const String deleteAccount = 'taxi.deleteAccount';
  static const String editProfile = 'taxi.profile.edit';
  static const String notifications = 'taxi.notifications';
  static const String notificationSettings = 'taxi.notifications.settings';
  static const String subscription = 'taxi.subscription';
  static const String rewards = 'taxi.rewards';
}
