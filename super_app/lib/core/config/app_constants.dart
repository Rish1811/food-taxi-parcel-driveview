import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class LocaleLanguageList {
  final String name;
  final String lang;
  final String? flag;

  const LocaleLanguageList({
    required this.name,
    required this.lang,
    this.flag,
  });
}

/// Central App Constants for K9 User Application.
class AppConstants {
  const AppConstants._();

  static const String title = 'K9';
  static const String appName = 'K9';

  /// Merchant name shown on the Razorpay checkout sheet.
  ///
  /// Without this Razorpay falls back to the legal entity registered on the
  /// account ("SWITCHEATS PRIVATE LIMITED"), which is not our consumer brand.
  static const String brandName = 'Food+taxi';

  /// Public logo URL for the Razorpay sheet. Razorpay fetches this over the
  /// network, so a bundled asset cannot be used — it must be a hosted URL.
  /// Falls back to the backend's configured business logo when set.
  static const String brandLogoUrl = String.fromEnvironment('BRAND_LOGO_URL');
  static const String appVersion = '1.0.0';

  /// Backend REST API host domain.
  static const String hostUrl = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://k9.appzeto.com',
  );

  /// Backend REST API base URL (all endpoints mounted under `/api/v1`).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '$hostUrl/api/v1',
  );

  /// Socket.IO server URL.
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: hostUrl,
  );

  /// Firebase project configuration for the super app (com.k9bharat.user).
  ///
  /// Project `k9rides-529a8` — the same project the k9 backend authenticates
  /// as (`firebase-adminsdk-fbsvc@k9rides-529a8.iam.gserviceaccount.com`).
  /// These values must stay in sync with `android/app/google-services.json`;
  /// they are only used as a fallback when the default `Firebase.initializeApp()`
  /// fails to read the platform config (see `ensureFirebaseInitialized`).
  ///
  /// iOS is not configured yet — there is no GoogleService-Info.plist for this
  /// project, so iOS builds will fall through to the failure branch.
  static String firebaseApiKey = (kIsWeb || Platform.isAndroid)
      ? "AIzaSyDt1UEqn5kYbrbQoRJnQ5klKZbLNVrGvuQ"
      : "ios firebase api key";

  static String get firbaseApiKey => firebaseApiKey;

  static String firebaseAppId = (kIsWeb || Platform.isAndroid)
      ? "1:857854567102:android:0472547c3baf400bfc34ef"
      : "ios firebase app id";

  static String firebaseMessagingSenderId =
      (kIsWeb || Platform.isAndroid) ? "857854567102" : "ios firebase sender id";

  static String get firebasemessagingSenderId => firebaseMessagingSenderId;

  static String firebaseProjectId =
      (kIsWeb || Platform.isAndroid) ? "k9rides-529a8" : "ios firebase project id";

  /// Regional RTDB instance — note this is NOT the default `.firebaseio.com`
  /// domain, so it must always be passed explicitly to
  /// `FirebaseDatabase.instanceFor(app:, databaseURL:)`.
  static String firebaseDatabaseUrl =
      "https://k9rides-529a8-default-rtdb.asia-southeast1.firebasedatabase.app";

  static const String firebaseStorageBucket = "k9rides-529a8.firebasestorage.app";

  /// Google Maps API key (Maps SDK + Geocoding API).
  static String mapKey = 'AIzaSyCLHQKJg5shpKs0uNiDHiZJTtBUMKl21ak';

  /// Payment Gateway keys.
  static const String stripePublishKey = '';
  static const String stripPublishKey = stripePublishKey;
  static String razorpayKey = '';

  /// Supported App Languages.
  static List<LocaleLanguageList> languageList = const [
    LocaleLanguageList(name: 'English', lang: 'en'),
  ];

  static String packageName = 'com.k9bharat.user';
  static String signKey = '';
}
