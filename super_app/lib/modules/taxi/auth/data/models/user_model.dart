class TaxiUserModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String gender;
  final String? currentRideId;
  final String? profileImage;
  final String? referralCode;
  final int referralCount;

  const TaxiUserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.gender,
    this.currentRideId,
    this.profileImage,
    this.referralCode,
    this.referralCount = 0,
  });

  factory TaxiUserModel.fromJson(Map<String, dynamic> json) {
    return TaxiUserModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      currentRideId: json['currentRideId']?.toString(),
      profileImage: json['profileImage']?.toString() ?? json['profile_image']?.toString(),
      referralCode: json['referralCode']?.toString(),
      referralCount: int.tryParse('${json['referralCount'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'gender': gender,
        'currentRideId': currentRideId,
        'profileImage': profileImage,
        'referralCode': referralCode,
        'referralCount': referralCount,
      };

  TaxiUserModel copyWith({
    String? name,
    String? email,
    String? gender,
    String? currentRideId,
    String? profileImage,
  }) {
    return TaxiUserModel(
      id: id,
      name: name ?? this.name,
      phone: phone,
      email: email ?? this.email,
      gender: gender ?? this.gender,
      currentRideId: currentRideId ?? this.currentRideId,
      profileImage: profileImage ?? this.profileImage,
      referralCode: referralCode,
      referralCount: referralCount,
    );
  }
}
