class WalletTransactionModel {
  final String id;
  final String type;
  final double amount;
  final String description;
  final DateTime createdAt;
  final String status;

  const WalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    required this.status,
  });

  bool get isCredit => type.toLowerCase() == 'credit';

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    final rawAmount = double.tryParse('${json['amount'] ?? 0}') ?? 0;
    final inferredType = rawAmount >= 0 ? 'credit' : 'debit';
    return WalletTransactionModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: (json['type'] ?? inferredType).toString(),
      amount: rawAmount.abs(),
      description: (json['description'] ?? json['note'] ?? json['reason'] ?? 'Transaction').toString(),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? json['created_at'] ?? ''}') ?? DateTime.now(),
      status: (json['status'] ?? 'success').toString(),
    );
  }
}
