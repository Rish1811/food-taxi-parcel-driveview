/// Central catalog of backend API paths (relative to [AppConstants.baseUrl]).
class ApiEndpoints {
  ApiEndpoints._();

  // Auth
  static const String requestOtp = '/food/auth/delivery/request-otp';
  static const String verifyOtp = '/food/auth/delivery/verify-otp';
  static const String refreshToken = '/food/auth/refresh-token';
  static const String logout = '/food/auth/logout';
  static const String me = '/food/auth/me';

  // Registration & profile
  static const String register = '/food/delivery/register';
  static String checkVehicle(String number) =>
      '/food/delivery/check-vehicle/$number';
  static const String profile = '/food/delivery/profile';
  static const String profileDetails = '/food/delivery/profile/details';
  static const String profilePhotoBase64 =
      '/food/delivery/profile/photo-base64';
  static const String profileBankDetails =
      '/food/delivery/profile/bank-details';
  static const String deleteAccount = '/food/delivery/profile/account';
  static const String reverify = '/food/delivery/reverify';

  // Availability
  static const String availability = '/food/delivery/availability';

  // Orders
  static const String ordersAvailable = '/food/delivery/orders/available';
  static const String ordersCurrent = '/food/delivery/orders/current';
  static String orderDetails(String orderId) =>
      '/food/delivery/orders/$orderId';
  static String orderAccept(String orderId) =>
      '/food/delivery/orders/$orderId/accept';
  static String orderReject(String orderId) =>
      '/food/delivery/orders/$orderId/reject';
  static String orderReachedPickup(String orderId) =>
      '/food/delivery/orders/$orderId/reached-pickup';
  static String orderConfirmPickup(String orderId) =>
      '/food/delivery/orders/$orderId/confirm-pickup';
  static String orderReachedDrop(String orderId) =>
      '/food/delivery/orders/$orderId/reached-drop';
  static String orderVerifyDropOtp(String orderId) =>
      '/food/delivery/orders/$orderId/verify-drop-otp';
  static String orderComplete(String orderId) =>
      '/food/delivery/orders/$orderId/complete';
  static String orderStatus(String orderId) =>
      '/food/delivery/orders/$orderId/status';
  static String orderRoute(String orderId) =>
      '/food/delivery/orders/$orderId/route';
  static String orderRateCustomer(String orderId) =>
      '/food/delivery/orders/$orderId/rate-customer';

  // Payment collection
  static String collectQr(String orderId) =>
      '/food/delivery/orders/$orderId/collect/qr';
  static String paymentStatus(String orderId) =>
      '/food/delivery/orders/$orderId/payment-status';
  static String collectCash(String orderId) =>
      '/food/delivery/orders/$orderId/collect/cash';

  // Wallet
  static const String wallet = '/food/delivery/wallet';
  static const String walletWithdraw = '/food/delivery/wallet/withdraw';
  static const String walletDepositOrder =
      '/food/delivery/wallet/deposit/order';
  static const String walletDepositVerify =
      '/food/delivery/wallet/deposit/verify';

  // Earnings / trips / settings
  static const String earnings = '/food/delivery/earnings';
  static const String tripHistory = '/food/delivery/trip-history';
  static const String pocketDetails = '/food/delivery/pocket-details';
  static const String earningAddonsActive =
      '/food/delivery/earning-addons/active';
  static const String cashLimit = '/food/delivery/cash-limit';
  static const String emergencyHelp = '/food/delivery/emergency-help';
  static const String referralStats = '/food/delivery/referrals/stats';

  // Support tickets
  static const String supportTickets = '/food/delivery/support-tickets';
  static String supportTicketDetails(String id) =>
      '/food/delivery/support-tickets/$id';

  // Emergency order reassignment
  static const String emergencyRequests =
      '/food/delivery/order-emergency-requests';
  static String emergencyRequestDetails(String id) =>
      '/food/delivery/order-emergency-requests/$id';

  // Chat
  static const String chatMessages = '/food/chat/messages';
  static const String chatConversations = '/food/chat/conversations';
  static String chatConversationRead(String conversationId) =>
      '/food/chat/conversations/$conversationId/read';

  // Push notifications
  static const String fcmTokenSaveMobile = '/fcm-tokens/mobile/save';
  static const String fcmTokenRemove = '/fcm-tokens/remove';
  static const String notificationsInbox = '/food/notifications/inbox';
  static String notificationRead(String id) =>
      '/food/notifications/$id/read';
  static String notificationDelete(String id) => '/food/notifications/$id';
  static const String notificationsDeleteAll =
      '/food/notifications/inbox/all';
// ── Taxi (ride) side ────────────────────────────────────────────────
  // The rider/driver taxi tree lives under /taxi on k9, separate from the
  // /food/delivery endpoints above. A driver authenticates once; the same
  // bearer works against both trees.

  /// PATCH — `{ workMode: "all" | "taxi" | "delivery" }`.
  ///
  /// Guarded server-side by the driver's `serviceCapabilities`, so a driver who
  /// is not registered for taxi cannot select it — the UI must surface that
  /// rejection rather than assume the switch took effect.
  static const String workMode = '/taxi/drivers/work-mode';

  /// PATCH — `{ location: [lng, lat], selfieImageUrl? }`.
  ///
  /// Sets `isOnline` on the **taxi driver** document, which is what dispatch
  /// and ride-acceptance both filter on. The food `/availability` call does not
  /// touch it: a driver who only calls that one is online for food and
  /// invisible to taxi. A selfie is required once per calendar day.
  static const String driverOnline = '/taxi/drivers/online';
  static const String driverOffline = '/taxi/drivers/offline';
  static const String driverMe = '/taxi/drivers/me';

  /// Multipart `file` (+ optional `folder`), returns `{ data: { url } }`.
  static const String uploadImage = '/uploads/image';

  /// The driver's in-progress ride, if any. This is what makes an active trip
  /// survive an app kill — the socket alone cannot replay a missed event.
  static const String rideActive = '/taxi/rides/active/me';
  static const String rides = '/taxi/rides';
  static String rideById(String rideId) => '/taxi/rides/$rideId';

  /// PATCH — `{ status: accepted | arriving | arrived | started | completed }`,
  /// plus optional fare/payment fields on completion.
  static String rideStatus(String rideId) => '/taxi/rides/$rideId/status';
  static String rideCancel(String rideId) =>
      '/taxi/drivers/rides/$rideId/cancel';
}
