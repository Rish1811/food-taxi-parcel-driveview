import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/modules/taxi/auth/application/auth_providers.dart';
import 'package:superapp_user/shared/session/presentation/system/presentation/widgets/system_status_view.dart';

class SessionExpiredScreen extends ConsumerWidget {
  const SessionExpiredScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopScope(
      canPop: false,
      child: SystemStatusView(
        icon: Icons.lock_clock_rounded,
        title: 'Session expired',
        message: 'Your session has expired for security reasons. Please log in again to continue.',
        primaryActionLabel: 'Log in again',
        onPrimaryAction: () async {
          await ref.read(authControllerProvider.notifier).logout();
          if (context.mounted) context.go('/auth/phone');
        },
      ),
    );
  }
}
