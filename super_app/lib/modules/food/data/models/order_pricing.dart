/// Server-computed bill from `POST /food/orders/calculate`.
///
/// Pricing is server-owned: never compute or adjust these numbers client-side.
/// The same object is echoed straight back into `POST /food/orders`.
class OrderPricing {
  final double subtotal;
  final double tax;
  final double packagingFee;
  final double deliveryFee;
  final double deliveryFeeGst;
  final double platformFee;
  final double quickDeliveryFee;
  final double discount;
  final double total;

  /// Percentages behind [tax] and [deliveryFeeGst], for labelling bill rows.
  /// 0 when the server did not send them (older backend).
  final double gstRate;
  final double deliveryFeeGstRate;
  final String currency;
  final String deliveryMode;
  final String? couponCode;

  /// Null when a coupon was rejected — `couponCode` is echoed back either way,
  /// so this is the only reliable "did the discount land" signal.
  final Map<String, dynamic>? appliedCoupon;

  final double? roadDistanceKm;

  /// Verbatim server payload, echoed into order creation unchanged.
  final Map<String, dynamic> raw;

  const OrderPricing({
    required this.subtotal,
    required this.tax,
    required this.packagingFee,
    required this.deliveryFee,
    required this.deliveryFeeGst,
    required this.platformFee,
    required this.quickDeliveryFee,
    required this.discount,
    required this.total,
    this.gstRate = 0,
    this.deliveryFeeGstRate = 0,
    required this.currency,
    required this.deliveryMode,
    this.couponCode,
    this.appliedCoupon,
    this.roadDistanceKm,
    this.raw = const {},
  });

  /// True once a coupon actually landed — checked against `discount`/
  /// `couponCode` too, not just `appliedCoupon`, since a backend that omits
  /// the nested `appliedCoupon` object but still returns a real `discount`
  /// and `couponCode` should still read as "applied" rather than silently
  /// showing no discount.
  bool get hasCouponApplied =>
      appliedCoupon != null ||
      ((couponCode?.isNotEmpty ?? false) && discount > 0);

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  factory OrderPricing.fromApi(Map<String, dynamic> json) {
    final appliedCoupon = (json['appliedCoupon'] as Map?)?.cast<String, dynamic>();
    return OrderPricing(
      subtotal: _d(json['subtotal']),
      tax: _d(json['tax']),
      packagingFee: _d(json['packagingFee']),
      deliveryFee: _d(json['deliveryFee']),
      deliveryFeeGst: _d(json['deliveryFeeGst']),
      platformFee: _d(json['platformFee']),
      quickDeliveryFee: _d(json['quickDeliveryFee']),
      // Same discount, different key across backend responses — mirrors the
      // fallback chain OrderModel already uses for a placed order's pricing.
      discount: _d(
        json['discount'] ?? json['discountAmount'] ?? json['couponDiscount'],
      ),
      total: _d(json['total'] ?? json['finalAmount'] ?? json['totalPayable']),
      gstRate: _d(json['gstRate']),
      deliveryFeeGstRate: _d(json['deliveryFeeGstRate']),
      currency: (json['currency'] ?? 'INR').toString(),
      deliveryMode: (json['deliveryMode'] ?? 'basic').toString(),
      couponCode: (json['couponCode'] ?? appliedCoupon?['code'])?.toString(),
      appliedCoupon: appliedCoupon,
      roadDistanceKm: (json['roadDistanceKm'] as num?)?.toDouble(),
      raw: json,
    );
  }
}

/// A menu price that moved between adding to cart and checking out.
///
/// Non-empty `priceChanges` must be confirmed by the user before the order is
/// submitted — that is the entire reason the backend returns it.
class PriceChange {
  final String itemId;
  final String name;
  final double previousPrice;
  final double price;

  const PriceChange({
    required this.itemId,
    required this.name,
    required this.previousPrice,
    required this.price,
  });

  factory PriceChange.fromApi(Map<String, dynamic> json) {
    return PriceChange(
      itemId: (json['itemId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      previousPrice: (json['previousPrice'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Full `/calculate` result: authoritative items, price drift, and the bill.
class OrderCalculation {
  final List<Map<String, dynamic>> items;
  final List<PriceChange> priceChanges;
  final OrderPricing pricing;

  const OrderCalculation({
    required this.items,
    required this.priceChanges,
    required this.pricing,
  });

  bool get hasPriceChanges => priceChanges.isNotEmpty;

  factory OrderCalculation.fromApi(Map<String, dynamic> json) {
    return OrderCalculation(
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      priceChanges: ((json['priceChanges'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => PriceChange.fromApi(e.cast<String, dynamic>()))
          .toList(),
      pricing: OrderPricing.fromApi(
        ((json['pricing'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
    );
  }
}
