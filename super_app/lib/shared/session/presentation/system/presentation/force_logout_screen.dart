import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/modules/taxi/auth/application/auth_providers.dart';
import 'package:superapp_user/shared/session/presentation/system/presentation/widgets/system_status_view.dart';

class ForceLogoutScreen extends ConsumerWidget {
  final String? reason;

  const ForceLogoutScreen({super.key, this.reason});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: SystemStatusView(
        icon: Icons.gpp_bad_rounded,
        title: 'You have been signed out',
        message: reason ?? 'Your account was signed out remotely. Please log in again to continue using the app.',
        primaryActionLabel: 'Log in again',
        onPrimaryAction: () async {
          await ref.read(authControllerProvider.notifier).logout();
          if (context.mounted) context.go('/auth/phone');
        },
      ),
    );
  }
}
