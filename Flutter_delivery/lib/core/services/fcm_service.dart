import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';
import '../network/api_endpoints.dart';
import '../network/dio_client.dart';
import '../storage/token_storage.dart';
import 'order_overlay_service.dart';

/// Dedicated channel for incoming-order alerts — separate from
/// [FcmService._channel] because it needs call-category / full-screen-intent
/// semantics that a plain order-status-update notification shouldn't have.
const _incomingOrdersChannel = AndroidNotificationChannel(
  'incoming_orders_channel_v4',
  'Incoming Orders',
  description: 'Full-screen incoming order alerts that require immediate action',
  importance: Importance.max,
  playSound: true,
);

/// Stable notification id for an order's incoming alert.
///
/// The alert used to be posted under `message.hashCode`, which is derived from the
/// push itself and is therefore unknowable to anything that later wants to take the
/// alert down. Keying on the order id means the withdrawal push can cancel exactly
/// the alert its order raised. Masked positive because Android ids are ints and a
/// negative one is not portable across the plugin.
int incomingOrderNotificationId(String orderId) => orderId.hashCode & 0x7fffffff;

String? _orderIdOf(Map<String, dynamic> data) {
  final id = (data['orderMongoId'] ?? data['orderId'] ?? data['_id'])?.toString();
  return (id == null || id.isEmpty) ? null : id;
}

/// Takes down the incoming-order alert for [orderId] wherever it is showing.
///
/// Safe to call from the background isolate, which is the case that matters: the
/// rider whose app is closed is the one the socket `order_claimed` event cannot
/// reach, so this is the only path that clears their screen.
Future<void> dismissIncomingOrderAlert(String orderId) async {
  await OrderOverlayService.closeForOrder(orderId);
  final localNotifications = FlutterLocalNotificationsPlugin();
  await localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    ),
    onDidReceiveBackgroundNotificationResponse: backgroundNotificationResponseHandler,
  );
  await localNotifications.cancel(incomingOrderNotificationId(orderId));
  await cancelFcmTrayCopy(orderId);
}

@pragma('vm:entry-point')
void backgroundNotificationResponseHandler(NotificationResponse response) async {
  final payload = response.payload;
  final actionId = response.actionId;

  if (actionId == 'accept' || actionId == 'reject') {
    final orderId = _orderIdOfPayload(payload);
    if (orderId != null) {
      await _respondToOrderFromBackground(orderId: orderId, accept: actionId == 'accept');
    }
  }
}

String? _orderIdOfPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map) {
      final id = (decoded['orderMongoId'] ?? decoded['orderId'] ?? decoded['_id'])?.toString();
      return (id == null || id.isEmpty) ? null : id;
    }
  } catch (_) {}
  return payload;
}

Future<void> _respondToOrderFromBackground({
  required String orderId,
  required bool accept,
}) async {
  try {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'access_token');
    if (token != null && token.isNotEmpty) {
      final dio = Dio(BaseOptions(
        baseUrl: AppConstants.baseUrl,
        headers: {'Authorization': 'Bearer $token'},
      ));
      await dio.patch(
        accept
            ? ApiEndpoints.orderAccept(orderId)
            : ApiEndpoints.orderReject(orderId),
      );
    }
  } catch (e) {
    print('[FCM Background Action] Error responding to order $orderId: $e');
  } finally {
    try {
      final localNotifications = FlutterLocalNotificationsPlugin();
      await localNotifications.cancel(incomingOrderNotificationId(orderId));
      await OrderOverlayService.closeForOrder(orderId);
    } catch (_) {}
  }
}

/// Removes the OS-rendered copy of the new-order push.
///
/// The push is hybrid: FCM posts a tray notification itself (tag `order_<id>`,
/// set by the backend — the two must stay in sync) so ROMs that refuse to start
/// the app in the background still ring. Wherever OUR alert does manage to show,
/// this takes the tray copy down so the rider sees one alert, not two. FCM posts
/// tagged notifications under id 0.
Future<void> cancelFcmTrayCopy(String orderId) async {
  try {
    await FlutterLocalNotificationsPlugin().cancel(0, tag: 'order_$orderId');
  } catch (_) {
    // Worst case the tray copy stays — a duplicate, not a lost order.
  }
}

