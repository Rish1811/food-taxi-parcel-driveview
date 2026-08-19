import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:superapp_user/core/utils/haptics.dart';

import 'package:superapp_user/design_system/components/feedback/taxi_snackbar_utils.dart';
import 'package:superapp_user/design_system/components/ride/app_bottom_navigation_bar.dart';
import 'package:superapp_user/modules/taxi/ride/application/ride_providers.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_controller.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_state.dart';
import 'package:superapp_user/modules/taxi/home/application/home_providers.dart';
import 'package:superapp_user/modules/taxi/home/application/saved_places_provider.dart';
import 'package:superapp_user/modules/taxi/home/data/models/app_module_model.dart';
import 'package:superapp_user/modules/taxi/home/data/models/saved_address_model.dart';
import 'package:superapp_user/modules/taxi/taxi_route_names.dart';

class TaxiHomeScreen extends ConsumerStatefulWidget {
  const TaxiHomeScreen({super.key});

  @override
  ConsumerState<TaxiHomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<TaxiHomeScreen> {
  late PageController _pageController;
  Timer? _bannerTimer;
  int _currentBannerIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startBannerAutoSlide();
  }

  void _startBannerAutoSlide() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(
      const Duration(seconds: 3, milliseconds: 500),
      (timer) {
        if (!mounted) return;
        final count = _bannerCount;
        if (count <= 1) return;

        final nextIndex = (_currentBannerIndex + 1) % count;
        if (_pageController.hasClients) {
          if (nextIndex == 0) {
            _pageController.animateToPage(
              0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInOut,
            );
          } else {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _getBannerList() {
    final banners = ref.watch(bannersProvider).value ?? const [];
    if (banners.isNotEmpty) {
      return banners
          .map(
            (b) => {
              'image': (b['image'] ?? '').toString(),
              'link': (b['link'] ?? '').toString(),
            },
          )
          .toList();
    }
    // Default promotional banner list for infinite loop sliding
    return const [
      {'image': 'assets/images/taxi/banner.png', 'link': ''},
      {'image': 'assets/images/taxi/banner.png', 'link': ''},
      {'image': 'assets/images/taxi/banner.png', 'link': ''},
    ];
  }

  int get _bannerCount => _getBannerList().length;

  /// Promotional banner carousel with auto-sliding infinite loop
  Widget _buildPromoBanner() {
    final banners = _getBannerList();

    return SizedBox(
      height: 115,
      width: double.infinity,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentBannerIndex = index;
          });
        },
        itemCount: banners.length,
        itemBuilder: (context, index) {
          final item = banners[index];
          final img = item['image'] ?? '';
          final link = item['link'] ?? '';

          Widget imageWidget;
          if (img.startsWith('http')) {
            imageWidget = CachedNetworkImage(
              imageUrl: img,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 115,
              placeholder: (context, url) =>
                  Image.asset('assets/images/taxi/banner.png', fit: BoxFit.cover),
              errorWidget: (context, url, error) =>
                  Image.asset('assets/images/taxi/banner.png', fit: BoxFit.cover),
            );
          } else {
            imageWidget = Image.asset(
              img.isNotEmpty ? img : 'assets/images/taxi/banner.png',
              fit: BoxFit.cover,
              width: double.infinity,
              height: 115,
              errorBuilder: (context, error, stackTrace) =>
                  Image.asset('assets/images/taxi/banner.png', fit: BoxFit.cover),
            );
          }

          return GestureDetector(
            onTap: link.isEmpty ? null : () => _openBannerLink(link),
            child: imageWidget,
          );
        },
      ),
    );
  }

