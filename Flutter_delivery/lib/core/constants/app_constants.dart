import 'dart:io';

import 'package:food_user_application/features/language/domain/models/language_listing_model.dart';

class AppConstants {
  static const String title = 'Appzeto Delivery';
  static const String appFontFamily = 'Latin';

  static const String apiHost = 'https://k9.appzeto.com';
  static const String baseUrl = '$apiHost/api/v1';

  static String resolveMediaUrl(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '';
    if (v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('data:')) {
      return v;
    }
    final path = v.startsWith('/') ? v : '/$v';
    return '$apiHost$path';
  }

  static String firbaseApiKey = (Platform.isAndroid)
      ? "AIzaSyC_twLhO7C21HdRBvoZvedceka0jdLCUjc"
      : "ios firebase api key";

  static String firebaseAppId = (Platform.isAndroid)
      ? "1:592916974677:android:5366c1825a27cf201518dc"
      : "ios firebase app id";

  static String firebasemessagingSenderId = (Platform.isAndroid)
      ? "592916974677"
      : "ios firebase sender id";

  static String firebaseProjectId = (Platform.isAndroid)
      ? "flutterfoodapp-e6742"
      : "ios firebase project id";

  static String mapKey = (Platform.isAndroid)
      ? 'AIzaSyArBbII2fgAuVaycfkEAm1GcuyvKPTSWyc'
      : 'your ios map key';

  static const String stripPublishKey = '';

  static List<LocaleLanguageList> languageList = [
    LocaleLanguageList(name: 'English', lang: 'en'),
  ];

  static String packageName = 'com.k9bharat.delivery';
  static String signKey = '';

  static const String fontFamily = 'Latin';
}
