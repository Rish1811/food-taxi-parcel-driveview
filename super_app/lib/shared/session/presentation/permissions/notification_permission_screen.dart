import 'package:superapp_user/app/routing/app_route_names.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/design_system/components/ride/secondary_button.dart';

class NotificationPermissionScreen extends StatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  State<NotificationPermissionScreen> createState() => _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState extends State<NotificationPermissionScreen> {
  bool _requesting = false;

  Future<void> _allow() async {
    setState(() => _requesting = true);
    await Permission.notification.request();
    if (mounted) context.go(AppRoutePaths.splash);
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
                  color: TaxiColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, size: 64, color: TaxiColors.accentDark),
              ),
              const SizedBox(height: 32),
              Text(
                'Stay in the loop',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Get real-time updates on your ride, driver arrival, offers and important account alerts.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              TaxiPrimaryButton(
                label: 'Enable notifications',
                isLoading: _requesting,
                onPressed: _allow,
              ),
              const SizedBox(height: 12),
              TaxiSecondaryButton(
                label: 'Not now',
                onPressed: () => context.go(AppRoutePaths.splash),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
