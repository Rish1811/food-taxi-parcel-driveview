/// Typed failures surfaced to the presentation layer.
///
/// The UI never sees a DioException — [ApiClient] maps transport and HTTP
/// errors onto these so screens can branch on type, not on status codes.
abstract class Failure implements Exception {
  final String message;
  const Failure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class ServerFailure extends Failure {
  /// HTTP status, when the server produced one.
  final int? statusCode;
  const ServerFailure([super.message = 'Something went wrong. Please try again.', this.statusCode]);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No internet connection.']);
}

class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'The request timed out. Please try again.']);
}

/// 401/403 — token missing, expired beyond refresh, or role rejected.
class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Session expired. Please log in again.']);
}

/// 400/422 — backend validation rejected the payload.
class ValidationFailure extends Failure {
  /// Field-level errors when the backend supplies them.
  final Map<String, String> fieldErrors;
  const ValidationFailure([super.message = 'Please check the details and try again.', this.fieldErrors = const {}]);
}

/// 429 — rate limited (the OTP routes are stricter).
class RateLimitFailure extends Failure {
  const RateLimitFailure([super.message = 'Too many attempts. Please wait a moment and try again.']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'Not found.']);
}
