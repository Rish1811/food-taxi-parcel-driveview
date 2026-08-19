import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:superapp_user/shared/session/presentation/system/presentation/widgets/system_status_view.dart';

class GpsDisabledScreen extends StatelessWidget {
  const GpsDisabledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SystemStatusView(
      icon: Icons.location_disabled_rounded,
      title: 'Turn on location services',
      message: 'Enable GPS on your device so we can find your pickup point and nearby drivers accurately.',
      primaryActionLabel: 'Open location settings',
      onPrimaryAction: () => Geolocator.openLocationSettings(),
    );
  }
}
