import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/design_system/tokens/module_theme_config.dart';
import 'package:superapp_user/modules/module_id.dart';
import 'package:superapp_user/modules/parcel/parcel_module.dart';

class ParcelHomeScreen extends ConsumerStatefulWidget {
  const ParcelHomeScreen({super.key});

  @override
  ConsumerState<ParcelHomeScreen> createState() => _ParcelHomeScreenState();
}

class _ParcelHomeScreenState extends ConsumerState<ParcelHomeScreen> {
  static const _orange = Color(0xFFFF5C2B);

  /// The module's own palette — the same one ModuleHomeShell paints the
  /// backdrop from, so anything themed here matches it by construction.
  static final _parcelTheme = ModuleThemeConfig.of(ModuleId.parcel);

  @override
  Widget build(BuildContext context) {
    // No location watch here any more: the removed header was its only reader,
    // and the app bar already resolves and shows the address once for the whole
    // shell. Watching it again just rebuilt this screen on every GPS update.
    return Scaffold(
      // Transparent so ModuleHomeShell's violet gradient shows through, the
      // same way the food and taxi home screens do it. An opaque colour here
      // paints straight over the backdrop the shell already drew — which is
      // why this module looked flat next to the other two.
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── CHOOSE A SERVICE title ────────────────────────────────────
          //
          // The orange header that used to sit above this is gone. It carried a
          // back button the module shell already provides, and repeated the
          // pickup address that the app bar shows on every screen — so it cost
          // a fifth of the viewport to say nothing new.
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              child: Column(
                children: [
                  // White, not slate: this sits in the dark half of the shell's
                  // gradient, where the previous near-black would have been
                  // close to invisible.
                  const Text(
                    'Choose a Service',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a vehicle for delivery service',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── SERVICE CARDS GRID ────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverGrid(
              delegate: SliverChildListDelegate([
                _ServiceCard(
                  label: 'Trucks',
                  subtitle: 'Heavy goods delivery',
                  badgeColor: const Color(0xFFFF7B2E),
                  badgeText: 'Trucks',
                  imagePath: 'assets/images/taxi/truck_cat.png',
                  plusColor: _orange,
                  onTap: () => context.push(ParcelRoutePaths.vehicles),
                ),
                _ServiceCard(
                  label: '2 Wheeler',
                  subtitle: 'Fast small parcels',
                  badgeColor: const Color(0xFF1B6FF3),
                  badgeText: '2 Wheeler',
                  imagePath: 'assets/images/taxi/scooter_cat.png',
                  plusColor: const Color(0xFF1B6FF3),
                  onTap: () => context.push(ParcelRoutePaths.vehicles),
                ),
                _ServiceCard(
                  label: 'Auto',
                  subtitle: 'Medium local rides',
                  badgeColor: const Color(0xFF10B981),
                  badgeText: 'Auto',
                  imagePath: 'assets/images/taxi/auto_cat.png',
                  plusColor: const Color(0xFF10B981),
                  onTap: () => context.push(ParcelRoutePaths.vehicles),
                ),
                _ServiceCard(
                  label: 'Packers & Movers',
                  subtitle: 'House shifting & mo...',
                  badgeColor: const Color(0xFF7C3AED),
                  badgeText: 'Packers & Movers',
                  imagePath: 'assets/images/taxi/movers_cat.png',
                  plusColor: const Color(0xFF7C3AED),
                  onTap: () => context.push(ParcelRoutePaths.vehicles),
                ),
              ]),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.88,
              ),
            ),
          ),

          // ── REWARDS BANNER ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  // Parcel's violet, taken from ModuleThemeConfig.of(parcel)
                  // rather than fresh hex, so it stays in step if the module
                  // palette is ever retuned. The old orange was food/taxi's
                  // accent and clashed with the shell gradient behind it.
                  gradient: LinearGradient(
                    colors: [_parcelTheme.activeTabBg, _parcelTheme.activeIndicator],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '\$',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explore Rewards',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Earn 2 coins for every 100 spent',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── TRUST BADGES ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _TrustBadge(
                    icon: Icons.verified_user_rounded,
                    iconColor: Color(0xFF10B981),
                    label: 'Safety Assured',
                    sub: 'Verified Drivers',
                  ),
                  _TrustBadge(
                    icon: Icons.timer_rounded,
                    iconColor: Color(0xFFFF5C2B),
                    label: 'On-Time',
                    sub: 'Fast & Reliable',
                  ),
                  _TrustBadge(
                    icon: Icons.headset_mic_rounded,
                    iconColor: Color(0xFF1B6FF3),
                    label: '24/7 Support',
                    sub: 'Always Active',
                  ),
                  _TrustBadge(
                    icon: Icons.wallet_rounded,
                    iconColor: Color(0xFF7C3AED),
                    label: 'Affordable',
                    sub: 'Best Rates',
                  ),
                ],
              ),
            ),
          ),

          // bottom safe area spacing
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

// ── Service Card ─────────────────────────────────────────────────────────────
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.label,
    required this.subtitle,
    required this.badgeColor,
    required this.badgeText,
    required this.imagePath,
    required this.plusColor,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final Color badgeColor;
  final String badgeText;
  final String imagePath;
  final Color plusColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge top-right + Image
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
              // Vehicle image centered
              Expanded(
                child: Center(
                  child: _VehicleImage(imagePath: imagePath, label: label),
                ),
              ),
              // Label + subtitle + plus button
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: plusColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tries to load the vehicle image asset. Falls back to an icon if the asset
/// doesn't exist yet.
class _VehicleImage extends StatelessWidget {
  const _VehicleImage({required this.imagePath, required this.label});
  final String imagePath;
  final String label;

  static const _iconMap = <String, IconData>{
    'Trucks': Icons.local_shipping_rounded,
    '2 Wheeler': Icons.electric_scooter_rounded,
    'Auto': Icons.electric_rickshaw_rounded,
    'Packers & Movers': Icons.moving_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imagePath,
      height: 80,
      fit: BoxFit.contain,
      errorBuilder: (ctx, err, _) => Icon(
        _iconMap[label] ?? Icons.local_shipping_rounded,
        size: 64,
        color: Colors.grey.shade300,
      ),
    );
  }
}

// ── Trust Badge ───────────────────────────────────────────────────────────────
class _TrustBadge extends StatelessWidget {
  const _TrustBadge({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sub,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
