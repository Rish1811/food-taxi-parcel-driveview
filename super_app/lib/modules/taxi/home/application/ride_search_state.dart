/// Where the rider is in the "find me a driver" phase.
///
/// These mirror what the backend actually reports during dispatch, so the
/// search screen never has to guess: [searching] is driven by `rideSearchUpdate`,
/// [accepted] by `rideAccepted`, and [noDrivers]/[cancelled] by `rideCancelled`
/// (distinguished by its `reasonCode`).
enum RideSearchPhase {
  idle,
  creating,
  searching,
  accepted,
  noDrivers,
  cancelled,
  failed,
}

class RideSearchState {
  final RideSearchPhase phase;
  final String? rideId;

  /// Current dispatch attempt and the total the server will make before it
  /// gives up. Both 0 until the first `rideSearchUpdate` lands.
  final int attempt;
  final int maxAttempts;

  /// Radius the server is currently searching, in metres.
  final double radiusMeters;

  /// How many drivers were pinged in this attempt, and cumulatively.
  final int matchedDrivers;
  final int totalNotifiedDrivers;

  /// Server's own budget for the whole search, used for the progress bar.
  final int maxSearchSeconds;

  final String? message;

  const RideSearchState({
    this.phase = RideSearchPhase.idle,
    this.rideId,
    this.attempt = 0,
    this.maxAttempts = 0,
    this.radiusMeters = 0,
    this.matchedDrivers = 0,
    this.totalNotifiedDrivers = 0,
    this.maxSearchSeconds = 0,
    this.message,
  });

  bool get isSearching =>
      phase == RideSearchPhase.creating || phase == RideSearchPhase.searching;

  bool get isTerminal =>
      phase == RideSearchPhase.accepted ||
      phase == RideSearchPhase.noDrivers ||
      phase == RideSearchPhase.cancelled ||
      phase == RideSearchPhase.failed;

  RideSearchState copyWith({
    RideSearchPhase? phase,
    String? rideId,
    int? attempt,
    int? maxAttempts,
    double? radiusMeters,
    int? matchedDrivers,
    int? totalNotifiedDrivers,
    int? maxSearchSeconds,
    String? message,
    bool clearMessage = false,
  }) {
    return RideSearchState(
      phase: phase ?? this.phase,
      rideId: rideId ?? this.rideId,
      attempt: attempt ?? this.attempt,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      matchedDrivers: matchedDrivers ?? this.matchedDrivers,
      totalNotifiedDrivers: totalNotifiedDrivers ?? this.totalNotifiedDrivers,
      maxSearchSeconds: maxSearchSeconds ?? this.maxSearchSeconds,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