/// Wakes the device for a ride offer that arrived while the app was closed.
///
/// Deliberately not the order overlay: the taxi push carries only
/// `{type, rideId, serviceType, userId}` — dispatch sends no fare, addresses or
/// distance — so there is nothing to render a rich bubble from. A full-screen
/// intent gets the driver into the app, where the offer is fetched in full.
///
/// The window is short (the server re-offers to the next driver in ~20s), hence
/// [timeoutAfter]: a stale ride alert left on the lock screen is worse than
/// none, because tapping it opens an offer that is already gone.
Future<void> _showRideRequestAlert(Map<String, dynamic> data) async {
  final rideId = (data['rideId'] ?? '')?.toString() ?? '';
  final isParcel = (data['serviceType'] ?? '').toString() == 'parcel';

  try {
    final localNotifications = FlutterLocalNotificationsPlugin();
    await localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
      onDidReceiveBackgroundNotificationResponse:
          backgroundNotificationResponseHandler,
    );
    await localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_incomingOrdersChannel);

    await localNotifications.show(
      incomingOrderNotificationId(rideId),
      isParcel ? 'New delivery request' : 'New ride request',
      'Tap to view the booking',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _incomingOrdersChannel.id,
          _incomingOrdersChannel.name,
          channelDescription: _incomingOrdersChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
          timeoutAfter: 30000,
          sound: const RawResourceAndroidNotificationSound('tujh_bin1'),
          playSound: true,
        ),
      ),
      payload: jsonEncode(data),
    );
  } catch (_) {
    // Nothing more is possible from a background isolate; the socket will
    // still deliver the offer if the app is brought to the front in time.
  }
}

/// Must stay top-level / static so the Dart VM can invoke it in the
/// background isolate when a push arrives while the app is killed.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  // Another rider accepted first — pull the alert down instead of leaving it
  // ringing until its own countdown expires.
  if (message.data['type'] == 'order_taken') {
    final orderId = _orderIdOf(message.data);
    if (orderId != null) await dismissIncomingOrderAlert(orderId);
    return;
  }

  if (message.data['type'] == 'ride_request') {
    await _showRideRequestAlert(message.data);
    return;
  }

  if (message.data['type'] != 'new_order') return;

  // If this handler is running at all, this device CAN show our own richer
  // alert — so take down the tray copy FCM just posted (the hybrid push exists
  // for ROMs where this handler never runs). Done first, so a throw later
  // can't leave both on screen.
  final incomingOrderId = _orderIdOf(message.data);
  if (incomingOrderId != null) await cancelFcmTrayCopy(incomingOrderId);

  // Try the overlay bubble first, but never trust it blindly — if the
  // permission check races with it being revoked, the plugin throws, or the
  // OEM ROM silently drops the overlay window, `showForOrder` now reports
  // that honestly instead of us assuming success. Whatever happens here,
  // the full-screen-intent notification below is the guaranteed fallback so
  // a delivered push is never left with nothing shown on screen.
  var overlayShown = false;
  try {
    if (await OrderOverlayService.hasPermission()) {
      overlayShown = await OrderOverlayService.showForOrder(message.data);
    }
  } catch (_) {
    overlayShown = false;
  }

  if (overlayShown) return;
  try {
    // A fresh isolate — the channel/plugin registered by FcmService.initialize()
    // in the main isolate doesn't exist here, so set both up again.
    final localNotifications = FlutterLocalNotificationsPlugin();
    await localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
      ),
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationResponseHandler,
    );
    await localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_incomingOrdersChannel);

    // Both key sets are live: dispatch sends restaurantAddress/customerAddress/
    // earnings/tripDistanceKm, while re-offer rounds still carry the older
    // pickupAddress/dropAddress/price/distance names. Reading only one set is
    // what left riders staring at "From: Restaurant  To: Customer  ₹".
    final pickup = message.data['restaurantAddress'] as String? ??
        message.data['pickupAddress'] as String? ??
        'Restaurant';
    final drop = message.data['customerAddress'] as String? ??
        message.data['dropAddress'] as String? ??
        'Customer';
    final price = message.data['earnings']?.toString() ??
        message.data['riderEarning']?.toString() ??
        message.data['price']?.toString() ??
        '';
    final distance = message.data['tripDistanceKm']?.toString() ??
        message.data['distance']?.toString() ??
        '';
    final body = 'From: $pickup\nTo: $drop\nEarnings: ₹$price | Dist: ${distance}km';

    await localNotifications.show(
      incomingOrderNotificationId(_orderIdOf(message.data) ?? ''),
      message.data['restaurantName'] as String? ?? 'New order',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _incomingOrdersChannel.id,
          _incomingOrdersChannel.name,
          channelDescription: _incomingOrdersChannel.description,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.call,
          fullScreenIntent: true,
          ongoing: true,
          // `ongoing` makes this undismissable by swipe, so it needs its own
          // expiry — otherwise a missed offer leaves a permanent notification
          // for an order that was reassigned 40 seconds ago.
          timeoutAfter: 45000,
          sound: const RawResourceAndroidNotificationSound('tujh_bin1'),
          playSound: true,
          styleInformation: BigTextStyleInformation(body),
          actions: <AndroidNotificationAction>[
            const AndroidNotificationAction(
              'accept',
              'Accept',
              showsUserInterface: true,
              cancelNotification: true,
            ),
            const AndroidNotificationAction(
              'reject',
              'Reject',
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: jsonEncode(message.data),
    );
  } catch (_) {
    // Last resort: the full-screen path itself failed (channel creation
    // race, plugin init error, etc.) — still surface a plain heads-up
    // notification with sound so the push isn't entirely invisible to the
    // rider instead of silently vanishing.
    try {
      await FlutterLocalNotificationsPlugin().show(
        message.hashCode,
        message.data['restaurantName'] as String? ?? 'New order',
        'Tap to view your new order',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _incomingOrdersChannel.id,
            _incomingOrdersChannel.name,
            channelDescription: _incomingOrdersChannel.description,
            importance: Importance.max,
            priority: Priority.high,
            sound: const RawResourceAndroidNotificationSound('tujh_bin1'),
            playSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    } catch (_) {
      // Genuinely nothing more we can do from a background isolate.
    }
  }
}

/// The backend's FCM_DEFAULT_CHANNEL_ID, used for every push that is NOT a
/// new-order alert (order status updates and the like).
///
/// Those arrive WITH a notification block, so the OS renders them against this id
/// directly. Android silently ignores an unknown channel id and drops back to a
/// low-importance default, so never creating this one left every status update
/// without a heads-up — indistinguishable from the push not arriving at all.
const _highImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'Order updates',
  description: 'Order status updates and alerts',
  importance: Importance.max,
);

