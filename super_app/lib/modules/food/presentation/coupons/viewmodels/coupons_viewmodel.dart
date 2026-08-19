import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/application/providers/catalog_providers.dart';

/// A coupon from `GET /food/restaurant/offers`.
///
/// The backend prebuilds `title` (e.g. "20% OFF" / "Flat ₹100 OFF"), so the UI
/// renders it verbatim rather than re-deriving copy from discountType/value.
class CouponModel {
  final String id;
  final String code;
  final String discountText;
  final String description;
  final double minSpend;
  final String expiryDate;

  const CouponModel({
    required this.id,
    required this.code,
    required this.discountText,
    required this.description,
    required this.minSpend,
    required this.expiryDate,
  });

  factory CouponModel.fromApi(Map<String, dynamic> json) {
    final end = json['endDate']?.toString();
    return CouponModel(
      id: (json['id'] ?? json['offerId'] ?? '').toString(),
      code: (json['couponCode'] ?? '').toString(),
      discountText: (json['title'] ?? '').toString(),
      description: (json['restaurantName'] ?? '').toString(),
      minSpend: (json['minOrderValue'] as num?)?.toDouble() ?? 0.0,
      expiryDate: end == null ? '' : end.split('T').first,
    );
  }
}

/// Live coupon list. Sending the Bearer token (the client attaches it when a
/// session exists) makes the backend drop coupons the user has exhausted.
///
/// Falls back to an empty list on failure — like [restaurantAddonsProvider],
/// a coupon-fetch error must never crash whatever screen is showing the
/// coupon sheet.
final couponsProvider = FutureProvider<List<CouponModel>>((ref) async {
  try {
    final offers = await ref.watch(catalogRemoteDataSourceProvider).getOffers();
    return offers.map(CouponModel.fromApi).toList();
  } catch (_) {
    return const [];
  }
});

/// Sync view for widgets that just need the current list (empty until loaded).
final couponsViewModelProvider = Provider<List<CouponModel>>((ref) {
  return ref.watch(couponsProvider).value ?? const [];
});
