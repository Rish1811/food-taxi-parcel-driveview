import 'package:superapp_user/core/config/api_config.dart';

/// A single wallet ledger row from `GET /food/user/wallet`.
class WalletTransaction {
  final String id;

  /// `addition` credits the wallet, anything else debits it. The backend also
  /// emits refund rows through this same `type` field.
  final String type;
  final double amount;
  final String status;
  final String description;
  final DateTime? date;
  final String? source;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.status,
    required this.description,
    this.date,
    this.source,
  });

  // `type` is `addition | deduction | refund` — a refund credits the wallet
  // just like an addition, so both count as credits.
  bool get isCredit => type.toLowerCase() == 'addition' || type.toLowerCase() == 'refund';
  bool get isRefund => type.toLowerCase() == 'refund' || (source ?? '').toLowerCase().contains('refund');

  factory WalletTransaction.fromApi(Map<String, dynamic> json) {
    final raw = (json['date'] ?? json['createdAt'])?.toString();
    return WalletTransaction(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      date: raw == null ? null : DateTime.tryParse(raw),
      source: (json['metadata'] as Map?)?['source']?.toString(),
    );
  }
}

/// `GET /food/user/wallet` → `{ wallet }`.
///
/// A user with no wallet row gets zeros rather than a 404.
class WalletModel {
  final double balance;
  final double referralEarnings;
  final List<WalletTransaction> transactions;

  const WalletModel({
    this.balance = 0.0,
    this.referralEarnings = 0.0,
    this.transactions = const [],
  });

  List<WalletTransaction> get credits => transactions.where((t) => t.isCredit).toList();
  List<WalletTransaction> get debits => transactions.where((t) => !t.isCredit).toList();
  List<WalletTransaction> get refunds => transactions.where((t) => t.isRefund).toList();

