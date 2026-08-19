class PromoModel {
  final String id;
  final String code;
  final String title;
  final String description;
  final double? discountPercent;
  final double? discountFlat;
  final double? maxDiscount;
  final DateTime? expiresAt;

  const PromoModel({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    this.discountPercent,
    this.discountFlat,
    this.maxDiscount,
    this.expiresAt,
  });

  factory PromoModel.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) => v == null ? null : double.tryParse('$v');
    return PromoModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      title: (json['title'] ?? json['name'] ?? json['code'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      discountPercent: asDouble(json['discount_percent'] ?? json['discountPercent']),
      discountFlat: asDouble(json['discount_flat'] ?? json['discountFlat']),
      maxDiscount: asDouble(json['max_discount'] ?? json['maxDiscount']),
      expiresAt: json['expires_at'] != null || json['expiresAt'] != null
          ? DateTime.tryParse('${json['expires_at'] ?? json['expiresAt']}')
          : null,
    );
  }
}
