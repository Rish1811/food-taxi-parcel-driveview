import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';

const _authRoutes = {'/phone-login', '/otp-verify', '/register', '/account-status'};
const _prelaunchRoutes = {'/', '/onboarding'};

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) => notifyListeners(),
    );
  }

  final Ref _ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authControllerProvider);
    final location = state.matchedLocation;
    final onUnauthedAllowedRoute =
        _prelaunchRoutes.contains(location) || _authRoutes.contains(location);

    return switch (authState) {
      // Still resolving the startup `/auth/me` check — let the splash
      // screen decide when to move on rather than forcing a route here.
      AuthInitial() || AuthLoading() => null,
      AuthUnauthenticated() ||
      AuthFailure() => onUnauthedAllowedRoute ? null : '/phone-login',
      AuthNeedsRegistration() => location == '/register' ? null : '/register',
      AuthPendingApproval() =>
        location == '/account-status' ? null : '/account-status',
      AuthAuthenticated() => onUnauthedAllowedRoute ? '/main' : null,
    };
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});
