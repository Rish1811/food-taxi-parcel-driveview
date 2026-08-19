import 'package:flutter/material.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';

class SystemStatusView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String primaryActionLabel;
  final VoidCallback? onPrimaryAction;
  final bool primaryActionLoading;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  const SystemStatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryActionLabel,
    required this.onPrimaryAction,
    this.primaryActionLoading = false,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 120,
                width: 120,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: TaxiColors.primaryGradient),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 54, color: Colors.white),
              ),
              const SizedBox(height: 28),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: TaxiColors.lightTextSecondary),
              ),
              const SizedBox(height: 32),
              TaxiPrimaryButton(
                label: primaryActionLabel,
                isLoading: primaryActionLoading,
                onPressed: onPrimaryAction,
              ),
              if (secondaryActionLabel != null) ...[
                const SizedBox(height: 12),
                TextButton(onPressed: onSecondaryAction, child: Text(secondaryActionLabel!)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
