import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/design_system/components/ride/app_bottom_navigation_bar.dart';
import 'package:superapp_user/modules/taxi/home/application/home_providers.dart';
import 'package:superapp_user/modules/taxi/home/data/models/app_module_model.dart';

class ServiceItemModel {
  final String label;
  final IconData icon;
  final Color iconColor;
  final Color badgeColor;
  final String? badgeText;
  final String route;

  const ServiceItemModel({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.route,
    this.badgeColor = Colors.transparent,
    this.badgeText,
  });
}

class AllServicesScreen extends ConsumerWidget {
  const AllServicesScreen({super.key});

  static const List<ServiceItemModel> _fallbackServices = [
    ServiceItemModel(
      label: 'Parcel on Bike',
      icon: Icons.inventory_2_rounded,
      iconColor: Color(0xFFD97706),
      route: '/delivery/new',
    ),
    ServiceItemModel(
      label: 'Auto',
      icon: Icons.electric_rickshaw_rounded,
      iconColor: Color(0xFF10B981),
      route: '/home/search',
    ),
    ServiceItemModel(
      label: 'Cab Economy',
      icon: Icons.directions_car_rounded,
      iconColor: Color(0xFFFF5200),
      route: '/home/search',
    ),
    ServiceItemModel(
      label: 'Bike',
      icon: Icons.two_wheeler_rounded,
      iconColor: Color(0xFFFF8A00),
      route: '/home/search',
    ),
    ServiceItemModel(
      label: 'Bike Lite',
      icon: Icons.two_wheeler_rounded,
      iconColor: Color(0xFF10B981),
      badgeColor: Color(0xFF10B981),
      badgeText: '%',
      route: '/home/search',
    ),
    ServiceItemModel(
      label: 'Cab Premium',
      icon: Icons.local_taxi_rounded,
      iconColor: Color(0xFFFF5C2B),
      badgeColor: Color(0xFFFFD700),
      badgeText: '★',
      route: '/home/search',
    ),
    ServiceItemModel(
      label: 'Cab Daily',
      icon: Icons.directions_car_filled_rounded,
      iconColor: Color(0xFF10B981),
      badgeColor: Color(0xFF10B981),
      badgeText: '%',
      route: '/home/search',
    ),
    ServiceItemModel(
      label: 'Travel',
      icon: Icons.cases_rounded,
      iconColor: Color(0xFF8B5CF6),
      route: '/rental',
    ),
  ];

  static String _routeFor(AppModuleModel module) {
    if (module.transportType == 'delivery') return '/delivery/new';
    if (module.serviceType == 'rental') return '/rental';
    return '/home/search';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);

    final modulesAsync = ref.watch(appModulesProvider);

    return Scaffold(
      backgroundColor: bgColor,
      bottomNavigationBar: const AppBottomNavigationBar(currentIndex: 1),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- TOP TITLE ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Text(
                'All Services',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),

            // --- 4-COLUMN SERVICE GRID ---
            Expanded(
              child: modulesAsync.when(
                data: (modules) {
                  if (modules.isEmpty) return _buildFallbackGrid(context, isDark, textPrimary);
                  return GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: modules.length,
                    itemBuilder: (context, index) {
                      final module = modules[index];
                      return _ApiModuleCard(
                        module: module,
                        isDark: isDark,
                        textPrimary: textPrimary,
                        onTap: () => context.push(_routeFor(module)),
                      );
                    },
                  );
                },
                loading: () => _buildFallbackGrid(context, isDark, textPrimary),
                error: (_, _) => _buildFallbackGrid(context, isDark, textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackGrid(BuildContext context, bool isDark, Color textPrimary) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: _fallbackServices.length,
      itemBuilder: (context, index) {
        final service = _fallbackServices[index];
        return _FallbackServiceCard(
          service: service,
          isDark: isDark,
          textPrimary: textPrimary,
          onTap: () => context.push(service.route),
        );
      },
    );
  }
}

class _ApiModuleCard extends StatelessWidget {
  final AppModuleModel module;
  final bool isDark;
  final Color textPrimary;
  final VoidCallback onTap;

  const _ApiModuleCard({
    required this.module,
    required this.isDark,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(
                child: module.mobileMenuIcon.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: module.mobileMenuIcon,
                        width: 42,
                        height: 42,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.apps_rounded,
                          color: Color(0xFFFF5200),
                          size: 40,
                        ),
                      )
                    : const Icon(
                        Icons.apps_rounded,
                        color: Color(0xFFFF5200),
                        size: 40,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            module.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackServiceCard extends StatelessWidget {
  final ServiceItemModel service;
  final bool isDark;
  final Color textPrimary;
  final VoidCallback onTap;

  const _FallbackServiceCard({
    required this.service,
    required this.isDark,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBgColor = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      service.icon,
                      size: 42,
                      color: service.iconColor,
                    ),
                  ),
                  if (service.badgeText != null)
                    Positioned(
                      top: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: service.badgeColor,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          service.badgeText!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            service.label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
