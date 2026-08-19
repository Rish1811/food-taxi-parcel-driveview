import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Broadcasts app-wide auth events (e.g. forced logout on refresh failure)
/// so the router and auth state can react without a direct dependency
/// from the networking layer on the auth feature.
class AuthEventBus {
  final _forceLogoutController = StreamController<void>.broadcast();

  Stream<void> get onForceLogout => _forceLogoutController.stream;

  void emitForceLogout() => _forceLogoutController.add(null);

  void dispose() => _forceLogoutController.close();
}

final authEventBusProvider = Provider<AuthEventBus>((ref) {
  final bus = AuthEventBus();
  ref.onDispose(bus.dispose);
  return bus;
});
