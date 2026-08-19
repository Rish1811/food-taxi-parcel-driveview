import 'package:superapp_user/app/routing/app_route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/design_system/components/ride/secondary_button.dart';

class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  ConsumerState<LocationPermissionScreen> createState() => _LocationPermissionScreenState();
}

class _LocationPermissionScreenState extends ConsumerState<LocationPermissionScreen> {
  bool _requesting = false;

  Future<void> _allow() async {
    setState(() => _requesting = true);
    await ref.read(taxiLocationServiceProvider).ensurePermission();
    if (mounted) context.go(AppRoutePaths.permissionNotifications);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                height: 140,
                width: 140,
                decoration: BoxDecoration(
                  color: TaxiColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded, size: 64, color: TaxiColors.primary),
              ),
              const SizedBox(height: 32),
              Text(
                'Enable your location',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We use your location to find nearby drivers and get you the fastest, most accurate pickup.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              TaxiPrimaryButton(
                label: 'Allow location access',
                isLoading: _requesting,
                onPressed: _allow,
              ),
              const SizedBox(height: 12),
              TaxiSecondaryButton(
                label: 'Not now',
                onPressed: () => context.go(AppRoutePaths.permissionNotifications),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