class FcmService {
  FcmService(this._dio, this._tokenStorage);

  final Dio _dio;
  final TokenStorage _tokenStorage;

  final _localNotifications = FlutterLocalNotificationsPlugin();
  final _notificationTapController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationReceivedController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTapController.stream;
      
  Stream<Map<String, dynamic>> get onNotificationReceived =>
      _notificationReceivedController.stream;

  static const _channel = AndroidNotificationChannel(
    'orders_channel',
    'Order Updates',
    description: 'New order alerts and delivery status updates',
    importance: Importance.max,
  );

  Future<void> initialize() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosInit = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: backgroundNotificationResponseHandler,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_channel);
      await androidPlugin?.createNotificationChannel(_highImportanceChannel);
      await androidPlugin?.createNotificationChannel(_incomingOrdersChannel);
    }

    await ensureAndroidAlertPermissions();

    // Cold start via the full-screen-intent notification (lock screen /
    // killed app) — onDidReceiveNotificationResponse above isn't guaranteed
    // to fire for the launching notification itself, so check explicitly.
    final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
    final launchResponse = launchDetails?.notificationResponse;
    if ((launchDetails?.didNotificationLaunchApp ?? false) && launchResponse != null) {
      // Goes through the same path as a live tap so an Accept/Reject pressed on a
      // terminated app still performs the action rather than only opening the order.
      _handleNotificationResponse(launchResponse);
    }

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationOpen);

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _handleNotificationOpen(initialMessage);

    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
  }

  /// Re-checked on every cold start AND every app resume (see main.dart's
  /// `didChangeAppLifecycleState`), not just once at cold start.
  ///
  /// Android 14+ revokes USE_FULL_SCREEN_INTENT by default for apps without
  /// calling/alarm functionality, even though it's declared in the
  /// manifest — without this explicit grant, fullScreenIntent notifications
  /// silently downgrade to a normal heads-up banner on both the lock screen
  /// and home screen. `requestFullScreenIntentPermission()` no-ops (returns
  /// true) if already granted or on pre-Android-14 devices, so it's cheap
  /// to call repeatedly. Re-running it on resume also catches riders who
  /// dismissed the Settings prompt the first time, or who granted/revoked
  /// it manually from system Settings mid-session — a one-shot check at
  /// process init would otherwise miss both cases for the app's entire
  /// lifetime in memory.
  Future<void> ensureAndroidAlertPermissions() async {
    if (!Platform.isAndroid) return;

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestFullScreenIntentPermission();

    // Overlay bubble permission ("display over other apps") — powers the
    // floating home-screen bubble for new orders that arrive while the app
    // is backgrounded (see OrderOverlayService). Separate from the
    // full-screen-intent permission above, which only covers the locked-
    // device case.
    await OrderOverlayService.requestPermission();
  }

  /// Routes a notification interaction: an Accept/Reject action button, or a
  /// plain tap on the notification body.
  ///
  /// The action id was previously discarded, so both buttons did exactly the same
  /// thing as tapping the notification — open the order screen. They looked like
  /// Accept and Reject but neither accepted nor rejected anything.
  ///
  /// Both actions are declared `showsUserInterface: true`, so the OS launches or
  /// resumes the app before dispatching here. That means the main isolate is alive
  /// and the injected Dio client (with its auth interceptor) is usable — no
  /// separate isolate-safe path is needed.
  void _handleNotificationResponse(NotificationResponse response) async {
    final payload = response.payload;
    final actionId = response.actionId;

    if (actionId == 'accept') {
      final orderId = _orderIdFromPayload(payload);
      if (orderId != null) {
        await _respondToOrder(orderId: orderId, accept: true);
        await dismissIncomingOrderAlert(orderId);
      }
      if (payload != null) _handleLocalNotificationPayload(payload);
      return;
    }

    if (actionId == 'reject') {
      final orderId = _orderIdFromPayload(payload);
      if (orderId != null) {
        await _respondToOrder(orderId: orderId, accept: false);
        await dismissIncomingOrderAlert(orderId);
      }
      return;
    }

    if (payload != null) _handleLocalNotificationPayload(payload);
  }

  String? _orderIdFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        final id = (decoded['orderMongoId'] ?? decoded['orderId'])?.toString();
        return (id == null || id.isEmpty) ? null : id;
      }
    } catch (_) {
      // Legacy bare-orderId payload.
    }
    return payload;
  }

  Future<void> _respondToOrder({
    required String orderId,
    required bool accept,
  }) async {
    try {
      await _dio.patch(
        accept
            ? ApiEndpoints.orderAccept(orderId)
            : ApiEndpoints.orderReject(orderId),
      );
    } catch (_) {
      // Best-effort: the offer may already have expired or gone to another rider.
      // The order screen we open alongside this shows the real current state.
    }
  }

  /// Payload from a locally-shown notification — the full-screen incoming-
  /// order alert encodes the whole data map as JSON; older/other local
  /// notifications may still carry a bare orderId string.
  void _handleLocalNotificationPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map) {
        _notificationTapController.add(Map<String, dynamic>.from(decoded));
        return;
      }
    } catch (_) {
      // Not JSON — fall through to the legacy plain-orderId form.
    }
    _notificationTapController.add({'orderId': payload});
  }

  Future<void> registerToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    await _tokenStorage.saveFcmToken(token);
    try {
      await _dio.post(
        ApiEndpoints.fcmTokenSaveMobile,
        data: {'token': token, 'platform': 'mobile'},
      );
    } catch (_) {
      // Best-effort — token is also sent at OTP verify / registration.
    }
  }

  /// Unsubscribes this device from pushes for the account being signed out.
  ///
  /// The token was not being sent, so the server had no idea which device to
  /// detach — it rejected the call, this catch swallowed the error, and logout
  /// completed locally with the token still attached. The rider signed out and
  /// kept receiving new-order alerts.
  ///
  /// Sends the token the device actually holds so only this device is detached.
  /// Falls back to the live FCM token when nothing was stored, and to a bare
  /// request when neither is available — the server treats that as "sign this
  /// owner out everywhere", which is still better than leaving it subscribed.
  Future<void> removeToken() async {
    String? token = await _tokenStorage.getFcmToken();
    if (token == null || token.isEmpty) {
      try {
        token = await FirebaseMessaging.instance.getToken();
      } catch (_) {
        token = null;
      }
    }

    try {
      await _dio.delete(
        ApiEndpoints.fcmTokenRemove,
        data: (token != null && token.isNotEmpty) ? {'token': token} : null,
      );
    } catch (_) {
      // Ignore — logging out locally regardless.
    }
    try {
      // Force Firebase to invalidate this token locally. This guarantees that 
      // even if the backend fails to remove it from the old user's profile, 
      // this device will no longer receive their pushes. The next user to 
      // log in will get a brand new unique token.
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }

  void _showForegroundNotification(RemoteMessage message) {
    _notificationReceivedController.add(message.data);

    // Foreground gets the same withdrawal. The in-app alert is cleared by the
    // controller listening to the stream above; the overlay and any tray alert
    // raised earlier while backgrounded are cleared here.
    if (message.data['type'] == 'order_taken') {
      final orderId = _orderIdOf(message.data);
      if (orderId != null) {
        OrderOverlayService.closeForOrder(orderId);
        _localNotifications.cancel(incomingOrderNotificationId(orderId));
      }
      return;
    }

    // 'new_order' pushes are already handled by the full-screen incoming-
    // order overlay (driven by the line above) — showing the plain tray
    // notification too would duplicate/compete with it.
    if (message.data['type'] == 'new_order') return;
    final notification = message.notification;
    if (notification == null) return;
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['orderId'] as String?,
    );
  }

  void _handleNotificationOpen(RemoteMessage message) {
    _notificationTapController.add(message.data);
  }

  void dispose() {
    _notificationTapController.close();
    _notificationReceivedController.close();
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService(
    ref.read(dioProvider),
    ref.read(tokenStorageProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});
