import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/ride/custom_app_bar.dart';
import 'package:superapp_user/design_system/components/ride/profile_tile.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Settings'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _Section(children: [
            ProfileTile(
              icon: Icons.notifications_outlined,
              title: 'Notification settings',
              onTap: () => context.push('/taxi/notifications/settings'),
            ),
            const Divider(height: 1),
            ProfileTile(
              icon: Icons.language_rounded,
              title: 'Language',
              onTap: () => context.push('/taxi/language'),
            ),
            const Divider(height: 1),
            ProfileTile(
              icon: Icons.dark_mode_outlined,
              title: 'App theme',
              onTap: () => context.push('/taxi/theme'),
            ),
          ]),
          const SizedBox(height: 16),
          _Section(children: [
            ProfileTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy policy',
              onTap: () => context.push('/settings/legal/privacy'),
            ),
            const Divider(height: 1),
            ProfileTile(
              icon: Icons.security_rounded,
              title: 'Security',
              onTap: () => context.push('/taxi/settings/security'),
            ),
            const Divider(height: 1),
            ProfileTile(
              icon: Icons.description_outlined,
              title: 'Terms of service',
              onTap: () => context.push('/settings/legal/terms'),
            ),
            const Divider(height: 1),
            ProfileTile(
              icon: Icons.info_outline_rounded,
              title: 'About',
              onTap: () => context.push('/settings/about'),
            ),
          ]),
          const SizedBox(height: 16),
          _Section(children: [
            ProfileTile(
              icon: Icons.delete_outline_rounded,
              title: 'Delete account',
              iconColor: TaxiColors.error,
              onTap: () => context.push('/taxi/delete-account'),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final List<Widget> children;
  const _Section({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TaxiColors.lightBorder),
      ),
      child: Column(children: children),
    );
  }
}
