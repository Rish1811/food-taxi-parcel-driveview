import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superapp_user/core/network/api_client.dart';
import 'package:superapp_user/core/storage/token_storage.dart';
import 'package:superapp_user/modules/food/api/datasources/auth_remote_datasource.dart';
import 'package:superapp_user/modules/food/data/repositories/auth_repository_impl.dart';

/// Exercises the real network stack against the live backend.
///
/// Run with:  flutter test test/auth_integration_test.dart
///
/// Covers the parts most likely to break silently: envelope unwrapping,
/// token persistence, and the Bearer-authenticated round trip.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // flutter_secure_storage is a platform channel — back it with an in-memory
  // map so the repository's real persistence path runs under test.
  final store = <String, String>{};
  setUpAll(() {
    // flutter_test installs HttpOverrides that stub every request with a 400.
    // This suite deliberately talks to the real backend.
    HttpOverrides.global = null;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async {
        switch (call.method) {
          case 'write':
            store[call.arguments['key'] as String] = call.arguments['value'] as String;
            return null;
          case 'read':
            return store[call.arguments['key'] as String];
          case 'delete':
            store.remove(call.arguments['key'] as String);
            return null;
          case 'readAll':
            return store;
          case 'deleteAll':
            store.clear();
            return null;
        }
        return null;
      },
    );
  });

  const testPhone = '9999999999';

  late TokenStorage tokens;
  late AuthRepositoryImpl repo;

  setUp(() {
    store.clear();
    tokens = TokenStorage();
    final client = ApiClient(tokens: tokens);
    repo = AuthRepositoryImpl(AuthRemoteDataSource(client), tokens);
  });

  test('request OTP → verify → session persisted → authed profile fetch', () async {
    // 1. Request OTP. Dev backend echoes the code back.
    final otpResult = await repo.requestOtp(testPhone);
    expect(otpResult.isSuccess, isTrue, reason: otpResult.message);
    final otp = otpResult.data;
    expect(otp, isNotNull, reason: 'dev backend should echo the OTP');

    // 2. Verify. This is where the envelope is unwrapped and tokens are saved.
    final session = await repo.verifyOtp(phone: testPhone, otp: otp!);
    expect(session.isSuccess, isTrue, reason: session.message);
    expect(session.data!.accessToken, isNotEmpty);
    expect(session.data!.user.phone, testPhone);

    // 3. Tokens actually landed in secure storage.
    expect(await tokens.hasSession, isTrue);
    expect(await tokens.accessToken, isNotEmpty);

    // 4. Authenticated round trip using the stored Bearer token.
    final profile = await repo.getProfile();
    expect(profile.isSuccess, isTrue, reason: profile.message);
    expect(profile.data!.id, session.data!.user.id);

    // 5. Session restore is what cold start relies on.
    final restored = await repo.restoreSession();
    expect(restored.data, isNotNull);

    // 6. Logout clears the session locally even though the server call is
    //    best-effort.
    await repo.logout();
    expect(await tokens.hasSession, isFalse);
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('a wrong OTP surfaces the backend message, not a crash', () async {
    await repo.requestOtp(testPhone);
    final result = await repo.verifyOtp(phone: testPhone, otp: '0000');
    expect(result.isSuccess, isFalse);
    expect(result.message, isNotNull);
    expect(await tokens.hasSession, isFalse, reason: 'failed login must not persist tokens');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('validation rejections surface the backend reason, not a generic fallback', () async {
    // The API puts validation reasons under `error`, not `message` — regression
    // guard for the client reading only one of the two.
    final result = await repo.verifyOtp(phone: testPhone, otp: '12');
    expect(result.isSuccess, isFalse);
    expect(result.message, contains('4 digits'));
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('profile update round-trips through PATCH', () async {
    final otp = (await repo.requestOtp(testPhone)).data!;
    await repo.verifyOtp(phone: testPhone, otp: otp);

    final name = 'QA ${DateTime.now().millisecondsSinceEpoch % 100000}';
    final updated = await repo.updateProfile(name: name);
    expect(updated.isSuccess, isTrue, reason: updated.message);
    expect(updated.data!.name, name);

    // Confirm the server, not just the local object, actually changed.
    final refetched = await repo.getProfile();
    expect(refetched.data!.name, name);
  }, timeout: const Timeout(Duration(seconds: 90)));
}
