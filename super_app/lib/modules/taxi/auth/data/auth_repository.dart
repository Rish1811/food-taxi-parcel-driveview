import 'package:superapp_user/core/network/taxi_api_client.dart';
import 'package:superapp_user/modules/taxi/api/taxi_endpoints.dart';
import 'package:superapp_user/modules/taxi/auth/data/models/user_model.dart';

/// Ride-side account operations.
///
/// **This deliberately cannot sign anyone in.** The app has one login — the
/// shared `/auth/phone` + `/auth/otp` flow — and one session in [TokenStorage].
///
/// `sendOtp`, `verifyOtp`, `signup` and `getCurrentUser` used to live here and
/// have been removed. They had no callers left, and leaving a second
/// session-issuing path in the tree is an invitation to mint a token that then
/// races the shared one for the same storage slot. The endpoints still exist on
/// k9 (`/api/v1/taxi/users/auth/*`); nothing in this app should call them.
///
/// Device push registration is not here either: it goes through the one
/// shared /api/v1/fcm-tokens/mobile/save call. The ride-side endpoint this
/// class used to POST to (/taxi/users/fcm-token) returns 404 on k9, and it
/// sent a `platform` field that the mobile endpoints reject with 400.
///
/// What remains is profile mutation, which is legitimately ride-scoped because
/// it writes through the taxi route tree — the same `users` document either way,
/// since `TaxiUser` and `FoodUser` are two Mongoose models over one collection.
class TaxiAuthRepository {
  final TaxiApiClient api;

  TaxiAuthRepository(this.api);

  Future<TaxiUserModel> updateProfile(Map<String, dynamic> fields) async {
    final data = await api.patch(ApiConstants.me, data: fields);
    return TaxiUserModel.fromJson(Map<String, dynamic>.from(data['user'] ?? data));
  }

  Future<String> uploadProfileImage(String dataUrl) async {
    final data = await api.post(ApiConstants.profileImage, data: {'dataUrl': dataUrl});
    return (data['secureUrl'] ?? '').toString();
  }

  Future<void> requestAccountDeletion(String reason) {
    return api.post(ApiConstants.deleteRequest, data: {'reason': reason});
  }
}
