import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:superapp_user/shared/session/presentation/system/presentation/widgets/system_status_view.dart';

class LocationPermissionDeniedScreen extends StatelessWidget {
  const LocationPermissionDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SystemStatusView(
      icon: Icons.location_off_rounded,
      title: 'Location permission needed',
      message: 'We need access to your location to show nearby drivers, calculate fares and get you picked up accurately.',
      primaryActionLabel: 'Open app settings',
      onPrimaryAction: () => openAppSettings(),
      secondaryActionLabel: 'Not now',
      onSecondaryAction: () => Navigator.of(context).maybePop(),
    );
  }
}
