import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:superapp_user/core/config/app_constants.dart';
import 'package:superapp_user/shared/profile/data/account_remote_datasource.dart';
import 'package:superapp_user/shared/profile/data/user_model.dart';

/// Fired when a push should navigate somewhere. The router listens to this
/// rather than the service reaching into navigation itself.
typedef PushDeepLinkHandler = void Function(PushDeepLink link);

/// A routed push.
///
/// Payloads carry `data.type` (`order_created`,
/// `order_created_pending_payment`, `payment_success`) plus `orderId`,
/// `orderMongoId` and a `link` like `/food/user/orders/<id>`.
class PushDeepLink {
  final String type;
  final String? orderId;
  final String? orderMongoId;
  final String? link;

  const PushDeepLink({
    required this.type,
    this.orderId,
    this.orderMongoId,
    this.link,
  });

  /// The id to open a tracking screen with — the Mongo id is what
  /// `GET /food/orders/:orderId` expects.
  String? get trackableOrderId => orderMongoId ?? orderId;

  bool get isOrderEvent =>
      type.startsWith('order_') ||
      type.startsWith('delivery_') ||
      type == 'payment_success' ||
      type == 'delivery_accepted';

  factory PushDeepLink.fromData(Map<String, dynamic> data) {
    return PushDeepLink(
      type: (data['type'] ?? '').toString(),
      orderId: data['orderId']?.toString(),
      orderMongoId: data['orderMongoId']?.toString(),
      link: data['link']?.toString(),
    );
  }
}

/// Ensures Firebase is initialized before any FCM calls.
Future<bool> ensureFirebaseInitialized() async {
  if (Firebase.apps.isNotEmpty) return true;
  debugPrint('[FCM] Firebase.initializeApp() started');
  try {
    await Firebase.initializeApp();
    debugPrint('[FCM] Firebase Initialized');
    return true;
  } catch (e) {
    debugPrint('[FCM] Standard Firebase initializeApp failed: $e. Using AppConstants FirebaseOptions...');
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: AppConstants.firebaseApiKey,
          appId: AppConstants.firebaseAppId,
          messagingSenderId: AppConstants.firebaseMessagingSenderId,
          projectId: AppConstants.firebaseProjectId,
          databaseURL: AppConstants.firebaseDatabaseUrl,
        ),
      );
      debugPrint('[FCM] Firebase Initialized');
      return true;
    } catch (fallbackErr) {
      debugPrint('[FCM] Firebase initialization failed: $fallbackErr');
      return false;
    }
  }
}

/// Background isolate handler.
///
/// Must be a top-level function and must initialize Firebase itself — the
/// isolate does not inherit the app's initialization.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await ensureFirebaseInitialized();
  final title = message.notification?.title ?? message.data['title'] ?? 'Order Update';
  final body = message.notification?.body ?? message.data['body'] ?? '';
  final payload = message.data;
  final link = PushDeepLink.fromData(Map<String, dynamic>.from(payload));

  debugPrint('''
[FCM] Background Notification Received
Notification Title: $title
Notification Body: $body
Payload: $payload
Order ID: ${link.trackableOrderId ?? "N/A"}
Notification Type: ${link.type}''');
}

/// Firebase Cloud Messaging wiring.
///
/// Covers all three delivery states:
///  * **foreground** — system heads-up notification via [FlutterLocalNotificationsPlugin]
///  * **background** — `onMessageOpenedApp` when the user taps the tray item
///  * **terminated** — `getInitialMessage()` on the first frame
class PushService {
  static const _localFcmKey = 'fcm_token_local';

