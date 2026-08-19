import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:superapp_user/design_system/components/feedback/taxi_snackbar_utils.dart';
import 'package:superapp_user/shared/session/presentation/system/presentation/widgets/system_status_view.dart';

class NoInternetScreen extends StatefulWidget {
  final VoidCallback? onConnected;

  const NoInternetScreen({super.key, this.onConnected});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  bool _checking = false;

  Future<void> _retry() async {
    setState(() => _checking = true);
    final results = await Connectivity().checkConnectivity();
    final connected = results.any((r) => r != ConnectivityResult.none);
    if (mounted) setState(() => _checking = false);
    if (connected) {
      widget.onConnected?.call();
    } else if (mounted) {
      SnackbarUtils.error(context, 'Still no internet connection');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SystemStatusView(
      icon: Icons.wifi_off_rounded,
      title: 'No internet connection',
      message: 'Please check your Wi-Fi or mobile data settings and try again.',
      primaryActionLabel: 'Retry',
      primaryActionLoading: _checking,
      onPrimaryAction: _retry,
    );
  }
}
