import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/network/network_providers.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/modules/taxi/auth/application/auth_state.dart';
import 'package:superapp_user/modules/taxi/auth/data/models/user_model.dart';
import 'package:superapp_user/modules/taxi/home/application/ride_search_controller.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:superapp_user/shared/profile/data/user_model.dart';

/// The ride side's view of the **one** app session.
///
/// This deliberately owns no login of its own any more. There is a single
/// sign-in — the shared `/auth/phone` + `/auth/otp` flow — and this controller
/// simply projects [authViewModelProvider] into the [AuthState] shape the ~12
/// ride-side screens already read.
///
/// Why one session works against two route trees on k9:
///  * both auth surfaces sign with the same secret
///    (`env.jwtSecret == config.jwtAccessSecret`)
///  * `TaxiUser` and `FoodUser` are two Mongoose models over the **same**
///    `users` collection, so a phone number is one document with one `_id`
///  * both middlewares already read either claim shape and normalise role case
///    — taxi: `payload.sub || payload.userId || payload.id`
///    — core: `decoded.userId || decoded.sub`
///
/// So the access token minted by the shared login authenticates every
/// `/api/v1/taxi/*` call as well. Keeping a second controller with its own
/// login would have meant two tokens racing for one storage slot.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Connect the ride socket whenever the session becomes valid, and drop it
    // on logout. Previously this lived in a bootstrap() that nothing calls any
    // more, which left every consumer stuck on AuthStatus.unknown.
    ref.listen(authViewModelProvider, (_, next) {
      _syncSocket(next.value);
    });

    final async = ref.watch(authViewModelProvider);
    return switch (async) {
      AsyncLoading() => const AuthState(status: AuthStatus.authenticating),
      AsyncError(:final error) => AuthState(
          status: AuthStatus.unauthenticated,
          error: error.toString(),
        ),
      _ => _project(async.value),
    };
  }

  AuthState _project(UserModel? user) {
    if (user == null) {
      return const AuthState(status: AuthStatus.unauthenticated);
    }
    return AuthState(status: AuthStatus.authenticated, user: _toTaxiUser(user));
  }

  static TaxiUserModel _toTaxiUser(UserModel user) => TaxiUserModel(
        id: user.id,
        name: user.name,
        phone: user.phone ?? '',
        email: user.email,
        gender: user.gender,
        profileImage: user.avatarUrl,
        referralCode: user.referralCode,
        referralCount: user.referralCount,
        // `currentRideId` is ride state, not identity — it is resolved from
        // GET /taxi/rides/active/me rather than carried on the user object.
        currentRideId: null,
      );

  Future<void> _syncSocket(UserModel? user) async {
    final socket = ref.read(taxiSocketServiceProvider);
    if (user == null) {
      socket.disconnect();
      return;
    }
    final token = await ref.read(tokenStorageProvider).accessToken;
    if (token == null || token.isEmpty) return;
    socket.connect(token);
    // Arm dispatch listeners immediately: `rideAccepted` can land within a
    // second of a ride being created, and a listener bound at screen-mount
    // time would lose the race.
    ref.read(rideSearchControllerProvider);
  }

  /// Logs out of the whole app, not just the ride side.
  Future<void> logout() =>
      ref.read(authViewModelProvider.notifier).logout();

  /// Kept for the ride screens that edit profile details.
  void updateUser(TaxiUserModel user) {
    state = state.copyWith(status: AuthStatus.authenticated, user: user);
  }
}
