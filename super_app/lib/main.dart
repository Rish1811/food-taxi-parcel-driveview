import 'package:superapp_user/core/storage/storage_providers.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/storage/local_storage_service.dart';
import 'package:superapp_user/app/super_app.dart';
import 'package:superapp_user/core/push/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[APP] App Started');

  // Hive — backs the ride-side boxes (recent searches, saved places,
  // emergency contacts, favourite drivers, settings). Opened here because
  // several call sites read boxes synchronously.
  //
  // Follow-up: only `settings` is genuinely needed before the first frame.
  // The other four belong in AppModule.warmUp() so a user who never opens a
  // ride flow does not pay for them at launch (docs/superapp Ch. 16).
  final localStorage = LocalStorageService();
  try {
    await localStorage.init();
    debugPrint('[APP] Local storage ready');
  } catch (e) {
    debugPrint('[APP] Local storage init failed: $e');
  }

  final firebaseOk = await ensureFirebaseInitialized();
  if (firebaseOk) {
    debugPrint('[APP] Firebase Initialized');
  }

  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    debugPrint('[FCM] Background Handler Registered');
  } catch (e) {
    debugPrint('[FCM] Background Handler Registration failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(localStorage),
      ],
      child: const SuperApp(),
    ),
  );
}
