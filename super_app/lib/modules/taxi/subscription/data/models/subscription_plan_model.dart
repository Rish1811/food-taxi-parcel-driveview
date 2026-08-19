class SubscriptionPlanModel {
  final String id;
  final String name;
  final String description;
  final double amount;
  final int durationDays;
  final String benefitType;
  final int rideLimit;
  final String howItWorks;
  final String vehicleTypeName;

  const SubscriptionPlanModel({
    required this.id,
    required this.name,
    required this.description,
    required this.amount,
    required this.durationDays,
    required this.benefitType,
    required this.rideLimit,
    required this.howItWorks,
    required this.vehicleTypeName,
  });

  bool get isUnlimited => benefitType == 'unlimited';

  factory SubscriptionPlanModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlanModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      durationDays: int.tryParse('${json['duration'] ?? 0}') ?? 0,
      benefitType: (json['benefit_type'] ?? 'limited').toString(),
      rideLimit: int.tryParse('${json['ride_limit'] ?? 0}') ?? 0,
      howItWorks: (json['how_it_works'] ?? '').toString(),
      vehicleTypeName: (json['vehicle_type'] is Map ? json['vehicle_type']['name'] : '')?.toString() ?? '',
    );
  }
}

class UserSubscriptionModel {
  final String id;
  final String planId;
  final String name;
  final String description;
  final double amount;
  final int durationDays;
  final String benefitType;
  final int rideLimit;
  final int ridesUsed;
  final int? ridesRemaining;
  final bool isUnlimited;
  final String status;
  final bool active;
  final DateTime? purchasedAt;
  final DateTime? expiresAt;

  const UserSubscriptionModel({
    required this.id,
    required this.planId,
    required this.name,
    required this.description,
    required this.amount,
    required this.durationDays,
    required this.benefitType,
    required this.rideLimit,
    required this.ridesUsed,
    required this.ridesRemaining,
    required this.isUnlimited,
    required this.status,
    required this.active,
    required this.purchasedAt,
    required this.expiresAt,
  });

  factory UserSubscriptionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    return UserSubscriptionModel(
      id: (json['id'] ?? '').toString(),
      planId: (json['planId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      amount: double.tryParse('${json['amount'] ?? 0}') ?? 0,
      durationDays: int.tryParse('${json['durationDays'] ?? 0}') ?? 0,
      benefitType: (json['benefit_type'] ?? 'limited').toString(),
      rideLimit: int.tryParse('${json['ride_limit'] ?? 0}') ?? 0,
      ridesUsed: int.tryParse('${json['rides_used'] ?? 0}') ?? 0,
      ridesRemaining: json['rides_remaining'] == null ? null : int.tryParse('${json['rides_remaining']}'),
      isUnlimited: json['isUnlimited'] == true,
      status: (json['status'] ?? 'active').toString(),
      active: json['active'] == true,
      purchasedAt: parseDate(json['purchasedAt']),
      expiresAt: parseDate(json['expiresAt']),
    );
  }
}

class SubscriptionSummaryModel {
  final int activeCount;
  final bool hasUnlimitedPlan;
  final int availableRideCredits;
  final List<UserSubscriptionModel> activePlans;
  final List<UserSubscriptionModel> history;

  const SubscriptionSummaryModel({
    required this.activeCount,
    required this.hasUnlimitedPlan,
    required this.availableRideCredits,
    required this.activePlans,
    required this.history,
  });

  factory SubscriptionSummaryModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionSummaryModel(
      activeCount: int.tryParse('${json['activeCount'] ?? 0}') ?? 0,
      hasUnlimitedPlan: json['hasUnlimitedPlan'] == true,
      availableRideCredits: int.tryParse('${json['availableRideCredits'] ?? 0}') ?? 0,
      activePlans: ((json['activePlans'] as List?) ?? [])
          .map((e) => UserSubscriptionModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      history: ((json['history'] as List?) ?? [])
          .map((e) => UserSubscriptionModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
