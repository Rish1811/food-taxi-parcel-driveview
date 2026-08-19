import '../data/models/delivery_partner.dart';

sealed class AuthState {
  const AuthState();
}

/// Initial state before the startup `/auth/me` check has run.
class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthNeedsRegistration extends AuthState {
  const AuthNeedsRegistration(this.phone);
  final String phone;
}

/// Partner exists but `status` isn't `approved` yet.
class AuthPendingApproval extends AuthState {
  const AuthPendingApproval({required this.isRejected, this.rejectionReason});
  final bool isRejected;
  final String? rejectionReason;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final DeliveryPartner user;
}

class AuthFailure extends AuthState {
  const AuthFailure(this.message);
  final String message;
}
