import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/modules/taxi/auth/application/auth_controller.dart';
import 'package:superapp_user/modules/taxi/auth/application/auth_state.dart';
import 'package:superapp_user/modules/taxi/auth/data/auth_repository.dart';

/// Ride-side auth wiring.
///
/// Follow-up: this still owns its own session state alongside food's
/// `authViewModelProvider`. k9 already unified identity — one
/// `core/users/user.model.js` and one access+refresh JWT pair — so these two
/// collapse into a single `shared/auth` controller in the shared pass. Keeping
/// them apart until then means one login does not yet authenticate both sides.
final taxiAuthRepositoryProvider = Provider<TaxiAuthRepository>((ref) {
  return TaxiAuthRepository(ref.watch(taxiApiClientProvider));
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
