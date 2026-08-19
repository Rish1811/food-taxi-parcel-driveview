import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/network/auth_event_bus.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/socket_service.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../data/models/delivery_partner.dart';
import 'auth_state.dart';

class AuthController extends Notifier<AuthState> {
  late final AuthRepository _repository;
  late final TokenStorage _tokenStorage;
  StreamSubscription<void>? _forceLogoutSub;

  @override
  AuthState build() {
    _repository = ref.read(authRepositoryProvider);
    _tokenStorage = ref.read(tokenStorageProvider);

    _forceLogoutSub = ref.read(authEventBusProvider).onForceLogout.listen((_) {
      ref.read(socketServiceProvider).disconnect();
      state = const AuthUnauthenticated();
    });
    ref.onDispose(() => _forceLogoutSub?.cancel());

    Future.microtask(checkAuthStatus);
    return const AuthInitial();
  }

  Future<void> checkAuthStatus() async {
    final hasToken = await _tokenStorage.hasAccessToken();
    if (!hasToken) {
      state = const AuthUnauthenticated();
      return;
    }
    state = const AuthLoading();
    final result = await _repository.getMe();
    result.when(
      success: (user) => _applyPartnerStatus(user),
      failure: (_) => state = const AuthUnauthenticated(),
    );
  }

  void _applyPartnerStatus(DeliveryPartner user) {
    if (user.isApproved) {
      state = AuthAuthenticated(user);
      _connectRealtime(user);
    } else {
      state = AuthPendingApproval(
        isRejected: user.isRejected,
        rejectionReason: user.rejectionReason,
      );
    }
  }

  Future<void> _connectRealtime(DeliveryPartner user) async {
    final accessToken = await _tokenStorage.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) return;
    ref
        .read(socketServiceProvider)
        .connect(accessToken: accessToken, partnerId: user.id);
    ref.read(fcmServiceProvider).registerToken();
  }

  Future<Result<String, AppError>> requestOtp(String phone) {
    return _repository.requestOtp(phone);
  }

  Future<AuthState> verifyOtp({required String phone, required String otp}) async {
    final fcmToken = await _tokenStorage.getFcmToken();
    final result = await _repository.verifyOtp(
      phone: phone,
      otp: otp,
      fcmToken: fcmToken,
    );
    return result.when(
      success: (verifyResult) {
        if (verifyResult.needsRegistration) {
          state = AuthNeedsRegistration(verifyResult.phone ?? phone);
        } else if (verifyResult.isLoggedIn && verifyResult.user != null) {
          _applyPartnerStatus(verifyResult.user!);
        } else if (verifyResult.pendingApproval) {
          state = AuthPendingApproval(
            isRejected: verifyResult.isRejected,
            rejectionReason: verifyResult.rejectionReason,
          );
        } else {
          state = const AuthUnauthenticated();
        }
        return state;
      },
      failure: (error) {
        return AuthFailure(error.message);
      },
    );
  }

  Future<Result<void, AppError>> register(FormData formData) async {
    final result = await _repository.register(formData);
    return result.when(
      success: (user) {
        _applyPartnerStatus(user);
        return const Result.success(null);
      },
      failure: (error) => Result.failure(error),
    );
  }

  void resetToUnauthenticated() {
    ref.read(socketServiceProvider).disconnect();
    state = const AuthUnauthenticated();
  }

  Future<void> logout() async {
    state = const AuthLoading();
    ref.read(socketServiceProvider).disconnect();
    await ref.read(fcmServiceProvider).removeToken();
    await _repository.logout();
    state = const AuthUnauthenticated();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
