import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/shared/auth/data/auth_session.dart';
import 'package:superapp_user/shared/profile/data/user_model.dart';
import 'package:superapp_user/shared/auth/application/auth_providers.dart';
import 'package:superapp_user/modules/food/application/providers/favorites_providers.dart';
import 'package:superapp_user/core/network/network_providers.dart';
import 'package:superapp_user/core/push/push_providers.dart';
import 'package:superapp_user/modules/food/data/contracts/auth_repository.dart';
import 'package:superapp_user/modules/food/presentation/favorites/viewmodels/favorites_viewmodel.dart';

void _authLog(String message) {
  if (kDebugMode) debugPrint('[AUTH] $message');
}

/// Holds the authenticated user, or null for guest mode.
///
/// State is restored from the encrypted token store on cold start, so a logged-in
/// user never sees the login screen again until the refresh token actually dies.
final authViewModelProvider =
    AsyncNotifierProvider<AuthViewModel, UserModel?>(AuthViewModel.new);

class AuthViewModel extends AsyncNotifier<UserModel?> {
  late final AuthRepository _repository;

  /// Last error surfaced by an auth action, for screens to render inline
  /// without flipping the whole provider into an error state (which would
  /// unmount the form).
  String? lastError;

  @override
  FutureOr<UserModel?> build() async {
    _repository = ref.watch(authRepositoryProvider);

    // The network layer bumps this when a refresh fails — drop to guest mode.
    ref.listen(sessionExpiredProvider, (_, _) {
      state = const AsyncValue.data(null);
    });

    final result = await _repository.restoreSession();
    return result.data;
  }

  bool get isLoggedIn => state.value != null;

  /// Step 1 — send the OTP. Returns the dev-mode code when the backend echoes
  /// it, so staging builds can prefill the field.
  Future<({bool ok, String? devOtp})> requestOtp(String phone) async {
    lastError = null;
    final result = await _repository.requestOtp(phone);
    if (!result.isSuccess) lastError = result.message;
    return (ok: result.isSuccess, devOtp: result.data);
  }

  /// A verification already in flight, so concurrent calls collapse onto it.
  Future<AuthSession?>? _verifyInFlight;

  /// Step 2 — verify. On success the token pair is persisted and the user is
  /// live. Returns the session so the caller can branch on
  /// [AuthSession.needsProfileSetup].
  ///
  /// **Single-flight.** The OTP is single-use on the backend, so two racing
  /// submissions of the same code would let the first succeed (and log the user
  /// in) while the second comes back "OTP not found" — which previously surfaced
  /// as a failure even though the session was already created. Collapsing
  /// concurrent calls onto one in-flight future guarantees the code is submitted
  /// exactly once, so success and the returned result stay consistent.
  Future<AuthSession?> verifyOtp({
    required String phone,
    required String otp,
    String? name,
    String? referralCode,
    String? fcmToken,
  }) {
    final inFlight = _verifyInFlight;
    if (inFlight != null) {
      _authLog('Verify already in progress — reusing the in-flight request');
      return inFlight;
    }
    final future = _doVerify(
      phone: phone,
      otp: otp,
      name: name,
      referralCode: referralCode,
      fcmToken: fcmToken,
    ).whenComplete(() => _verifyInFlight = null);
    _verifyInFlight = future;
    return future;
  }

  Future<AuthSession?> _doVerify({
    required String phone,
    required String otp,
    String? name,
    String? referralCode,
    String? fcmToken,
  }) async {
    lastError = null;
    _authLog('Verifying OTP...');
    final result = await _repository.verifyOtp(
      phone: phone,
      otp: otp,
      name: name,
      referralCode: referralCode,
      fcmToken: fcmToken,
    );

    if (result.isSuccess && result.data != null) {
      _authLog('OTP verification successful');
      _authLog('Creating session · Saving JWT · Saving User');
      // Single source of truth for auth: the session is only ever set here,
      // and only on a verified success.
      state = AsyncValue.data(result.data!.user);
      _authLog('Authentication state updated (isLoggedIn = true)');
      return result.data;
    }
    _authLog('OTP verification failed: ${result.message}');
    lastError = result.message;
    return null;
  }

  /// Step 3 — profile completion / later edits. Optimistically keeps the
  /// current user on screen and updates Riverpod state.
  Future<bool> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    String? gender,
    String? dateOfBirth,
    String? anniversary,
  }) async {
    lastError = null;
    final currentUser = state.value;
    final updatedUser = (currentUser ?? const UserModel(id: 'u1')).copyWith(
      name: name ?? currentUser?.name,
      email: email ?? currentUser?.email,
      phone: phone ?? currentUser?.phone,
      avatarUrl: avatarUrl ?? currentUser?.avatarUrl,
      gender: gender ?? currentUser?.gender,
      dateOfBirth: dateOfBirth ?? currentUser?.dateOfBirth,
      anniversary: anniversary ?? currentUser?.anniversary,
    );

    // Optimistically update local Riverpod state immediately
    state = AsyncValue.data(updatedUser);

    final result = await _repository.updateProfile(
      name: name,
      email: email,
      gender: gender,
      dateOfBirth: dateOfBirth,
      anniversary: anniversary,
    );
    if (result.isSuccess && result.data != null) {
      state = AsyncValue.data(result.data!.copyWith(
        avatarUrl: avatarUrl ?? result.data!.avatarUrl,
        phone: phone ?? result.data!.phone,
      ));
      return true;
    }
    return true;
  }

  /// Pull the freshest profile (after an address change, wallet top-up, etc.).
  Future<void> refreshProfile() async {
    final result = await _repository.getProfile();
    if (result.isSuccess && result.data != null) {
      state = AsyncValue.data(result.data);
    }
  }

  /// Clears the session securely and returns to guest mode. App settings stored
  /// outside the token store are untouched.
  ///
  /// Unregisters the push token *before* [AuthRepository.logout] clears the
  /// access token — the backend removal call needs a still-valid Authorization
  /// header, and firing it after the token store is wiped meant it silently
  /// failed and the device kept receiving pushes for the logged-out account.
  Future<void> logout({String? fcmToken}) async {
    final push = ref.read(pushServiceProvider);
    // Belt-and-suspenders: also hand the token to the logout call itself, so
    // the backend can drop it in the same authenticated request even if the
    // dedicated unregister call below fails transiently.
    final currentPushToken = fcmToken ?? push.token;
    await push.unregisterToken();
    await _repository.logout(fcmToken: currentPushToken);
    // Favourites are cached under a device-wide key, so they would otherwise
    // follow the device into the next account.
    await ref.read(favoritesRepositoryProvider).clearLocal();
    ref.invalidate(favoritesViewModelProvider);
    state = const AsyncValue.data(null);
  }
}
