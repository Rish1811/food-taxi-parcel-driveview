class RentalPricingModel {
  final String id;
  final String label;
  final int durationHours;
  final double price;
  final int includedKm;
  final double extraHourPrice;
  final double extraKmPrice;

  const RentalPricingModel({
    required this.id,
    required this.label,
    required this.durationHours,
    required this.price,
    required this.includedKm,
    required this.extraHourPrice,
    required this.extraKmPrice,
  });

  factory RentalPricingModel.fromJson(Map<String, dynamic> json) {
    return RentalPricingModel(
      id: (json['id'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      durationHours: int.tryParse('${json['durationHours'] ?? 0}') ?? 0,
      price: double.tryParse('${json['price'] ?? 0}') ?? 0,
      includedKm: int.tryParse('${json['includedKm'] ?? 0}') ?? 0,
      extraHourPrice: double.tryParse('${json['extraHourPrice'] ?? 0}') ?? 0,
      extraKmPrice: double.tryParse('${json['extraKmPrice'] ?? 0}') ?? 0,
    );
  }
}

class RentalAdvancePaymentModel {
  final bool enabled;
  final String paymentMode;
  final double amount;
  final String label;

  const RentalAdvancePaymentModel({
    this.enabled = false,
    this.paymentMode = 'percentage',
    this.amount = 0,
    this.label = 'Advance booking payment',
  });

  factory RentalAdvancePaymentModel.fromJson(Map<String, dynamic> json) {
    return RentalAdvancePaymentModel(
      enabled: json['enabled'] == true,
      paymentMode: (json['paymentMode'] ?? 'percentage').toString(),
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      label: (json['label'] ?? 'Advance booking payment').toString(),
    );
  }

  double payableNowFor(double totalCost) {
    if (!enabled) return 0;
    switch (paymentMode) {
      case 'full':
        return totalCost;
      case 'fixed':
        return amount.clamp(0, totalCost);
      case 'percentage':
      default:
        return (totalCost * amount / 100).clamp(0, totalCost);
    }
  }
}

class RentalVehicleModel {
  final String id;
  final String name;
  final String shortDescription;
  final String vehicleCategory;
  final String image;
  final int capacity;
  final List<RentalPricingModel> pricing;
  final RentalAdvancePaymentModel advancePayment;

  const RentalVehicleModel({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.vehicleCategory,
    required this.image,
    required this.capacity,
    required this.pricing,
    required this.advancePayment,
  });

  factory RentalVehicleModel.fromJson(Map<String, dynamic> json) {
    final pricingList = (json['pricing'] as List? ?? []);
    return RentalVehicleModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      shortDescription: (json['short_description'] ?? '').toString(),
      vehicleCategory: (json['vehicleCategory'] ?? 'Car').toString(),
      image: (json['image'] ?? '').toString(),
      capacity: int.tryParse('${json['capacity'] ?? 0}') ?? 1,
      pricing: pricingList.map((e) => RentalPricingModel.fromJson(Map<String, dynamic>.from(e))).toList(),
      advancePayment: json['advancePayment'] is Map
          ? RentalAdvancePaymentModel.fromJson(Map<String, dynamic>.from(json['advancePayment']))
          : const RentalAdvancePaymentModel(),
    );
  }
}
