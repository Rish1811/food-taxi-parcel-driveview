import 'package:superapp_user/modules/taxi/taxi_constants.dart';

/// Endpoint paths only — host/base URL live in [TaxiConstants] (single source
/// of truth for environment config).
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = TaxiConstants.baseUrl;

  static const String socketUrl = TaxiConstants.socketUrl;

  // Auth
  static const String sendOtp = '/taxi/users/auth/send-otp';
  static const String verifyOtp = '/taxi/users/auth/verify-otp';
  static const String otpLogin = '/taxi/users/otp-login';
  static const String register = '/taxi/users/register';
  static const String signup = '/taxi/users/signup';
  static const String login = '/taxi/users/login';

  // Profile
  static const String me = '/taxi/users/me';
  static const String profileImage = '/taxi/users/profile-image';
  static const String deleteRequest = '/taxi/users/me/delete-request';

  // Bootstrap / catalog
  static const String bootstrap = '/taxi/users/bootstrap';
  static const String appModules = '/taxi/users/app-modules';
  static const String settings = '/taxi/users/settings'; // + '/$category'
  static const String intercityPackages = '/taxi/users/intercity-packages';
  static const String goodsTypes = '/taxi/users/goods-types';
  static const String vehicleTypes = '/taxi/users/vehicle-types';
  /// Vehicles offering a Safe Ride here, with the normal fare and the safe-ride fare.
  static const String safeRideVehicles = '/taxi/users/safe-ride/vehicles';
  /// Slim marker-art feed (id + icon_types + map_icon) used to draw vehicles
  /// on the map, instead of the ~7MB full catalog.
  static const String vehicleMapIcons = '/taxi/users/vehicle-map-icons';
  /// Admin-uploaded promo banners shown on the home screen.
  static const String banners = '/taxi/users/banners';
  static const String setPrices = '/taxi/users/set-prices';
  static const String zones = '/taxi/users/zones';
  static const String serviceLocations = '/taxi/users/service-locations';
  static const String serviceStores = '/taxi/users/service-stores';
  static const String rentalVehicles = '/taxi/users/rental-vehicles';

  // Notifications
  static const String notifications = '/taxi/users/notifications';

  // Wallet
  static const String wallet = '/taxi/users/wallet';
  static const String walletTopup = '/taxi/users/wallet/topup';
  static const String walletTransfer = '/taxi/users/wallet/transfer';
  static const String walletTransferDriver = '/taxi/users/wallet/transfer/driver';
  static const String walletRazorpayOrder = '/taxi/users/wallet/razorpay/order';
  static const String walletRazorpayVerify = '/taxi/users/wallet/razorpay/verify';
  static const String walletPhonepeOrder = '/taxi/users/wallet/phonepe/order';
  static const String walletPhonepeStatus = '/taxi/users/wallet/phonepe/status'; // + '/$merchantTransactionId'

  // Promo
  static const String promoValidate = '/taxi/promos/validate';
  static const String promoAvailable = '/taxi/promos/available';

  // Subscriptions
  static const String subscriptionPlans = '/taxi/users/subscriptions/plans';
  static const String mySubscriptions = '/taxi/users/subscriptions/me';
  static const String buySubscription = '/taxi/users/subscriptions/purchase';

  // Rides
  static const String rides = '/taxi/rides';
  static const String activeRide = '/taxi/rides/active/me';
  static const String availableDrivers = '/taxi/rides/available-drivers';
  static const String rideTipSettings = '/taxi/rides/app-settings/tip';

  // Rentals
  static const String rentalQuoteRequests = '/taxi/users/rental-quote-requests';
  static const String rentalBookings = '/taxi/users/rental-bookings';
  static const String activeRentalBooking = '/taxi/users/rental-bookings/active';
  static const String rentalAdvanceWallet = '/taxi/users/rental-advance/wallet';
  static const String rentalAdvanceRazorpayOrder = '/taxi/users/rental-advance/razorpay/order';
  static const String rentalAdvanceRazorpayVerify = '/taxi/users/rental-advance/razorpay/verify';
  static const String rentalAdvancePhonepeOrder = '/taxi/users/rental-advance/phonepe/order';
  static const String rentalAdvancePhonepeStatus = '/taxi/users/rental-advance/phonepe/status'; // + '/$merchantTransactionId'

  // Deliveries
  static const String deliveries = '/taxi/deliveries';

  // Bus
  static const String buses = '/taxi/users/buses'; // + '/routes', '/search', '/$id/seats'
  static const String busBookings = '/taxi/users/bus-bookings';
  static const String busBookingsOrder = '/taxi/users/bus-bookings/order';
  static const String busBookingsVerify = '/taxi/users/bus-bookings/verify';

  // Pooling
  static const String pooling = '/taxi/users/pooling'; // + '/search', '/routes/$id'
  static const String poolingBookings = '/taxi/users/pooling/bookings';
  static const String poolingBookingsOrder = '/taxi/users/pooling/bookings/order';
  static const String poolingBookingsVerify = '/taxi/users/pooling/bookings/verify';

  // Sos
  static const String sos = '/taxi/users/sos';

  // Support
  static const String supportTitles = '/taxi/support/titles';
  static const String supportTickets = '/taxi/support/tickets';
  static const String myTickets = '/taxi/support/tickets/my';

  // Common
  static const String uploadImage = '/taxi/common/upload/image';
  static const String paymentGateway = '/taxi/common/payment-gateway';
  static const String referralsTranslation = '/taxi/common/referrals/translation';
  static const String referralsSettings = '/taxi/common/referrals/settings';
}
