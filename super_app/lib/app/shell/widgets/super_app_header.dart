import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/app/routing/app_route_names.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:superapp_user/shared/location/application/current_location_provider.dart';
import 'package:superapp_user/shared/notifications/presentation/viewmodels/notification_inbox_viewmodel.dart';
import 'package:superapp_user/core/utils/haptics.dart';

import 'package:superapp_user/design_system/tokens/module_theme_config.dart';
import 'package:superapp_user/modules/module_id.dart';

/// Location, notifications and profile — shared across every module home.
class SuperAppHeader extends ConsumerWidget {
  const SuperAppHeader({super.key, this.themeConfig});

  final ModuleThemeConfig? themeConfig;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = themeConfig ?? ModuleThemeConfig.of(ModuleId.food);
    final label = ref.watch(currentLocationLabelProvider);
    final addressLine = ref.watch(currentAddressLineProvider);
    final user = ref.watch(authViewModelProvider).value;
    final unread = ref.watch(unreadNotificationCountProvider);

    final displayLabel = (label.isNotEmpty && label != 'Indore')
        ? (label.contains(',') ? label.split(',').first : label)
        : 'Office';
    final displayAddress = addressLine.isNotEmpty
        ? addressLine
        : 'Mamaloka Building 5th Floor, New Palasia, Indore';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Row(
        children: [
          // Location pin icon inside dark rounded box
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: config.containerBoxBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: config.containerBoxBorder,
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () {
                Haptics.light();
                context.push(AppRoutePaths.addresses);
              },
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                            color: Colors.white, // Pure white color for high visibility
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ],
                  ),
                  Text(
                    displayAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.2,
                      color: Color(0xFFE2F0EA), // Bright light green-white for high visibility
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _HeaderIconButton(
            icon: Icons.notifications_none_rounded,
            badgeCount: unread,
            themeConfig: config,
            onTap: () {
              Haptics.light();
              ref.read(notificationInboxProvider.notifier).clearUnreadCount();
              context.push(AppRoutePaths.notifications);
            },
          ),
          const SizedBox(width: 8),
          // Profile avatar with online green dot badge
          GestureDetector(
            onTap: () {
              Haptics.light();
              context.push(AppRoutePaths.profile);
            },
            child: Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF10B981),
                      width: 1.5,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (user?.avatarUrl?.isNotEmpty ?? false)
                      ? SmartImage(
                          url: user!.avatarUrl!,
                          category: ImageCategory.brand,
                          width: 40,
                          height: 40,
                        )
                      : const Icon(
                          Icons.person_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                ),
                Positioned(
                  bottom: 1,
                  right: 1,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: config.darkTop,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.themeConfig,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final ModuleThemeConfig themeConfig;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: themeConfig.containerBoxBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: themeConfig.containerBoxBorder,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.white,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF032418),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  badgeCount > 9 ? '9+' : '$badgeCount',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
