class RentalBookingModel {
  final String id;
  final String bookingReference;
  final String vehicleName;
  final String vehicleImage;
  final String packageLabel;
  final DateTime? pickupDateTime;
  final DateTime? returnDateTime;
  final double totalCost;
  final double payableNow;
  final String paymentStatus;
  final String status;
  final DateTime? createdAt;

  const RentalBookingModel({
    required this.id,
    required this.bookingReference,
    required this.vehicleName,
    required this.vehicleImage,
    required this.packageLabel,
    required this.pickupDateTime,
    required this.returnDateTime,
    required this.totalCost,
    required this.payableNow,
    required this.paymentStatus,
    required this.status,
    required this.createdAt,
  });

  factory RentalBookingModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    final selectedPackage = (json['selectedPackage'] as Map?) ?? {};
    return RentalBookingModel(
      id: (json['id'] ?? '').toString(),
      bookingReference: (json['bookingReference'] ?? '').toString(),
      vehicleName: (json['vehicleName'] ?? '').toString(),
      vehicleImage: (json['vehicleImage'] ?? '').toString(),
      packageLabel: (selectedPackage['label'] ?? '').toString(),
      pickupDateTime: parseDate(json['pickupDateTime']),
      returnDateTime: parseDate(json['returnDateTime']),
      totalCost: double.tryParse('${json['totalCost'] ?? 0}') ?? 0,
      payableNow: double.tryParse('${json['payableNow'] ?? 0}') ?? 0,
      paymentStatus: (json['paymentStatus'] ?? 'pending').toString(),
      status: (json['status'] ?? 'pending').toString(),
      createdAt: parseDate(json['createdAt']),
    );
  }
}
