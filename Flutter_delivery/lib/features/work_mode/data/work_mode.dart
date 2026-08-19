/// Which kinds of job this driver wants dispatched to them.
///
/// Wire values come from k9's `setWorkMode`, which accepts exactly
/// `all | taxi | delivery` and rejects anything else with 400.
enum WorkMode {
  /// Food deliveries only.
  delivery('delivery', 'Food', 'Food orders only'),

  /// Taxi rides only.
  taxi('taxi', 'Taxi', 'Ride requests only'),

  /// Both — dispatch sends whichever comes first.
  all('all', 'Both', 'Food orders and rides');

  const WorkMode(this.wire, this.label, this.description);

  /// Value sent to `PATCH /taxi/drivers/work-mode`.
  final String wire;
  final String label;
  final String description;

  bool get acceptsFood => this == WorkMode.delivery || this == WorkMode.all;
  bool get acceptsRides => this == WorkMode.taxi || this == WorkMode.all;

  static WorkMode parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'taxi':
        return WorkMode.taxi;
      case 'all':
      case 'both':
        return WorkMode.all;
      default:
        return WorkMode.delivery;
    }
  }

  /// The capability a driver must hold to select this mode.
  ///
  /// The server enforces this against `driver.serviceCapabilities`; mirroring
  /// it here lets the UI grey out a mode instead of letting the driver pick it
  /// and receive a 400.
  bool isAllowedFor(Set<String> capabilities) {
    switch (this) {
      case WorkMode.taxi:
        return capabilities.contains('taxi');
      case WorkMode.delivery:
        return capabilities.contains('delivery');
      case WorkMode.all:
        return capabilities.contains('taxi') &&
            capabilities.contains('delivery');
    }
  }

  String unavailableReason() {
    switch (this) {
      case WorkMode.taxi:
        return "You're not registered for taxi rides";
      case WorkMode.delivery:
        return "You're not registered for deliveries";
      case WorkMode.all:
        return 'Needs both taxi and delivery approval';
    }
  }
}
