import 'package:superapp_user/core/error/failures.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:superapp_user/core/config/api_config.dart';
import 'package:superapp_user/core/network/api_client.dart';
import 'package:superapp_user/shared/profile/data/user_model.dart';
import 'package:superapp_user/shared/wallet/data/wallet_model.dart';

/// Wallet, referrals, notification inbox and FCM registration — the
/// account-scoped endpoints under `/food/user`, `/food/notifications` and
/// `/fcm-tokens`. All Bearer-only.
class AccountRemoteDataSource {
  final ApiClient _client;

  const AccountRemoteDataSource(this._client);

  // --------------------------------------------------------------- wallet

  Future<WalletModel> getWallet() async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.wallet);
    final wallet = data['wallet'];
    return WalletModel.fromApi(
      wallet is Map ? wallet.cast<String, dynamic>() : data,
    );
  }

  /// Creates a Razorpay order for a top-up. `amount` in the response is paise.
  Future<Map<String, dynamic>> createTopupOrder(double amount) async {
    final data = await _client.post<Map<String, dynamic>>(
      '${ApiPaths.wallet}/topup/order',
      body: {'amount': amount},
    );
    return ((data['razorpay'] as Map?) ?? const {}).cast<String, dynamic>();
  }

  /// Idempotent — re-verifying a completed top-up returns the wallet unchanged
  /// rather than double-crediting.
  Future<WalletModel> verifyTopup({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required double amount,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '${ApiPaths.wallet}/topup/verify',
      body: {
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
        'amount': amount,
      },
    );
    final wallet = data['wallet'];
    return WalletModel.fromApi(
      wallet is Map ? wallet.cast<String, dynamic>() : data,
    );
  }

  Future<CashbackHistory> getCashbackHistory({int page = 1, int limit = 20}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.cashbackHistory,
      query: {'page': page, 'limit': limit},
    );
    return CashbackHistory.fromApi(data);
  }

  Future<RefundHistory> getRefundHistory({int page = 1, int limit = 20}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.refundHistory,
      query: {'page': page, 'limit': limit},
    );
    return RefundHistory.fromApi(data);
  }

  /// No auth required, but the shared client attaches the token when a
  /// session exists — harmless either way.
  Future<CashbackSettings> getCashbackSettings() async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.cashbackSettings, auth: false);
    return CashbackSettings.fromApi(data);
  }

  // ------------------------------------------------------------ referrals

  Future<ReferralDetails> getReferralDetails() async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.referralDetails);
    return ReferralDetails.fromApi(data);
  }

  // -------------------------------------------------------- notifications

  Future<({List<AppNotification> items, int unreadCount, int totalPages})> getInbox({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.notificationInbox,
      query: {'page': page, 'limit': limit},
    );
    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AppNotification.fromApi(e.cast<String, dynamic>()))
        .toList();
    // Notifications use `pagination`, unlike orders (`meta`) and restaurants
    // (flat `total`). Three envelopes exist across this API.
    final pagination = (data['pagination'] as Map?)?.cast<String, dynamic>() ?? const {};
    return (
      items: items,
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<void> markRead(String id) async {
    await _client.patch<dynamic>('${ApiPaths.notificationInbox.replaceAll('/inbox', '')}/$id/read');
  }

  Future<void> deleteNotification(String id) async {
    await _client.delete<dynamic>('${ApiPaths.notificationInbox.replaceAll('/inbox', '')}/$id');
  }

  Future<void> clearInbox() async {
    await _client.delete<dynamic>('${ApiPaths.notificationInbox}/all');
  }

  // ------------------------------------------------------------ fcm token

  /// Mobile variant — POST /api/v1/fcm-tokens/mobile/save
  /// Registers this device against the signed-in account.
  ///
  /// Contract (k9): `POST /api/v1/fcm-tokens/mobile/save` with `{ token }`
  /// and a bearer. **`platform` must be omitted on mobile** — sending it is
  /// rejected with 400; only the web endpoint (`/fcm-tokens/save`) takes
  /// `platform: "web"`.
  ///
  /// The owner (ownerType/ownerId) is derived from the token, so no user id is
  /// passed, and the call is an upsert — repeating it with the same token is
  /// safe and is what makes the app-start reconciliation cheap.
  Future<bool> saveFcmToken(String token, {UserModel? user}) async {
    try {
      // Plain client call: the auth interceptor attaches the bearer, so the
      // previous hand-built Authorization header was both redundant and the
      // reason the raw JWT was being written to the log on every launch.
      await _client.post<dynamic>(ApiPaths.fcmSaveMobile, body: {'token': token});
      if (kDebugMode) debugPrint('[FCM] token registered');
      return true;
    } on Failure catch (failure) {
      if (kDebugMode) debugPrint('[FCM] token registration failed: ${failure.message}');
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] token registration failed: $e');
      return false;
    }
  }

  /// Unregisters this device so the next account on the handset is not
  /// targeted with the previous user's notifications.
  ///
  /// Uses the path form (`/fcm-tokens/remove/:token`) rather than a body:
  /// DELETE-with-body is inconsistently supported across proxies, and the
  /// previous call also sent `platform: 'mobile'`, which the mobile
  /// endpoints reject.
  Future<void> removeFcmToken(String token) async {
    await _client.delete<dynamic>('${ApiPaths.fcmRemove}/$token');
  }
}
