import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/modules/taxi/home/application/booking_state.dart';
import 'package:superapp_user/modules/taxi/home/application/home_providers.dart';
import 'package:superapp_user/modules/parcel/application/delivery_booking_controller.dart';
import 'package:superapp_user/modules/parcel/application/delivery_categories.dart';

/// Step 1 of the delivery flow: select vehicle category.
/// Matches reference UI with light orange header theme, 2x2 category tiles with plus buttons,
/// Explore Rewards banner, and bottom trust badges.
class DeliveryVehicleScreen extends ConsumerStatefulWidget {
  const DeliveryVehicleScreen({super.key});

  @override
  ConsumerState<DeliveryVehicleScreen> createState() =>
      _DeliveryVehicleScreenState();
}

class _DeliveryVehicleScreenState extends ConsumerState<DeliveryVehicleScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedPickup());
  }

  /// Seeds the pickup from the rider's current location so the flow opens with
  /// a usable address instead of an empty field.
  Future<void> _seedPickup() async {
    if (ref.read(deliveryBookingProvider).pickup != null) return;
    final position = await ref.read(currentPositionProvider.future);
    final address = await ref.read(currentAddressProvider.future);
    if (position == null || !mounted) return;

    ref
        .read(deliveryBookingProvider.notifier)
        .setPickup(
          BookingLocation(
            lat: position.latitude,
            lng: position.longitude,
            address: address,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final pickup = ref.watch(deliveryBookingProvider).pickup;
    final addressAsync = ref.watch(currentAddressProvider);
    final currentAddr = addressAsync.value ?? 'Fetching location...';
    final addressToDisplay = (pickup?.address != null && pickup!.address.isNotEmpty)
        ? pickup.address
        : currentAddr;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Top Lighter Orange Header Section
            _HeaderSection(
              address: addressToDisplay,
              onBack: () => Navigator.of(context).maybePop(),
              onAddressTap: () {
                context.push('/parcel/addresses');
              },
            ),

            // Content Area under Header
            Transform.translate(
              offset: const Offset(0, 0),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    // Subheader Section: "Choose a Service"
                    Row(
                      children: const [
                        Expanded(
                          child: Divider(
                            color: Color(0xFFE2E8F0),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(16.0, 18.0, 16.0, 0.0),
                          child: Text( 
                            'Choose a Service',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Color(0xFFE2E8F0),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Select a vehicle for delivery service',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2x2 Category Cards Grid
                    GridView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.94,
                          ),
                      itemCount: kDeliveryCategories.length,
                      itemBuilder: (context, index) {
                        final category = kDeliveryCategories[index];
                        return _CategoryCardTile(
                          category: category,
                          index: index,
                          onTap: () {
                            ref
                                .read(deliveryBookingProvider.notifier)
                                .selectDeliveryCategory(category.id);
                            context.push('/parcel/addresses');
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Explore Rewards Banner
                    const _ExploreRewardsBanner(),

                    const SizedBox(height: 20),

                    // Bottom Trust Badges Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: const [
                        _TrustBadge(
                          icon: Icons.verified_user_rounded,
                          iconColor: Color(0xFF10B981),
                          title: 'Safety Assured',
                          subtitle: 'Verified Drivers',
                        ),
                        _TrustBadge(
                          icon: Icons.timer_rounded,
                          iconColor: Color(0xFFFF5C2B),
                          title: 'On-Time',
                          subtitle: 'Fast & Reliable',
                        ),
                        _TrustBadge(
                          icon: Icons.headset_mic_rounded,
                          iconColor: Color(0xFF3B82F6),
                          title: '24/7 Support',
                          subtitle: 'Always Active',
                        ),
                        _TrustBadge(
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: Color(0xFF8B5CF6),
                          title: 'Affordable',
                          subtitle: 'Best Rates',
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Bottom Ghosted Logistics Illustration
                    Center(
                      child: Opacity(
                        opacity: 0.20,
                        child: Image.asset(
                          'assets/images/taxi/bottom_truck_bg.png',
                          height: 95,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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

/// Top Extended Header containing Back Button & Pickup Address Card
/// Features a lighter, warmer vibrant orange gradient as requested.
class _HeaderSection extends StatelessWidget {
  final String address;
  final VoidCallback onBack;
  final VoidCallback onAddressTap;

  const _HeaderSection({
    required this.address,
    required this.onBack,
    required this.onAddressTap,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        // Warm lighter orange gradient
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF8550), Color(0xFFFF6933)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Stack(
        children: [
          // Background subtle vector map graphic
          Positioned(
            right: -10,
            top: 0,
            width: 220,
            height: 110,
            child: Opacity(
              opacity: 0.18,
              // child: Image.asset(
              //   'assets/images/taxi/top_map_bg.png',
              //   fit: BoxFit.cover,
              //   errorBuilder: (_, _, _) => const SizedBox.shrink(),
              // ),
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: topPadding + 6),

              // Top Left Back Button (Translucent rounded button)
              Padding(
                padding: const EdgeInsets.only(left: 14.0, bottom: 10.0),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),

              // White Pickup Card inside Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: InkWell(
                  onTap: onAddressTap,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Green Pin Location Badge
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6F8F0),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.location_on_outlined,
                              color: Color(0xFF10B981),
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Pickup Address Label & Text
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'PICK UP FROM',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Right Chevron Arrow
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Category Card Widget with 3D image asset, category badge, description, and accent plus button
class _CategoryCardTile extends StatelessWidget {
  final DeliveryCategory category;
  final int index;
  final VoidCallback onTap;

  const _CategoryCardTile({
    required this.category,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Unique accent styling per category card
    final tagBgColors = [
      const Color(0xFFFFF7ED), // Trucks
      const Color(0xFFEFF6FF), // 2 Wheeler
      const Color(0xFFF0FDF4), // Auto
      const Color(0xFFFAF5FF), // Movers
    ];

    final tagTextColors = [
      const Color(0xFFFF5C2B),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
    ];

    final plusBtnColors = [
      const Color(0xFFFF5C2B),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFF8B5CF6),
    ];

    final tagBg = tagBgColors[index % tagBgColors.length];
    final tagText = tagTextColors[index % tagTextColors.length];
    final plusColor = plusBtnColors[index % plusBtnColors.length];

    String assetToUse = category.assetImage;
    if (assetToUse.isEmpty) {
      if (category.id == 'trucks') assetToUse = 'assets/images/taxi/truck_cat.png';
      if (category.id == '2wheeler') assetToUse = 'assets/images/taxi/scooter_cat.png';
      if (category.id == 'auto') assetToUse = 'assets/images/taxi/auto_cat.png';
      if (category.id == 'movers') assetToUse = 'assets/images/taxi/movers_cat.png';
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Stack(
            children: [
              // Top Right Category Tag
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: tagBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    category.title,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: tagText,
                    ),
                  ),
                ),
              ),

              // Main Content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // Vehicle 3D Image
                  Expanded(
                    child: Center(
                      child: assetToUse.isNotEmpty
                          ? Image.asset(
                              assetToUse,
                              height: 74,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Icon(
                                category.icon,
                                size: 44,
                                color: plusColor,
                              ),
                            )
                          : Icon(category.icon, size: 44, color: plusColor),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Title Text
                  Text(
                    category.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 1),

                  // Bottom Row: Description & Plus Action Button
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getShortDesc(category.id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: plusColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getShortDesc(String id) {
    switch (id) {
      case 'trucks':
        return 'Heavy goods delivery';
      case '2wheeler':
        return 'Fast small parcels';
      case 'auto':
        return 'Medium local rides';
      case 'movers':
        return 'House shifting & move';
      default:
        return 'Quick delivery';
    }
  }
}

/// "Explore Rewards" Light Orange Gradient Banner widget
class _ExploreRewardsBanner extends StatelessWidget {
  const _ExploreRewardsBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFFF7A45), Color(0xFFFF5C2B)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2BFF5C2B),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Gold Coin Icon Badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFDF00), Color(0xFFD4AF37)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text(
                '\$',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 2,
                      offset: Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Title & Description
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Explore Rewards',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 1),
                Text(
                  'Earn 2 coins for every 100 spent',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFFFEAE2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // Right Arrow Button
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Trust Badge Item for bottom bar
class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _TrustBadge({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 8.5,
            fontWeight: FontWeight.w500,
            color: Color(0xFF94A3B8),
          ),
        ),
      ],
    );
  }
}
