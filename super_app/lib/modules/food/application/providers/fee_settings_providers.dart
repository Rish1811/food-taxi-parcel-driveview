import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/config/api_config.dart';
import 'package:superapp_user/core/network/network_providers.dart';

/// Order-level fee rules the checkout has to respect.
///
/// Currently just the COD ceiling, which the server enforces in
/// `order.service.js`:
///
/// ```js
/// if (codOrderLimit != null && pricing.total >= codOrderLimit) {
///   throw new ValidationError(`Cash on Delivery is not allowed for orders of ₹${codOrderLimit} or more.`);
/// }
/// ```
///
/// Fetching it lets the cart disable the option up front instead of letting
/// the user pick COD, tap Place order, and get rejected.
class FeeSettings {
  const FeeSettings({this.codOrderLimit});

  /// Orders at or above this total cannot be paid in cash. Null means no ceiling.
  final num? codOrderLimit;

  bool allowsCodFor(num total) =>
      codOrderLimit == null || total < codOrderLimit!;

  factory FeeSettings.fromJson(Map<String, dynamic> json) =>
      FeeSettings(codOrderLimit: json['codOrderLimit'] as num?);

  static const empty = FeeSettings();
}

/// Cached for an hour — this is admin-managed configuration, not live data.
/// Failures resolve to [FeeSettings.empty] rather than throwing: an unreachable
/// settings endpoint must not block checkout, and the server still enforces the
/// rule regardless of what the client believes.
final feeSettingsProvider = FutureProvider<FeeSettings>((ref) async {
  try {
    final data = await ref.watch(apiClientProvider).get<Map<String, dynamic>>(
          ApiPaths.feeSettings,
          cacheTtl: const Duration(hours: 1),
        );
    return FeeSettings.fromJson(data);
  } catch (_) {
    return FeeSettings.empty;
  }
});
