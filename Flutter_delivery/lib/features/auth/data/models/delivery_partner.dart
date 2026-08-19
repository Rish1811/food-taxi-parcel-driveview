class DeliveryPartner {
  const DeliveryPartner({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    this.email,
    this.countryCode,
    this.address,
    this.city,
    this.state,
    this.vehicleType,
    this.vehicleName,
    this.vehicleNumber,
    this.panNumber,
    this.aadharNumber,
    this.drivingLicenseNumber,
    this.profilePhoto,
    this.aadharPhoto,
    this.panPhoto,
    this.drivingLicensePhoto,
    this.rejectionReason,
    this.bankAccountHolderName,
    this.bankAccountNumber,
    this.bankIfscCode,
    this.bankName,
    this.upiId,
    this.upiQrCode,
    this.availabilityStatus,
    this.lastLat,
    this.lastLng,
    this.referralCode,
    this.referralCount,
    this.rating,
    this.totalRatings,
  });

  final String id;
  final String name;
  final String phone;
  final String status; // pending | approved | rejected | deactivated
  final String? email;
  final String? countryCode;
  final String? address;
  final String? city;
  final String? state;
  final String? vehicleType;
  final String? vehicleName;
  final String? vehicleNumber;
  final String? panNumber;
  final String? aadharNumber;
  final String? drivingLicenseNumber;
  final String? profilePhoto;
  final String? aadharPhoto;
  final String? panPhoto;
  final String? drivingLicensePhoto;
  final String? rejectionReason;
  final String? bankAccountHolderName;
  final String? bankAccountNumber;
  final String? bankIfscCode;
  final String? bankName;
  final String? upiId;
  final String? upiQrCode;
  final String? availabilityStatus;
  final double? lastLat;
  final double? lastLng;
  final String? referralCode;
  final int? referralCount;
  final double? rating;
  final int? totalRatings;

  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isPending => status == 'pending';
  bool get isDeactivated => status == 'deactivated';
  bool get isOnline => availabilityStatus == 'online';

  factory DeliveryPartner.fromJson(Map<String, dynamic> json) {
    return DeliveryPartner(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      email: json['email'] as String?,
      countryCode: json['countryCode'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      vehicleType: json['vehicleType'] as String?,
      vehicleName: json['vehicleName'] as String?,
      vehicleNumber: json['vehicleNumber'] as String?,
      panNumber: json['panNumber'] as String?,
      aadharNumber: json['aadharNumber'] as String?,
      drivingLicenseNumber: json['drivingLicenseNumber'] as String?,
      profilePhoto: json['profilePhoto'] as String?,
      aadharPhoto: json['aadharPhoto'] as String?,
      panPhoto: json['panPhoto'] as String?,
      drivingLicensePhoto: json['drivingLicensePhoto'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      bankAccountHolderName: json['bankAccountHolderName'] as String?,
      bankAccountNumber: json['bankAccountNumber'] as String?,
      bankIfscCode: json['bankIfscCode'] as String?,
      bankName: json['bankName'] as String?,
      upiId: json['upiId'] as String?,
      upiQrCode: json['upiQrCode'] as String?,
      availabilityStatus: json['availabilityStatus'] as String?,
      lastLat: (json['lastLat'] as num?)?.toDouble(),
      lastLng: (json['lastLng'] as num?)?.toDouble(),
      referralCode: json['referralCode'] as String?,
      referralCount: (json['referralCount'] as num?)?.toInt(),
      rating: (json['rating'] as num?)?.toDouble(),
      totalRatings: (json['totalRatings'] as num?)?.toInt(),
    );
  }

  DeliveryPartner copyWith({String? availabilityStatus}) {
    return DeliveryPartner(
      id: id,
      name: name,
      phone: phone,
      status: status,
      email: email,
      countryCode: countryCode,
      address: address,
      city: city,
      state: state,
      vehicleType: vehicleType,
      vehicleName: vehicleName,
      vehicleNumber: vehicleNumber,
      panNumber: panNumber,
      aadharNumber: aadharNumber,
      drivingLicenseNumber: drivingLicenseNumber,
      profilePhoto: profilePhoto,
      aadharPhoto: aadharPhoto,
      panPhoto: panPhoto,
      drivingLicensePhoto: drivingLicensePhoto,
      rejectionReason: rejectionReason,
      bankAccountHolderName: bankAccountHolderName,
      bankAccountNumber: bankAccountNumber,
      bankIfscCode: bankIfscCode,
      bankName: bankName,
      upiId: upiId,
      upiQrCode: upiQrCode,
      availabilityStatus: availabilityStatus ?? this.availabilityStatus,
      lastLat: lastLat,
      lastLng: lastLng,
      referralCode: referralCode,
      referralCount: referralCount,
      rating: rating,
      totalRatings: totalRatings,
    );
  }
}
