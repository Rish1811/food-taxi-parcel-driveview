import 'package:superapp_user/core/error/failures.dart';
import 'package:superapp_user/core/network/api_response.dart';
import 'package:superapp_user/core/storage/token_storage.dart';
import 'package:superapp_user/modules/food/data/contracts/auth_repository.dart';
import 'package:superapp_user/modules/food/api/datasources/auth_remote_datasource.dart';
import 'package:superapp_user/shared/auth/data/auth_session.dart';
import 'package:superapp_user/shared/profile/data/user_model.dart';

/// Backend-backed [AuthRepository].
///
/// Owns token persistence: verify-otp writes the pair, logout clears it. Every
/// typed [Failure] from the network layer is converted into the [ApiResponse]
/// envelope the presentation layer already consumes.
class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remote;
  final TokenStorage _tokens;

  const AuthRepositoryImpl(this._remote, this._tokens);

  @override
  Future<bool> get hasSession => _tokens.hasSession;

  @override
  Future<ApiResponse<String?>> requestOtp(String phone) async {
    return _guard(() async {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      // Ensure any unauthenticated session state is clean before starting OTP verification
      if (!await _tokens.hasSession) {
        await _tokens.clear();
      }
      final devOtp = await _remote.requestOtp(digits);
      return ApiResponse.success(devOtp, 'OTP sent');
    });
  }

  @override
  Future<ApiResponse<AuthSession>> verifyOtp({
    required String phone,
    required String otp,
    String? name,
    String? referralCode,
    String? fcmToken,
  }) async {
    return _guard(() async {
      final session = await _remote.verifyOtp(
        phone: phone.replaceAll(RegExp(r'\D'), ''),
        otp: otp,
        name: name,
        referralCode: referralCode,
        fcmToken: fcmToken,
      );
      await _tokens.save(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );
      return ApiResponse.success(session, 'Login successful');
    });
  }

  @override
  Future<ApiResponse<UserModel>> getProfile() =>
      _guard(() async => ApiResponse.success(await _remote.getProfile()));

  @override
  Future<ApiResponse<UserModel>> updateProfile({
    String? name,
    String? email,
    String? gender,
    String? dateOfBirth,
    String? anniversary,
  }) {
    return _guard(() async {
      final payload = <String, dynamic>{
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
        if (gender != null && gender.isNotEmpty) 'gender': gender,
        'dateOfBirth': ?dateOfBirth,
        'anniversary': ?anniversary,
      };
      if (payload.isEmpty) {
        return ApiResponse<UserModel>.error('Nothing to update');
      }
      return ApiResponse.success(await _remote.updateProfile(payload), 'Profile updated');
    });
  }

  @override
  Future<ApiResponse<UserModel?>> restoreSession() async {
    if (!await _tokens.hasSession) {
      return const ApiResponse.success(null);
    }
    // A 401 here is already handled by the client's refresh-then-logout path,
    // so reaching the error branch means the session is genuinely gone.
    final result = await getProfile();
    if (result.isSuccess) return ApiResponse.success(result.data);
    if (result.data == null) await _tokens.clear();
    return ApiResponse.success(null, result.message);
  }

  @override
  Future<ApiResponse<void>> logout({String? fcmToken}) async {
    final refresh = await _tokens.refreshToken;
    try {
      await _remote.logout(refreshToken: refresh, fcmToken: fcmToken);
    } catch (_) {
      // Server-side invalidation is best-effort — the local session must be
      // cleared either way, otherwise a network blip strands the user logged in.
    }
    await _tokens.clear();
    return const ApiResponse.success(null, 'Logged out');
  }

  /// Converts typed failures into the [ApiResponse] envelope callers expect.
  Future<ApiResponse<T>> _guard<T>(Future<ApiResponse<T>> Function() run) async {
    try {
      return await run();
    } on Failure catch (f) {
      return ApiResponse<T>.error(f.message);
    } catch (e) {
      return ApiResponse<T>.error('Something went wrong. Please try again.');
    }
  }
}
