import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/app/routing/app_route_names.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/modules/app_module.dart';
import 'package:superapp_user/modules/module_registry.dart';

/// The super-app landing screen: pick a service.
///
/// Tiles come from [ModuleRegistry.enabled], so a new module appears here the
/// moment it is registered — this screen is never edited to add one.
///
/// Deliberately minimal for now. The richer version (active-job cards, recent
/// activity, shortcuts, server-driven ordering from `/taxi/users/app-modules`)
/// lands once `shared/activity` exists.
class HubScreen extends ConsumerWidget {
  const HubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(moduleRegistryProvider).enabled;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What do you need?',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Food, rides and more — one app.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 1.05,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _ModuleTile(module: modules[index]),
                  childCount: modules.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _ShortcutChip(
                      label: 'Wallet',
                      icon: Icons.account_balance_wallet_rounded,
                      location: AppRoutePaths.wallet,
                    ),
                    _ShortcutChip(
                      label: 'Notifications',
                      icon: Icons.notifications_rounded,
                      location: AppRoutePaths.notifications,
                    ),
                    _ShortcutChip(
                      label: 'Refer & earn',
                      icon: Icons.card_giftcard_rounded,
                      location: AppRoutePaths.referral,
                    ),
                    _ShortcutChip(
                      label: 'Help',
                      icon: Icons.support_agent_rounded,
                      location: AppRoutePaths.support,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({required this.module});

  final AppModule module;

  @override
  Widget build(BuildContext context) {
    final accent = module.accent;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go(module.entryRoute),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.primary.withValues(alpha: isDark ? 0.18 : 0.10),
                Colors.transparent,
              ],
            ),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(module.icon, color: accent.primary, size: 24),
              ),
              Text(
                module.label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.label,
    required this.icon,
    required this.location,
  });

  final String label;
  final IconData icon;
  final String location;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ActionChip(
      avatar: Icon(icon, size: 17, color: AppColors.primary),
      label: Text(label),
      onPressed: () => context.push(location),
      backgroundColor: isDark ? AppColors.cardDark : AppColors.cardLight,
      side: BorderSide(
        color: isDark ? AppColors.borderDark : AppColors.borderLight,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    );
  }
}
