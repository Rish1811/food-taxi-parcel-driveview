import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/realtime/socket_service.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:superapp_user/core/network/network_providers.dart';

/// The app's one Socket.IO connection — order tracking and chat both read
/// this instead of opening their own.
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});

/// Connects the shared socket on login, disconnects on logout. Mounted once
/// from `MainAppShell` (`ref.watch`) so it lives for the app's session.
final socketConnectionProvider = NotifierProvider<SocketConnectionNotifier, bool>(
  SocketConnectionNotifier.new,
);

class SocketConnectionNotifier extends Notifier<bool> {
  @override
  bool build() {
    ref.listen(authViewModelProvider, (previous, next) {
      if (previous?.value?.id == next.value?.id) return;
      unawaited(_sync(next.value != null));
    });

    final loggedIn = ref.read(authViewModelProvider).value != null;
    if (loggedIn) {
      // Deferred: connecting synchronously here would run inside build(),
      // before this notifier is registered as initialized.
      unawaited(Future.microtask(() => _sync(true)));
    }
    return loggedIn;
  }

  Future<void> _sync(bool loggedIn) async {
    final service = ref.read(socketServiceProvider);
    if (loggedIn) {
      final token = await ref.read(tokenStorageProvider).accessToken;
      if (token != null && token.isNotEmpty) service.connect(token);
    } else {
      service.disconnect();
    }
    state = loggedIn;
  }
}
