import 'package:dio/dio.dart';

import 'package:superapp_user/core/config/api_config.dart';
import 'package:superapp_user/core/network/api_client.dart';
import 'package:superapp_user/shared/auth/data/auth_session.dart';
import 'package:superapp_user/shared/profile/data/user_model.dart';

/// Thin transport layer for `/food/auth` and the profile half of `/food/user`.
///
/// No business logic here — it maps endpoints to models and lets [ApiClient]
/// throw typed failures upward.
class AuthRemoteDataSource {
  final ApiClient _client;

  const AuthRemoteDataSource(this._client);

  /// `POST /food/auth/user/request-otp` — phone is digits only, 8–15 chars.
  ///
  /// Returns the OTP when the backend is in dev mode (it echoes `otp` in the
  /// payload), otherwise null. Used to prefill the field on staging builds.
  Future<String?> requestOtp(String phone) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiPaths.requestOtp,
      body: {'phone': phone},
      auth: false,
    );
    return data['otp']?.toString();
  }

  /// `POST /food/auth/user/verify-otp` — creates the account if it's new.
  Future<AuthSession> verifyOtp({
    required String phone,
    required String otp,
    String? name,
    String? referralCode,
    String? fcmToken,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiPaths.verifyOtp,
      body: {
        'phone': phone,
        'otp': otp,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (referralCode != null && referralCode.isNotEmpty) 'ref': referralCode,
        if (fcmToken != null && fcmToken.isNotEmpty) ...{
          'fcmToken': fcmToken,
          'platform': 'mobile',
        },
      },
      auth: false,
    );
    return AuthSession.fromJson(data);
  }

  /// `GET /food/user/profile` → `{ user }`
  Future<UserModel> getProfile() async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.profile);
    return UserModel.fromJson((data['user'] as Map).cast<String, dynamic>());
  }

  /// `PATCH /food/user/profile` — every field optional.
  Future<UserModel> updateProfile(Map<String, dynamic> payload) async {
    final data = await _client.patch<Map<String, dynamic>>(ApiPaths.profile, body: payload);
    return UserModel.fromJson((data['user'] as Map).cast<String, dynamic>());
  }

  /// `POST /food/user/profile/profile-image` — multipart, field name `file`.
  ///
  /// The server stores the file and writes the resulting URL to the user's
  /// profileImage, returning it. This is the ONLY way to set an avatar: the
  /// profile PATCH takes a URL, so handing it a local device path just stored a
  /// string that no client could ever load.
  Future<String> uploadProfileImage(String filePath) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });
    final data = await _client.post<Map<String, dynamic>>(
      ApiPaths.profileImage,
      body: form,
    );
    final url = (data['profileImage'] ??
            (data['user'] is Map ? (data['user'] as Map)['profileImage'] : null))
        ?.toString();
    if (url == null || url.isEmpty) {
      throw StateError('Upload succeeded but returned no image URL');
    }
    // The server returns a RELATIVE path (/uploads/...) whenever no absolute
    // upload base URL is configured, so nginx can serve it per environment.
    // UserModel.fromJson already resolves it on read; without doing the same here
    // the optimistic UI update would hold a path Image.network cannot load, and
    // the new photo would only appear after a full profile refetch.
    return ApiConfig.resolveMedia(url);
  }

  /// `POST /food/auth/logout` — invalidates the refresh token server-side and
  /// unregisters the push token. Best-effort: the caller clears local state
  /// regardless of the outcome.
  Future<void> logout({String? refreshToken, String? fcmToken}) async {
    await _client.post<dynamic>(
      ApiPaths.logout,
      body: {
        'refreshToken': ?refreshToken,
        if (fcmToken != null && fcmToken.isNotEmpty) ...{
          'fcmToken': fcmToken,
          'platform': 'mobile',
        },
      },
    );
  }
}
