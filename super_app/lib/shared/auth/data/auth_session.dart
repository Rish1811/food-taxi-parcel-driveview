import 'package:superapp_user/shared/profile/data/user_model.dart';

/// Result of `POST /food/auth/user/verify-otp`.
///
/// The backend has no "does this phone exist" endpoint — account creation is
/// implicit at OTP verification, and [isNewUser] is how the server tells us the
/// account has no usable name yet. That flag is what drives the profile-completion
/// steps after login.
class AuthSession {
  final String accessToken;
  final String refreshToken;
  final UserModel user;
  final bool isNewUser;

  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.isNewUser,
  });

  /// True when we still need to collect profile details before landing the
  /// user on the home screen.
  bool get needsProfileSetup => isNewUser || !user.isProfileComplete;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      user: UserModel.fromJson((json['user'] as Map).cast<String, dynamic>()),
      isNewUser: json['isNewUser'] as bool? ?? false,
    );
  }
}
