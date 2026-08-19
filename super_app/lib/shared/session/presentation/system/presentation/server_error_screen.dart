import 'package:flutter/material.dart';
import 'package:superapp_user/shared/session/presentation/system/presentation/widgets/system_status_view.dart';

class ServerErrorScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const ServerErrorScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SystemStatusView(
      icon: Icons.cloud_off_rounded,
      title: 'Something went wrong',
      message: "Our servers are taking a bit longer than usual to respond. Please try again in a moment.",
      primaryActionLabel: 'Retry',
      onPrimaryAction: onRetry ?? () => Navigator.of(context).maybePop(),
    );
  }
}
