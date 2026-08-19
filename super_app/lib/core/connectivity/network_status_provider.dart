import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod 3.0 Notifier for monitoring network connectivity status.
final networkStatusProvider = NotifierProvider<NetworkStatusNotifier, bool>(() {
  return NetworkStatusNotifier();
});

class NetworkStatusNotifier extends Notifier<bool> {
  Timer? _timer;
  bool _isChecking = false;

  @override
  bool build() {
    _startPeriodicCheck();
    ref.onDispose(() {
      _timer?.cancel();
    });
    return true;
  }

  void _startPeriodicCheck() {
    checkConnection();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      checkConnection();
    });
  }

  /// Manually checks internet connectivity.
  Future<bool> checkConnection() async {
    if (_isChecking) return state;
    _isChecking = true;
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      final hasInternet = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (state != hasInternet) {
        state = hasInternet;
      }
      return hasInternet;
    } catch (_) {
      if (state != false) {
        state = false;
      }
      return false;
    } finally {
      _isChecking = false;
    }
  }

  /// Signals a connection failure detected from network requests (e.g. Dio errors).
  void reportOffline() {
    if (state) {
      state = false;
    }
  }
}
