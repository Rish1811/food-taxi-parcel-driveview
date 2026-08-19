import 'delivery_partner.dart';

/// The 3-branch payload returned by `POST /food/auth/delivery/verify-otp`.
/// Always arrives with HTTP 200 — callers must branch on these fields,
/// not the status code.
class AuthVerifyResult {
  const AuthVerifyResult({
    required this.needsRegistration,
    required this.pendingApproval,
    required this.isRejected,
    this.phone,
    this.rejectionReason,
    this.accessToken,
    this.refreshToken,
    this.user,
  });

  final bool needsRegistration;
  final bool pendingApproval;
  final bool isRejected;
  final String? phone;
  final String? rejectionReason;
  final String? accessToken;
  final String? refreshToken;
  final DeliveryPartner? user;

  bool get isLoggedIn => accessToken != null && accessToken!.isNotEmpty;

  factory AuthVerifyResult.fromJson(Map<String, dynamic> json) {
    return AuthVerifyResult(
      needsRegistration: json['needsRegistration'] == true,
      pendingApproval: json['pendingApproval'] == true,
      isRejected: json['isRejected'] == true,
      phone: json['phone'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      user: json['user'] != null
          ? DeliveryPartner.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }
}
