import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NetworkController extends Notifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  final Connectivity _connectivity = Connectivity();

  @override
  bool build() {
    _initConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
    
    ref.onDispose(() {
      _subscription?.cancel();
    });
    
    // Default to true (connected) until we know otherwise
    return true; 
  }

  Future<void> _initConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.none) && result.length == 1) {
      state = false;
    } else {
      state = true;
    }
  }
}

final networkControllerProvider = NotifierProvider<NetworkController, bool>(
  NetworkController.new,
);