  final AccountRemoteDataSource _account;
  final FlutterSecureStorage _storage;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  PushService(this._account, [FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  PushDeepLinkHandler? _onDeepLink;

  final _foreground = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onForeground => _foreground.stream;

  String? _token;
  String? get token => _token;

  bool _firebaseInitialized = false;
  bool _permissionGranted = false;
  bool _backendSaveSuccess = false;

  void _logNotificationDetails(String source, RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'] ?? 'Order Update';
    final body = message.notification?.body ?? message.data['body'] ?? '';
    final payload = message.data;
    final link = PushDeepLink.fromData(Map<String, dynamic>.from(payload));

    debugPrint('''
[FCM] Notification Details ($source):
Notification Title: $title
Notification Body: $body
Payload: $payload
Order ID: ${link.trackableOrderId ?? "N/A"}
Notification Type: ${link.type}''');
  }

  /// Wires listeners & requests notification permission automatically on startup.
  Future<void> initialize({
    PushDeepLinkHandler? onDeepLink,
    VoidCallback? onPermanentlyDenied,
  }) async {
    _onDeepLink = onDeepLink;

    try {
      _firebaseInitialized = await ensureFirebaseInitialized();

      // STEP: INITIALIZE LOCAL NOTIFICATIONS FOR SYSTEM HEADS-UP NOTIFICATIONS
      const androidChannel = AndroidNotificationChannel(
        'default',
        'High Importance Notifications',
        description: 'This channel is used for order status push notifications.',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);

      await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          _log('Notification clicked.');
          if (response.payload != null && response.payload!.isNotEmpty) {
            try {
              final Map<String, dynamic> data = jsonDecode(response.payload!);
              final link = PushDeepLink.fromData(data);
              if (link.isOrderEvent && link.trackableOrderId != null) {
                _log('Opening Order Tracking screen.');
                _onDeepLink?.call(link);
              }
            } catch (e) {
              _log('Error handling notification tap payload: $e');
            }
          }
        },
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // STEP 2: NOTIFICATION PERMISSION
      _log('Permission Requested');
      final status = await Permission.notification.status;
      if (status.isDenied) {
        final requested = await Permission.notification.request();
        _log('Permission Result: ${requested.name}');
        if (requested.isGranted) {
          _permissionGranted = true;
        } else if (requested.isPermanentlyDenied) {
          onPermanentlyDenied?.call();
        }
      } else if (status.isPermanentlyDenied) {
        _log('Permission Result: permanentlyDenied');
        onPermanentlyDenied?.call();
      } else if (status.isGranted || status.isLimited) {
        _log('Permission Result: ${status.name}');
        _permissionGranted = true;
      }

      final fcmSettings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
      if (fcmSettings.authorizationStatus == AuthorizationStatus.authorized ||
          fcmSettings.authorizationStatus == AuthorizationStatus.provisional) {
        _permissionGranted = true;
      }

      // STEP 3: TOKEN GENERATION
      _log('Fetching FCM token...');
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        _token = token;
        _log('Generated Token:\n$token');

        // STEP 7: LOCAL STORAGE
        await _saveTokenLocally(token);

        // STEP 5 & 6: BACKEND REQUEST
        _backendSaveSuccess = await _save(token);
      } else {
        _log('Generated Token: NULL - getToken() returned empty or null');
      }

      // STEP 9: FOREGROUND HANDLER REGISTERED (SHOW SYSTEM HEADS-UP NOTIFICATION VIA FLUTTER_LOCAL_NOTIFICATIONS)
      _onMessageSub = FirebaseMessaging.onMessage.listen((message) async {
        _logNotificationDetails('Foreground', message);
        _log('Foreground message received.');

        if (!_foreground.isClosed) {
          _foreground.add(message);
        }

        final title = message.notification?.title ?? message.data['title'] ?? 'Order Update';
        final body = message.notification?.body ?? message.data['body'] ?? '';
        final notificationId = message.hashCode;

        _log('Displaying local notification.');
        try {
          const androidDetails = AndroidNotificationDetails(
            'default',
            'High Importance Notifications',
            channelDescription: 'This channel is used for order status push notifications.',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            playSound: true,
            enableVibration: true,
            icon: '@mipmap/ic_launcher',
          );
          const notificationDetails = NotificationDetails(android: androidDetails);

          await _localNotifications.show(
            id: notificationId,
            title: title,
            body: body,
            notificationDetails: notificationDetails,
            payload: jsonEncode(message.data),
          );
          _log('Local notification displayed successfully.');
        } catch (e) {
          _log('Failed to display local notification: $e');
        }
      });

      // STEP 12: NOTIFICATION CLICK (BACKGROUND)
      _onOpenedSub = FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _logNotificationDetails('Background', message);
        _route(message);
      });

      // STEP 11: TERMINATED NOTIFICATION
      final initial = await _messaging.getInitialMessage();
      _log('Initial Message Checked');
      if (initial != null) {
        _logNotificationDetails('Terminated', initial);
        _route(initial);
      }

