import 'package:superapp_user/core/config/api_config.dart';

/// The authenticated user, mapped from `GET /food/user/profile` and the
/// `verify-otp` response (both return the same document).
///
/// Field names match what the existing screens already read. Values that the
/// backend owns elsewhere (wallet balance) default to zero rather than a
/// hardcoded figure — the wallet endpoint supplies the real number.
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phone;
  final String countryCode;

  /// Absolute URL — relative `/uploads/...` paths are resolved on parse.
  final String? avatarUrl;

  final String gender;
  final String? dateOfBirth;
  final String? anniversary;

  final String referralCode;
  final String? referredBy;
  final int referralCount;

  final bool isVerified;
  final bool isActive;
  final String role;

  /// Supplied by `GET /food/user/wallet`, not by the user document.
  final double walletBalance;

  const UserModel({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone,
    this.countryCode = '+91',
    this.avatarUrl,
    this.gender = '',
    this.dateOfBirth,
    this.anniversary,
    this.referralCode = '',
    this.referredBy,
    this.referralCount = 0,
    this.isVerified = false,
    this.isActive = true,
    this.role = 'USER',
    this.walletBalance = 0.0,
  });

  /// A brand-new account comes back with no usable name — that's what drives
  /// the "complete your profile" step after OTP.
  bool get isProfileComplete => name.trim().isNotEmpty;

  String get displayName => name.trim().isNotEmpty ? name.trim() : 'Guest';

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? countryCode,
    String? avatarUrl,
    String? gender,
    String? dateOfBirth,
    String? anniversary,
    String? referralCode,
    String? referredBy,
    int? referralCount,
    bool? isVerified,
    bool? isActive,
    String? role,
    double? walletBalance,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      countryCode: countryCode ?? this.countryCode,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      anniversary: anniversary ?? this.anniversary,
      referralCode: referralCode ?? this.referralCode,
      referredBy: referredBy ?? this.referredBy,
      referralCount: referralCount ?? this.referralCount,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      role: role ?? this.role,
      walletBalance: walletBalance ?? this.walletBalance,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final image = json['profileImage'];
    // profileImage is a plain string on the user doc, but the API wraps images
    // as { url } elsewhere — accept both so this never bites.
    final imageUrl = image is Map ? image['url'] as String? : image as String?;

    return UserModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] as String?)?.trim() ?? '',
      email: (json['email'] as String?)?.trim() ?? '',
      phone: json['phone'] as String?,
      countryCode: json['countryCode'] as String? ?? '+91',
      avatarUrl: (imageUrl == null || imageUrl.isEmpty) ? null : ApiConfig.resolveMedia(imageUrl),
      gender: json['gender'] as String? ?? '',
      dateOfBirth: json['dateOfBirth'] as String?,
      anniversary: json['anniversary'] as String?,
      referralCode: (json['referralCode'] ?? '').toString(),
      referredBy: json['referredBy']?.toString(),
      referralCount: (json['referralCount'] as num?)?.toInt() ?? 0,
      isVerified: json['isVerified'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      role: json['role'] as String? ?? 'USER',
    );
  }

  /// Only the fields `PATCH /food/user/profile` accepts. Nulls are omitted so
  /// a partial edit never blanks out untouched fields.
  Map<String, dynamic> toUpdatePayload() {
    final map = <String, dynamic>{};
    if (name.isNotEmpty) map['name'] = name;
    if (email.isNotEmpty) map['email'] = email;
    if (gender.isNotEmpty) map['gender'] = gender;
    if (dateOfBirth != null) map['dateOfBirth'] = dateOfBirth;
    if (anniversary != null) map['anniversary'] = anniversary;
    return map;
  }
}
