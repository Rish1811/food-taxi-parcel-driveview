import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/app/shell/widgets/super_app_header.dart';
import 'package:superapp_user/design_system/components/nav/module_top_nav.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/tokens/module_theme_config.dart';
import 'package:superapp_user/modules/module_id.dart';

/// Wraps a module's **entry** screen with the service switcher and dynamic top-to-bottom gradient backdrop.
class ModuleHomeShell extends ConsumerWidget {
  const ModuleHomeShell({
    super.key,
    required this.moduleId,
    required this.child,
  });

  final ModuleId moduleId;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = ModuleThemeConfig.of(moduleId);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Stack(
        children: [
          // Top-to-bottom gradient: Starts DARK at the top, gets lighter going down
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 420,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          config.darkTop,
                          config.darkTop.withValues(alpha: 0.85),
                          config.midColor.withValues(alpha: 0.4),
                          AppColors.backgroundDark,
                        ]
                      : [
                          config.darkTop,                          // 1. Top status bar & Location header: DARK GREEN
                          config.darkTop.withValues(alpha: 0.95), // 2. Module Nav Tabs: DARK GREEN
                          config.midColor,                        // 3. Search Bar area: Medium Green
                          config.glowWash.withValues(alpha: 0.70),// 4. Category row: Light Green Wash
                          config.softTint.withValues(alpha: 0.35),// 5. Below Categories: Soft Tint
                          AppColors.backgroundLight.withValues(alpha: 0.0), // 6. Filter Pills & Feed: White
                        ],
                  stops: isDark
                      ? const [0.0, 0.4, 0.75, 1.0]
                      : const [0.0, 0.22, 0.42, 0.65, 0.85, 1.0],
                ),
              ),
            ),
          ),
          Column(
            children: [
              SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SuperAppHeader(themeConfig: config),
                    ModuleTopNav(activeModule: moduleId),
                  ],
                ),
              ),
              Expanded(child: child),
            ],
          ),
        ],
      ),
    );
  }
}