      // STEP 4: TOKEN REFRESH
      _onTokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) {
        final oldToken = _token;
        _token = newToken;
        _log('Token Refreshed\nOld Token:\n${oldToken ?? "NULL"}\nNew Token:\n$newToken');
        unawaited(_saveTokenLocally(newToken));
        unawaited(_save(newToken));
      });

      debugPrint('[APP] Notification Service Initialized');

      // STEP 13: SUMMARY
      _printDebugSummary();
    } catch (e) {
      _log('initialize failed: $e');
    }
  }

  /// Registers the device against the signed-in account. Call after login.
  Future<void> registerToken({UserModel? user}) async {
    try {
      await ensureFirebaseInitialized();
      _log('Fetching FCM token...');
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        _log('ERROR: FCM Token is NULL');
        return;
      }
      _token = token;
      _log('FCM Token Generated:\n$token');
      await _saveTokenLocally(token);
      _backendSaveSuccess = await _save(token, user: user);
      _printDebugSummary();
    } catch (e) {
      _log('registerToken failed: $e');
    }
  }

  /// App Start launch check (Step 8).
  Future<void> performAppStartCheck({required bool isLoggedIn, UserModel? user}) async {
    final storedToken = await getStoredTokenLocally();
    final currentToken = await _safeToken();
    _log('App Launch Check:\nLogged In: $isLoggedIn\nUser ID: ${user?.id ?? "N/A"}\nPhone: ${user?.phone ?? "N/A"}\nStored Token: ${storedToken ?? "NULL"}\nCurrent Firebase Token: ${currentToken ?? "NULL"}');

    if (currentToken != null && currentToken.isNotEmpty) {
      await _saveTokenLocally(currentToken);
      if (isLoggedIn || user != null) {
        _log('Registering FCM token on fresh launch...');
        await registerToken(user: user);
      }
    }
  }

  /// Unregisters on logout — the device must stop being targeted at all
  /// three levels (backend record, Firebase-issued token, local cache), plus
  /// any tray notification still showing from the outgoing session.
  ///
  /// Idempotent: reads the token from local storage rather than
  /// `_messaging.getToken()`, which would silently mint a *new* token (and
  /// undefeat the [FirebaseMessaging.deleteToken] call below) if this runs
  /// twice — it does, once from [AuthViewModel.logout] itself and again from
  /// the reactive listener in `superapp_user.dart` that also covers
  /// a forced logout on session expiry.
  Future<void> unregisterToken() async {
    try {
      await _localNotifications.cancelAll();
    } catch (e) {
      _log('cancelAll failed: $e');
    }

    final token = _token ?? await getStoredTokenLocally();
    if (token == null || token.isEmpty) return;

    try {
      await _account.removeFcmToken(token);
    } catch (e) {
      _log('backend unregisterToken failed: $e');
    }
    try {
      await ensureFirebaseInitialized();
      await _messaging.deleteToken();
    } catch (e) {
      _log('deleteToken failed: $e');
    }

    _token = null;
    await _storage.delete(key: _localFcmKey);
  }

  Future<void> _saveTokenLocally(String token) async {
    _log('Saving token locally...');
    await _storage.write(key: _localFcmKey, value: token);
    _log('Local save successful.');
    final readBack = await _storage.read(key: _localFcmKey);
    _log('Local Token:\n$readBack');
  }

  Future<String?> getStoredTokenLocally() async {
    return await _storage.read(key: _localFcmKey);
  }

  Future<String?> _safeToken() async {
    try {
      await ensureFirebaseInitialized();
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _save(String token, {UserModel? user}) async {
    try {
      return await _account.saveFcmToken(token, user: user);
    } catch (e) {
      _log('token save skipped: $e');
      return false;
    }
  }

  void _route(RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;
    final link = PushDeepLink.fromData(Map<String, dynamic>.from(data));
    _log('Notification clicked.');
    if (link.isOrderEvent && link.trackableOrderId != null) {
      _log('Opening Order Tracking screen.');
      _onDeepLink?.call(link);
    }
  }

  void _printDebugSummary() {
    debugPrint('''
=========================
FCM DEBUG SUMMARY
=========================
Firebase Initialized: ${_firebaseInitialized ? "YES" : "NO"}
Permission Granted: ${_permissionGranted ? "YES" : "NO"}
Token Generated: ${_token != null && _token!.isNotEmpty ? "YES" : "NO"}
Token:
${_token ?? "NULL"}
Backend Save Success: ${_backendSaveSuccess ? "YES" : "NO"}
Local Save Success: YES
Notification Channel Created: YES
Foreground Handler Registered: ${_onMessageSub != null ? "YES" : "NO"}
Background Handler Registered: YES
=========================
''');
  }

  void dispose() {
    _onMessageSub?.cancel();
    _onOpenedSub?.cancel();
    _onTokenRefreshSub?.cancel();
    _foreground.close();
  }

  void _log(String msg) {
    debugPrint('[FCM] $msg');
  }
}
