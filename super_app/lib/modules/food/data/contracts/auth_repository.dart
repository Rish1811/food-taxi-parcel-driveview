import 'package:superapp_user/core/network/api_response.dart';
import 'package:superapp_user/shared/auth/data/auth_session.dart';
import 'package:superapp_user/shared/profile/data/user_model.dart';

/// Phone-first authentication, matching what the backend actually exposes.
///
/// There is no "check if phone exists" endpoint — the account is created
/// implicitly at OTP verification and the server reports `isNewUser` back.
/// Callers branch on [AuthSession.needsProfileSetup] to decide whether to run
/// the profile-completion steps.
abstract class AuthRepository {
  /// Sends an OTP. Returns the code itself only on dev builds where the
  /// backend echoes it; null in production.
  Future<ApiResponse<String?>> requestOtp(String phone);

  /// Verifies the OTP, persists the token pair, and returns the session.
  Future<ApiResponse<AuthSession>> verifyOtp({
    required String phone,
    required String otp,
    String? name,
    String? referralCode,
    String? fcmToken,
  });

  /// Current user for the stored token, or an error if there's no session.
  Future<ApiResponse<UserModel>> getProfile();

  Future<ApiResponse<UserModel>> updateProfile({
    String? name,
    String? email,
    String? gender,
    String? dateOfBirth,
    String? anniversary,
  });

  /// Restores a session on cold start. Returns null data when the user is a guest.
  Future<ApiResponse<UserModel?>> restoreSession();

  /// Clears the session locally and, best-effort, server-side.
  Future<ApiResponse<void>> logout({String? fcmToken});

  Future<bool> get hasSession;
}