  Future<void> _openBannerLink(String link) async {
    // Deep links stay inside the app; anything else is a normal URL.
    if (link.startsWith('/')) {
      if (mounted) context.push(link);
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _handleHomeWorkTap(
    String slotType,
    SavedAddressModel? saved,
  ) async {
    if (saved == null) {
      // '/home/map-picker' is the standalone taxi app's path and is not
      // registered in super_app's router, so this push never resolved: the map
      // never opened, nothing could be saved, and the shortcut could therefore
      // never book a ride either. The route lives at TaxiRoutePaths.pickOnMap.
      final result = await context.push<Map<String, dynamic>>(
        '${TaxiRoutePaths.pickOnMap}?type=drop',
      );
      if (result != null && mounted) {
        final String addr = result['address'] ?? '';
        final double lat = (result['lat'] as num?)?.toDouble() ?? 0;
        final double lng = (result['lng'] as num?)?.toDouble() ?? 0;
        if (addr.isNotEmpty && lat != 0 && lng != 0) {
          await ref
              .read(savedPlacesProvider.notifier)
              .saveHomeOrWork(
                type: slotType,
                address: addr,
                lat: lat,
                lng: lng,
              );
          if (mounted) {
            SnackbarUtils.info(
              context,
              '${slotType.toLowerCase() == 'home' ? 'Home' : 'Work'} location saved!',
            );
          }
        }
      }
    } else {
      // currentPositionProvider is a FutureProvider, so `.value` is null until
      // it resolves — which it usually has not on a cold open, exactly when
      // someone taps a shortcut. The old fallback quietly booked from Indore
      // city centre, sending a driver to a place the rider had never been.
      // Wait for the real fix instead, and say so rather than inventing one.
      Position? currentPos = ref.read(currentPositionProvider).value;
      if (currentPos == null) {
        try {
          currentPos = await ref.read(currentPositionProvider.future);
        } catch (_) {
          currentPos = null;
        }
      }
      if (!mounted) return;
      if (currentPos == null) {
        SnackbarUtils.info(
          context,
          'Still finding your location — try again in a moment.',
        );
        return;
      }

      final pickupAddr =
          ref.read(currentAddressProvider).value ?? 'Current Location';
      final pickupLoc = BookingLocation(
        lat: currentPos.latitude,
        lng: currentPos.longitude,
        address: pickupAddr,
      );

      final dropLoc = BookingLocation(
        lat: saved.lat,
        lng: saved.lng,
        address: saved.address,
      );

      ref.read(bookingControllerProvider.notifier)
        ..setPickup(pickupLoc)
        ..setDrop(dropLoc);

      if (mounted) {
        context.push('/taxi/vehicles');
      }
    }
  }

  Widget _buildOngoingRideCard(BuildContext context) {
    final ride = ref.watch(myActiveRideProvider).value;
    if (ride == null) return const SizedBox.shrink();

    const finished = {'completed', 'cancelled', 'canceled'};
    if (finished.contains(ride.liveStatus) || finished.contains(ride.status)) {
      return const SizedBox.shrink();
    }



    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: GestureDetector(
        onTap: () async {
          await context.push('/taxi/rides/${ride.rideId}/track');
          if (context.mounted) ref.invalidate(myActiveRideProvider);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(13),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 10,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C2B),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.directions_car_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'ONGOING RIDE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '₹${ride.fare.round()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(color: Colors.white.withValues(alpha: 0.1), height: 1, thickness: 1),
              const SizedBox(height: 8),
              // Addresses
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 5),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981), // Green
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 14,
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444), // Red
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.pickupAddress.isNotEmpty ? ride.pickupAddress : 'Pickup Location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ride.dropAddress.isNotEmpty ? ride.dropAddress : 'Drop Location',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedPlaces = ref.watch(savedPlacesProvider);
    SavedAddressModel? homePlace;
    SavedAddressModel? workPlace;
    for (final p in savedPlaces) {
      final t = p.type.toLowerCase();
      final l = p.label.toLowerCase();
      if (t == 'home' || l == 'home') {
        homePlace = p;
      } else if (t == 'work' || l == 'work') {
        workPlace = p;
      }
    }

    final modulesAsync = ref.watch(appModulesProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                16, 12, 16,
                // 60 nav bar + the same trimmed inset the bar itself uses.
                // Reserving the full system inset here left the last card
                // floating well above the nav on 3-button-nav devices.
                60 +
                    (MediaQuery.of(context).padding.bottom > 12
                        ? 12
                        : MediaQuery.of(context).padding.bottom) +
                    16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ongoing active ride alert card if active
                  // _buildOngoingRideCard(context),

                  // Destination Search Box
                  InkWell(
                    onTap: () => context.push('/taxi/destination'),
                    borderRadius: BorderRadius.circular(26),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x12000000),
                            blurRadius: 12,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFFF5C2B),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Where are you going?',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5C2B),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // --- 3. QUICK SAVED LOCATIONS ROW ---
                  Row(
                    children: [
                      _QuickLocationCard(
                        icon: Icons.business_rounded,
                        iconColor: const Color(0xFF3B82F6),
                        title: 'Work',
                        subtitle: workPlace != null
                            ? (workPlace.address.isNotEmpty
                                  ? workPlace.address
                                  : 'Saved location')
                            : 'Set location',
                        onTap: () => _handleHomeWorkTap('work', workPlace),
                      ),
                      const SizedBox(width: 8),
                      _QuickLocationCard(
                        icon: Icons.home_rounded,
                        iconColor: const Color(0xFFEF4444),
                        title: 'Home',
                        subtitle: homePlace != null
                            ? (homePlace.address.isNotEmpty
                                  ? homePlace.address
                                  : 'Saved location')
                            : 'Set location',
                        onTap: () => _handleHomeWorkTap('home', homePlace),
                      ),
                      const SizedBox(width: 8),
                      _QuickLocationCard(
                        icon: Icons.star_rounded,
                        iconColor: const Color(0xFFF59E0B),
                        title: 'Saved',
                        subtitle: 'Your places',
                        onTap: () => context.push('/taxi/saved-places'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // --- 4. PROMOTIONAL BANNER CAROUSEL ---
                  InkWell(
                    onTap: () => context.push('/taxi/destination'),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      height: 115,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _buildPromoBanner(),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Carousel Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_bannerCount, (index) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        width: index == _currentBannerIndex ? 12 : 4.5,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: index == _currentBannerIndex
                              ? const Color(0xFFFF5C2B)
                              : const Color(0xFFCBD5E1),
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 7),

                  // --- 5. OUR SERVICES SECTION ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Our Services',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      InkWell(
                        onTap: () => context.push('/taxi/services'),
                        child: const Row(
                          children: [
                            Text(
                              'View all',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFF5C2B),
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFFFF5C2B),
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                 // const SizedBox(height: 8),

                  // Services Row (Taxi, Bike, Parcel, Outstation)
                  _buildServicesGrid(modulesAsync),
                  _buildOngoingRideCard(context),
                  const SizedBox(height: 16),

                  // --- 6. WHAT DO YOU NEED TODAY? SECTION ---
                  const Text(
                    'What do you need today?',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 2 Side-by-Side Large Promotional Featured Cards (Ride Now & Delivery with text)
                  Row(
                    children: [
                      // Card 1: Ride Now
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Haptics.light();
                            context.push('/taxi/destination');
                          },
                          child: Container(
                            height: 135,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    'assets/images/taxi/Ridenow.png',
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Image.asset(
                                              'assets/images/taxi/Ridenow.png',
                                              fit: BoxFit.cover,
                                            ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Ride Now',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            width: 18,
                                            height: 18,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Color(0xFFFF5C2B),
                                              size: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Quick & comfortable\nrides anytime',
                                        style: TextStyle(
                                          fontSize: 10,
                                          height: 1.2,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Card 2: Delivery
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Haptics.light();
                            context.push('/parcel/vehicles');
                          },
                          child: Container(
                            height: 135,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x0A000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Image.asset(
                                    'assets/images/taxi/Delivery.png',
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (
                                          context,
                                          error,
                                          stackTrace,
                                        ) => Image.asset(
                                          'assets/images/taxi/Delivery.png',
                                          fit: BoxFit.cover,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Delivery',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            width: 18,
                                            height: 18,
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.arrow_forward_rounded,
                                              color: Color(0xFF10B981),
                                              size: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      const Text(
                                        'Send anything\nanywhere',
                                        style: TextStyle(
                                          fontSize: 10,
                                          height: 1.2,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
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
            ),

            // --- 7. BOTTOM NAVIGATION BAR ---
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppBottomNavigationBar(currentIndex: 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServicesGrid(AsyncValue<List<AppModuleModel>> modulesAsync) {
    final bgColors = [
      const Color(0xFFFFF0EA),
      const Color(0xFFE6F8F0),
      const Color(0xFFF3E8FF),
      const Color(0xFFE0F2FE),
      const Color(0xFFFEF3C7),
    ];

    return modulesAsync.when(
      data: (modules) {
        final activeModules = modules.where((m) => m.active).toList();
        activeModules.sort((a, b) => a.orderBy.compareTo(b.orderBy));

        final listToRender = activeModules.isNotEmpty
            ? activeModules
            : _getFallbackModules();

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 8,
            // Sized to the content (48 icon + 6 gap + one label line + 20 padding).
            // A ratio of 0.85 avoids the RenderFlex vertical overflow on small screens.
            childAspectRatio: 0.82,
          ),
          itemCount: listToRender.length,
          itemBuilder: (context, index) {
            final item = listToRender[index];
            return _buildServiceItem(item, bgColors[index % bgColors.length]);
          },
        );
      },
      loading: () => _buildStaticServicesGrid(bgColors),
      error: (e, st) => _buildStaticServicesGrid(bgColors),
    );
  }

  Widget _buildStaticServicesGrid(List<Color> bgColors) {
    final fallbackList = _getFallbackModules();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 10,
        crossAxisSpacing: 8,
        childAspectRatio: 0.82,
      ),
      itemCount: fallbackList.length,
      itemBuilder: (context, index) {
        final item = fallbackList[index];
        return _buildServiceItem(item, bgColors[index % bgColors.length]);
      },
    );
  }

  Widget _buildServiceItem(AppModuleModel m, Color bgColor) {
    final String iconUrl = m.mobileMenuIcon;
    final String sName = m.name;
    final String sType = '${m.serviceType} ${m.transportType} ${m.name}'
        .toLowerCase();

    String fallbackAsset = 'assets/images/taxi/taxi_service.png';
    IconData fallbackIcon = Icons.local_taxi_rounded;

    if (sType.contains('bike') || sType.contains('moto')) {
      fallbackAsset = 'assets/images/taxi/bike_service.png';
      fallbackIcon = Icons.two_wheeler_rounded;
    } else if (sType.contains('parcel') || sType.contains('delivery')) {
      fallbackAsset = 'assets/images/taxi/parcel_service.png';
      fallbackIcon = Icons.inventory_2_rounded;
    } else if (sType.contains('outstation') || sType.contains('intercity')) {
      fallbackAsset = 'assets/images/taxi/outstation_service.png';
      fallbackIcon = Icons.directions_bus_rounded;
    } else if (sType.contains('rental')) {
      fallbackAsset = 'assets/images/taxi/2.png';
      fallbackIcon = Icons.electric_rickshaw_rounded;
    }

    void onTap() {
      Haptics.light();
      if (sType.contains('parcel') || sType.contains('delivery')) {
        context.push('/parcel/vehicles');
      } else if (sType.contains('rental')) {
        context.push('/rental');
      } else if (sType.contains('outstation')) {
        // No outstation screen exists in either source app -- the original
        // taxi router had no /outstation route either, so this tile has always
        // been a dead link. Outstation is a ride *type*, so start the normal
        // booking funnel; the intercity package picker
        // (GET /taxi/users/intercity-packages) is a separate build.
        context.push('/taxi/destination');
      } else {
        context.push('/taxi/destination');
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Soft colored icon box for the vehicle image
            Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: iconUrl.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: iconUrl,
                      fit: BoxFit.contain,
                      placeholder: (context, url) =>
                          Image.asset(fallbackAsset, fit: BoxFit.contain),
                      errorWidget: (context, url, error) => Image.asset(
                        fallbackAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          fallbackIcon,
                          color: const Color(0xFFFF5C2B),
                          size: 24,
                        ),
                      ),
                    )
                  : Image.asset(
                      fallbackAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        fallbackIcon,
                        color: const Color(0xFFFF5C2B),
                        size: 24,
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            // Service name text positioned right under the image box
            Text(
              sName,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<AppModuleModel> _getFallbackModules() {
    return const [
      AppModuleModel(
        id: '1',
        name: 'Taxi',
        transportType: 'taxi',
        serviceType: 'daily',
        orderBy: 1,
        shortDescription: 'Ride in city',
        description: 'Taxi ride',
        mobileMenuIcon: '',
        active: true,
      ),
      AppModuleModel(
        id: '2',
        name: 'Bike',
        transportType: 'bike',
        serviceType: 'daily',
        orderBy: 2,
        shortDescription: 'Quick bike ride',
        description: 'Bike ride',
        mobileMenuIcon: '',
        active: true,
      ),
      AppModuleModel(
        id: '3',
        name: 'Parcel',
        transportType: 'parcel',
        serviceType: 'delivery',
        orderBy: 3,
        shortDescription: 'Send anything',
        description: 'Parcel delivery',
        mobileMenuIcon: '',
        active: true,
      ),
      AppModuleModel(
        id: '4',
        name: 'Outstation',
        transportType: 'outstation',
        serviceType: 'outstation',
        orderBy: 4,
        shortDescription: 'Intercity trips',
        description: 'Outstation cab',
        mobileMenuIcon: '',
        active: true,
      ),
    ];
  }
}

/// Quick Location Card (Work, Home, Saved)
class _QuickLocationCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickLocationCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

