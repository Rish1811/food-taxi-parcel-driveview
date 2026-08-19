import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/design_system/tokens/module_theme_config.dart';
import 'package:superapp_user/modules/module_id.dart';

class NavItem {
  final ModuleId? id;
  final String label;
  final String tagline;
  final String imageAsset;
  final IconData fallbackIcon;
  final String route;

  const NavItem({
    required this.id,
    required this.label,
    required this.tagline,
    required this.imageAsset,
    required this.fallbackIcon,
    required this.route,
  });
}

/// The service switcher shown at the top of every module home.
///
/// One tab per registered module, so adding a module here is the only nav
/// change it needs. Features active tab extension touching the search bar
/// directly, matching the exact design.
class ModuleTopNav extends ConsumerWidget {
  const ModuleTopNav({super.key, required this.activeModule});

  final ModuleId activeModule;

  static const List<NavItem> navItems = [
    NavItem(
      id: ModuleId.food,
      label: 'Food',
      tagline: 'Delicious meals',
      imageAsset: 'assets/images/food.png',
      fallbackIcon: Icons.fastfood_rounded,
      route: '/food',
    ),
    NavItem(
      id: ModuleId.taxi,
      label: 'Rides',
      tagline: 'Book a ride',
      imageAsset: 'assets/images/Rides.png',
      fallbackIcon: Icons.directions_car_rounded,
      route: '/taxi',
    ),
    NavItem(
      id: ModuleId.parcel,
      label: 'Parcel',
      tagline: 'Send anything',
      imageAsset: 'assets/images/parcel.png',
      fallbackIcon: Icons.local_shipping_rounded,
      route: '/parcel',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeConfig = ModuleThemeConfig.of(activeModule);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.only(top: 4, bottom: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: navItems.map((item) {
          final isActive = item.id == activeModule;
          final itemConfig = ModuleThemeConfig.of(item.id);

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _ModuleTab(
                item: item,
                isActive: isActive,
                activeConfig: activeConfig,
                itemConfig: itemConfig,
                onTap: isActive ? null : () => context.go(item.route),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ModuleTab extends StatelessWidget {
  const _ModuleTab({
    required this.item,
    required this.isActive,
    required this.activeConfig,
    required this.itemConfig,
    required this.onTap,
  });

  final NavItem item;
  final bool isActive;
  final ModuleThemeConfig activeConfig;
  final ModuleThemeConfig itemConfig;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isActive,
      label: '${item.label}. ${item.tagline}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          margin: EdgeInsets.only(bottom: isActive ? 0 : 6),
          padding: EdgeInsets.fromLTRB(
            isActive ? 5 : 3,
            isActive ? 9 : 6,
            isActive ? 5 : 3,
            isActive ? 11 : 6,
          ),
          decoration: BoxDecoration(
            gradient: isActive
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [itemConfig.activeTabBg, itemConfig.darkTop],
                  )
                : null,
            color: isActive ? null : const Color(0x33000000),
            borderRadius: isActive
                ? const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(6),
                    bottomRight: Radius.circular(6),
                  )
                : BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? itemConfig.activeTabBorder
                  : Colors.white.withValues(alpha: 0.12),
              width: isActive ? 1.2 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: itemConfig.darkTop.withValues(alpha: 0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    item.imageAsset,
                    width: isActive ? 20 : 17,
                    height: isActive ? 20 : 17,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      item.fallbackIcon,
                      size: isActive ? 18 : 15,
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isActive ? 13 : 12,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                            color: isActive
                                ? Colors.white
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        Text(
                          item.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isActive ? 9 : 8.5,
                            height: 1.25,
                            fontWeight: FontWeight.w500,
                            color: isActive
                                ? Colors.white.withValues(alpha: 0.85)
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isActive) ...[
                const SizedBox(height: 4),
                Container(
                  width: 26,
                  height: 3,
                  decoration: BoxDecoration(
                    color: itemConfig.activeIndicator,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: itemConfig.activeIndicator.withValues(alpha: 0.6),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
