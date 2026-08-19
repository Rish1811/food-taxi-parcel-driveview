import 'package:flutter/material.dart';
import 'package:superapp_user/shared/session/presentation/system/presentation/widgets/system_status_view.dart';

class MaintenanceScreen extends StatelessWidget {
  final VoidCallback? onRetry;

  const MaintenanceScreen({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SystemStatusView(
      icon: Icons.build_circle_outlined,
      title: 'Under maintenance',
      message: "We're currently performing scheduled maintenance to improve your experience. Please check back shortly.",
      primaryActionLabel: 'Try again',
      onPrimaryAction: onRetry ?? () => Navigator.of(context).maybePop(),
    );
  }
}