  factory WalletModel.fromApi(Map<String, dynamic> json) {
    return WalletModel(
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      referralEarnings: (json['referralEarnings'] as num?)?.toDouble() ?? 0.0,
      transactions: ((json['transactions'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => WalletTransaction.fromApi(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// One row of `GET /food/user/cashback`.
class CashbackEntry {
  final String id;
  final double amount;
  final String description;
  final String orderId;
  final String orderDisplayId;
  final String status;
  final DateTime? date;

  const CashbackEntry({
    required this.id,
    required this.amount,
    required this.description,
    this.orderId = '',
    this.orderDisplayId = '',
    this.status = '',
    this.date,
  });

  factory CashbackEntry.fromApi(Map<String, dynamic> json) {
    final raw = (json['date'] ?? json['createdAt'])?.toString();
    return CashbackEntry(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: (json['description'] ?? '').toString(),
      orderId: (json['orderId'] ?? '').toString(),
      orderDisplayId: (json['orderDisplayId'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      date: raw == null ? null : DateTime.tryParse(raw),
    );
  }
}

/// `GET /food/user/cashback` → `{ totalEarned, items, pagination }`.
class CashbackHistory {
  final double totalEarned;
  final List<CashbackEntry> items;
  final int totalPages;

  const CashbackHistory({this.totalEarned = 0, this.items = const [], this.totalPages = 1});

  factory CashbackHistory.fromApi(Map<String, dynamic> json) {
    final pagination = (json['pagination'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CashbackHistory(
      totalEarned: (json['totalEarned'] as num?)?.toDouble() ?? 0.0,
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => CashbackEntry.fromApi(e.cast<String, dynamic>()))
          .toList(),
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// One row of `GET /food/user/refunds`.
class RefundEntry {
  final String orderId;
  final String orderDisplayId;
  final String restaurantName;
  final double amount;

  /// `pending` | `processed` | `failed`.
  final String status;
  final String method;
  final String refundId;
  final String reason;

  /// `true` — refunded to wallet; `false` — refunded to the original card/UPI.
  final bool creditedToWallet;
  final DateTime? processedAt;
  final DateTime? createdAt;

  const RefundEntry({
    required this.orderId,
    this.orderDisplayId = '',
    this.restaurantName = '',
    required this.amount,
    this.status = '',
    this.method = '',
    this.refundId = '',
    this.reason = '',
    this.creditedToWallet = false,
    this.processedAt,
    this.createdAt,
  });

  factory RefundEntry.fromApi(Map<String, dynamic> json) {
    final processed = json['processedAt']?.toString();
    final created = json['createdAt']?.toString();
    return RefundEntry(
      orderId: (json['orderId'] ?? '').toString(),
      orderDisplayId: (json['orderDisplayId'] ?? '').toString(),
      restaurantName: (json['restaurantName'] ?? '').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      status: (json['status'] ?? '').toString(),
      method: (json['method'] ?? '').toString(),
      refundId: (json['refundId'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      creditedToWallet: json['creditedToWallet'] as bool? ?? false,
      processedAt: processed == null ? null : DateTime.tryParse(processed),
      createdAt: created == null ? null : DateTime.tryParse(created),
    );
  }
}

/// `GET /food/user/refunds` → `{ totalRefunded, refunds, pagination }`.
class RefundHistory {
  final double totalRefunded;
  final List<RefundEntry> refunds;
  final int totalPages;

  const RefundHistory({this.totalRefunded = 0, this.refunds = const [], this.totalPages = 1});

  factory RefundHistory.fromApi(Map<String, dynamic> json) {
    final pagination = (json['pagination'] as Map?)?.cast<String, dynamic>() ?? const {};
    return RefundHistory(
      totalRefunded: (json['totalRefunded'] as num?)?.toDouble() ?? 0.0,
      refunds: ((json['refunds'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => RefundEntry.fromApi(e.cast<String, dynamic>()))
          .toList(),
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
    );
  }
}

/// `GET /food/admin/cashback-settings/public` — no auth required.
class CashbackSettings {
  final bool isEnabled;
  final String cashbackType;
  final double cashbackValue;
  final double minOrderValue;
  final double maxCashback;

  const CashbackSettings({
    this.isEnabled = false,
    this.cashbackType = 'percentage',
    this.cashbackValue = 0,
    this.minOrderValue = 0,
    this.maxCashback = 0,
  });

  /// "Get 10% cashback up to ₹50 on orders above ₹200" — built from live
  /// settings only; never shown when disabled.
  String get bannerText {
    final value = cashbackType == 'percentage' ? '${cashbackValue.toStringAsFixed(0)}%' : '₹${cashbackValue.toStringAsFixed(0)}';
    return 'Get $value cashback up to ₹${maxCashback.toStringAsFixed(0)} on orders above ₹${minOrderValue.toStringAsFixed(0)}';
  }

  factory CashbackSettings.fromApi(Map<String, dynamic> json) {
    final settings = (json['cashbackSettings'] as Map?)?.cast<String, dynamic>() ?? json;
    return CashbackSettings(
      isEnabled: settings['isEnabled'] as bool? ?? false,
      cashbackType: (settings['cashbackType'] ?? 'percentage').toString(),
      cashbackValue: (settings['cashbackValue'] as num?)?.toDouble() ?? 0.0,
      minOrderValue: (settings['minOrderValue'] as num?)?.toDouble() ?? 0.0,
      maxCashback: (settings['maxCashback'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// One invited friend from `GET /food/user/referrals/details`.
class ReferralInvite {
  final String id;
  final String name;

  /// Server-masked, e.g. `98****3210`.
  final String phone;
  final String profileImage;

  /// `credited` | `pending` | `rejected`
  final String status;
  final String? reason;
  final double earnedAmount;
  final DateTime? invitedAt;

  const ReferralInvite({
    required this.id,
    required this.name,
    required this.phone,
    required this.profileImage,
    required this.status,
    this.reason,
    this.earnedAmount = 0,
    this.invitedAt,
  });

  factory ReferralInvite.fromApi(Map<String, dynamic> json) {
    final raw = json['invitedAt']?.toString();
    final image = json['profileImage']?.toString();
    return ReferralInvite(
      id: (json['id'] ?? json['refereeId'] ?? '').toString(),
      name: (json['name'] ?? 'Friend').toString(),
      phone: (json['phone'] ?? '').toString(),
      profileImage: ApiConfig.resolveMedia(image),
      status: (json['status'] ?? '').toString(),
      reason: json['reason']?.toString(),
      earnedAmount: (json['earnedAmount'] as num?)?.toDouble() ?? 0.0,
      invitedAt: raw == null ? null : DateTime.tryParse(raw),
    );
  }
}

/// `GET /food/user/referrals/details`.
class ReferralDetails {
  final int referralCount;
  final double totalEarnings;
  final double rewardAmount;
  final int totalInvited;
  final int creditedCount;
  final int pendingCount;
  final int rejectedCount;
  final List<ReferralInvite> invitedFriends;

  /// The user's unique referral code (e.g. "TANU25").
  final String referralCode;

  /// A shareable deep-link URL, if the backend provides one.
  final String referralLink;

  /// A pre-composed share message from the backend, or empty string.
  final String shareText;

  const ReferralDetails({
    this.referralCount = 0,
    this.totalEarnings = 0,
    this.rewardAmount = 0,
    this.totalInvited = 0,
    this.creditedCount = 0,
    this.pendingCount = 0,
    this.rejectedCount = 0,
    this.invitedFriends = const [],
    this.referralCode = '',
    this.referralLink = '',
    this.shareText = '',
  });

  factory ReferralDetails.fromApi(Map<String, dynamic> json) {
    final dataMap = (json['data'] as Map?)?.cast<String, dynamic>() ?? json;
    final stats = (dataMap['stats'] as Map?)?.cast<String, dynamic>() ??
        (json['stats'] as Map?)?.cast<String, dynamic>() ??
        const {};

    final invitesRaw = dataMap['invitedFriends'] ??
        dataMap['referralHistory'] ??
        dataMap['history'] ??
        json['invitedFriends'] ??
        json['referralHistory'];

    return ReferralDetails(
      referralCount: (stats['referralCount'] ?? dataMap['referralCount'] ?? stats['totalReferrals'] as num?)?.toInt() ?? 0,
      totalEarnings: (stats['totalReferralEarnings'] ?? stats['totalEarnings'] ?? dataMap['totalEarnings'] ?? dataMap['totalReferralEarnings'] as num?)?.toDouble() ?? 0.0,
      rewardAmount: (stats['rewardAmount'] ?? dataMap['rewardAmount'] ?? stats['referralReward'] as num?)?.toDouble() ?? 0.0,
      totalInvited: (stats['totalInvited'] ?? dataMap['totalInvited'] ?? stats['referralCount'] as num?)?.toInt() ?? 0,
      creditedCount: (stats['creditedCount'] ?? dataMap['creditedCount'] as num?)?.toInt() ?? 0,
      pendingCount: (stats['pendingCount'] ?? dataMap['pendingCount'] as num?)?.toInt() ?? 0,
      rejectedCount: (stats['rejectedCount'] ?? dataMap['rejectedCount'] as num?)?.toInt() ?? 0,
      invitedFriends: ((invitesRaw as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ReferralInvite.fromApi(e.cast<String, dynamic>()))
          .toList(),
      referralCode: (dataMap['referralCode'] ?? json['referralCode'] ?? stats['referralCode'] ?? dataMap['code'] ?? '').toString(),
      referralLink: (dataMap['referralLink'] ?? json['referralLink'] ?? dataMap['link'] ?? json['link'] ?? '').toString(),
      shareText: (dataMap['shareText'] ?? json['shareText'] ?? dataMap['message'] ?? json['message'] ?? '').toString(),
    );
  }
}

/// One row of `GET /food/notifications/inbox`.
class AppNotification {
  final String id;
  final String title;
  final String message;

  /// Deep link, e.g. `/food/user/orders/<id>`.
  final String? link;
  final String category;
  final bool isRead;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    this.link,
    this.category = '',
    this.isRead = false,
    this.createdAt,
  });

  factory AppNotification.fromApi(Map<String, dynamic> json) {
    final raw = json['createdAt']?.toString();
    return AppNotification(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      link: json['link']?.toString(),
      category: (json['category'] ?? '').toString(),
      isRead: json['isRead'] as bool? ?? false,
      createdAt: raw == null ? null : DateTime.tryParse(raw),
    );
  }
}
