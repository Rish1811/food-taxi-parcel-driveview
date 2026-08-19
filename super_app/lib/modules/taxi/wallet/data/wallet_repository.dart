import 'package:superapp_user/modules/taxi/api/taxi_endpoints.dart';
import 'package:superapp_user/core/network/taxi_api_client.dart';
import 'package:superapp_user/modules/taxi/wallet/data/models/wallet_transaction_model.dart';

class WalletOrderResult {
  final String orderId;
  final String keyId;
  final double amount;

  const WalletOrderResult({required this.orderId, required this.keyId, required this.amount});

  factory WalletOrderResult.fromJson(Map<String, dynamic> json) {
    return WalletOrderResult(
      orderId: (json['orderId'] ?? json['order_id'] ?? json['id'] ?? '').toString(),
      keyId: (json['keyId'] ?? json['key_id'] ?? json['key'] ?? '').toString(),
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
    );
  }
}

class TaxiWalletRepository {
  final TaxiApiClient api;

  TaxiWalletRepository(this.api);

  Future<double> getBalance() async {
    final data = await api.get(ApiConstants.wallet);
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    return double.tryParse('${map['balance'] ?? 0}') ?? 0;
  }

  Future<List<WalletTransactionModel>> getTransactions() async {
    final data = await api.get(ApiConstants.wallet);
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final results = (map['transactions'] ?? map['results'] ?? []) as List;
    return results.map((e) => WalletTransactionModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<WalletOrderResult> createTopupOrder(double amount) async {
    final data = await api.post(ApiConstants.walletRazorpayOrder, data: {'amount': amount});
    return WalletOrderResult.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> verifyTopupPayment(Map<String, dynamic> payload) {
    return api.post(ApiConstants.walletRazorpayVerify, data: payload);
  }
}
