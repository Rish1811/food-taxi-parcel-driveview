import 'package:superapp_user/core/config/api_config.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:superapp_user/core/maps/route_polyline_service.dart';
import 'package:superapp_user/core/maps/app_map_style.dart';
import 'package:superapp_user/design_system/components/ride/custom_bottom_sheet.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_controller.dart';
import 'package:superapp_user/modules/taxi/home/data/models/vehicle_type_model.dart';

import 'package:superapp_user/core/maps/route_marker_helper.dart';
import 'package:superapp_user/modules/taxi/home/presentation/nearby_driver_markers.dart';

const _fallbackLatLng = LatLng(22.7196, 75.8577);

class RideTypeScreen extends ConsumerStatefulWidget {
  const RideTypeScreen({super.key});

  @override
  ConsumerState<RideTypeScreen> createState() => _RideTypeScreenState();
}

class _RideTypeScreenState extends ConsumerState<RideTypeScreen> {
  GoogleMapController? _mapController;
  List<LatLng> _routePoints = [];
  Map<String, BitmapDescriptor> _customMarkers = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingControllerProvider.notifier).loadCatalog();
      _fetchRoutePolyline();
      _generateCustomMarkers();
    });
  }

  Future<void> _generateCustomMarkers() async {
    final booking = ref.read(bookingControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);

    final Map<String, BitmapDescriptor> markers = {};

    if (booking.pickup != null) {
      markers['pickup'] = await RouteMarkerHelper.createCustomPinWithLabel(
        labelText: booking.pickup!.address,
        pinColor: const Color(0xFF10B981),
        boxBgColor: boxBgColor,
        textColor: textColor,
        prefix: 'Pickup',
      );
    }

    if (booking.drop != null) {
      markers['drop'] = await RouteMarkerHelper.createCustomPinWithLabel(
        labelText: booking.drop!.address,
        pinColor: const Color(0xFFFF5C2B),
        boxBgColor: boxBgColor,
        textColor: textColor,
        prefix: 'Drop',
      );
    }

    for (int i = 0; i < booking.stops.length; i++) {
      markers['stop_$i'] = await RouteMarkerHelper.createCustomPinWithLabel(
        labelText: booking.stops[i].address,
        pinColor: const Color(0xFF3B82F6),
        boxBgColor: boxBgColor,
        textColor: textColor,
        prefix: 'Stop ${i + 1}',
      );
    }

    if (mounted) {
      setState(() {
        _customMarkers = markers;
      });
    }
  }

  Future<void> _fetchRoutePolyline() async {
    final booking = ref.read(bookingControllerProvider);
    if (booking.pickup == null || booking.drop == null) return;

    final pickup = LatLng(booking.pickup!.lat, booking.pickup!.lng);
    final drop = LatLng(booking.drop!.lat, booking.drop!.lng);
    final stops = booking.stops.map((s) => LatLng(s.lat, s.lng)).toList();

    final points = await RoutePolylineService.getRoutePoints(
      pickup: pickup,
      drop: drop,
      stops: stops,
    );

    if (mounted) {
      setState(() {
        _routePoints = points;
      });
      _fitRouteBounds(points);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _fitRouteBounds(_routePoints);
  }

  void _fitRouteBounds([List<LatLng>? points]) {
    final booking = ref.read(bookingControllerProvider);
    if (booking.pickup == null || booking.drop == null || _mapController == null) return;

    final pickup = LatLng(booking.pickup!.lat, booking.pickup!.lng);
    final drop = LatLng(booking.drop!.lat, booking.drop!.lng);

    final allPoints = (points != null && points.isNotEmpty) ? points : [pickup, drop];

    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  String _formatDropTime(double? durationSeconds) {
    final minutes = (durationSeconds ?? 0) / 60;
    final dropTime = DateTime.now().add(Duration(minutes: minutes.round()));
    final hour = dropTime.hour > 12 ? dropTime.hour - 12 : (dropTime.hour == 0 ? 12 : dropTime.hour);
    final minute = dropTime.minute.toString().padLeft(2, '0');
    final period = dropTime.hour >= 12 ? 'pm' : 'am';
    return 'Drop $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    final booking = ref.watch(bookingControllerProvider);
    final controller = ref.read(bookingControllerProvider.notifier);

    final pickupLatLng = booking.pickup != null
        ? LatLng(booking.pickup!.lat, booking.pickup!.lng)
        : _fallbackLatLng;
    final dropLatLng =
        booking.drop != null ? LatLng(booking.drop!.lat, booking.drop!.lng) : _fallbackLatLng;

    // Default 2-point line if road polyline is loading
    final List<LatLng> fallbackPolylinePoints = [
      pickupLatLng,
      ...booking.stops.map((s) => LatLng(s.lat, s.lng)),
      dropLatLng,
    ];

    final activePoints = _routePoints.isNotEmpty ? _routePoints : fallbackPolylinePoints;

    // Live vehicles from /rides/available-drivers, polled every 20s. This used
    // to render nothing at all: the endpoint required a vehicleTypeId the map
    // never sends, so every poll 400'd and the failure was swallowed into an
    // empty list. The only thing on the map was a decorative marker pinned to
    // a point on the route line — a vehicle that did not exist.
    final nearbyDriverMarkers = buildNearbyDriverMarkers(ref);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ==================== LAYER 1: INTERACTIVE GOOGLE MAP WITH ROUTE ====================
          Positioned.fill(
            child: Stack(
              children: [
                GoogleMap(
                  style: AppMapStyle.muted,
                  initialCameraPosition: CameraPosition(target: pickupLatLng, zoom: 14),
                  onMapCreated: _onMapCreated,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  polylines: {
                    Polyline(
                      polylineId: const PolylineId('ride_route'),
                      points: activePoints,
                      color: const Color(0xFF0F172A),
                      width: 5,
                      jointType: JointType.round,
                      startCap: Cap.roundCap,
                      endCap: Cap.roundCap,
                    ),
                  },

                  markers: {
                    ...nearbyDriverMarkers,
                    Marker(
                      markerId: const MarkerId('pickup_marker'),
                      position: pickupLatLng,
                      icon: _customMarkers['pickup'] ??
                          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                    ),
                    Marker(
                      markerId: const MarkerId('drop_marker'),
                      position: dropLatLng,
                      icon: _customMarkers['drop'] ??
                          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                    ),
                    for (int i = 0; i < booking.stops.length; i++)
                      Marker(
                        markerId: MarkerId('stop_$i'),
                        position: LatLng(booking.stops[i].lat, booking.stops[i].lng),
                        icon: _customMarkers['stop_$i'] ??
                            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                      ),
                  },
                ),

                // ==================== TOP FLOATING BACK BUTTON ====================
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  left: 16,
                  child: FloatingActionButton.small(
                    heroTag: 'back_btn',
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    elevation: 3,
                    onPressed: () => context.pop(),
                    child: const Icon(Icons.arrow_back_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),

          // ==================== LAYER 2: VEHICLE SELECTION BOTTOM SHEET ====================
          DraggableScrollableSheet(
            initialChildSize: 0.62,
            minChildSize: 0.62,
            maxChildSize: 0.85,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 18,
                      offset: Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Drag Handle Bar
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 10, bottom: 16),
                        width: 48,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Category Pill
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFD0D5DD)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'CATEGORY: ${booking.selectedVehicle?.name.toUpperCase() ?? 'RIDE'}',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2563EB),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Route Summary
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline indicators
                          Column(
                            children: [
                              const SizedBox(height: 4),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 28,
                                color: const Color(0xFFCBD5E1),
                              ),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFF5C2B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          // Addresses
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.pickup?.address ?? 'Pickup Location',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  booking.drop?.address ?? 'Drop Location',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Edit & Now buttons
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              InkWell(
                                onTap: () => context.pop(),
                                child: const Padding(
                                  padding: EdgeInsets.all(4.0),
                                  child: Text(
                                    'Edit',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF0F172A)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Now',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.w500,
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
                    const SizedBox(height: 12),

                    // Distance and Time Pills
                    Padding(
                      padding: const EdgeInsets.only(left: 36, right: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${((booking.distanceMeters ?? 0) / 1000).toStringAsFixed(1)} km',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${((booking.durationSeconds ?? 0) / 60).round()} mins',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

                    // Scrollable Vehicle Types List
                    Expanded(
                      child: booking.vehicleTypes.isEmpty
                          // A failed load used to render the same spinner as a
                          // pending one, so a dead endpoint looked like an
                          // endless loader with no way out.
                          ? (booking.error != null
                              ? _VehicleLoadError(
                                  message: booking.error!,
                                  onRetry: () => ref
                                      .read(bookingControllerProvider.notifier)
                                      .loadCatalog(),
                                )
                              : const Center(child: CircularProgressIndicator()))
                          : ListView.separated(
                              controller: scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: booking.vehicleTypes.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final vehicle = booking.vehicleTypes[index];
                                final fare = controller.fareForVehicle(vehicle);
                                final isSelected = booking.selectedVehicle?.id == vehicle.id;
                                final dropTimeStr = _formatDropTime(booking.durationSeconds);
                                final etaMinutes = booking.etaMinutesByVehicle[vehicle.id];

                                return _VehicleSelectionTile(
                                  vehicle: vehicle,
                                  calculatedPrice: fare?.total,
                                  dropTimeStr: dropTimeStr,
                                  etaMinutes: etaMinutes,
                                  isSelected: isSelected,
                                  onTap: () => controller.selectVehicle(vehicle),
                                );
                              },
                            ),
                    ),

                    // --- BOTTOM STICKY ACTION BAR ---
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Payment Method & Offers Row (Segmented style)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                // Cash
                                Expanded(
                                  child: InkWell(
                                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                                    onTap: () => _showPaymentSheet(context, controller, booking.paymentMethod),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.money, size: 16, color: Color(0xFF10B981)),
                                          const SizedBox(width: 6),
                                          Text(
                                            booking.paymentMethod == 'cash' ? 'Cash' : booking.paymentMethod.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(height: 18, width: 1, color: const Color(0xFFE2E8F0)),
                                // Coupon
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _showPromoSheet(context, controller, booking.promoCode),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          const Icon(Icons.local_activity_outlined, size: 16, color: Color(0xFF3B82F6)),
                                          const SizedBox(width: 6),
                                          Text(
                                            booking.promoCode ?? 'Coupon',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Container(height: 18, width: 1, color: const Color(0xFFE2E8F0)),
                                // Myself
                                Expanded(
                                  child: InkWell(
                                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
                                    onTap: () {},
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF3B82F6),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Myself',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Large CTA Button (Book New vehicle)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: booking.isSubmitting
                                  ? null
                                  : () async {
                                      final success = await controller.confirmBooking();
                                      if (!context.mounted) return;
                                      if (success) {
                                        context.pushReplacement('/taxi/searching');
                                      } else {
                                        context.pushReplacement('/taxi/no-driver');
                                      }
                                    },
                              child: booking.isSubmitting
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Book ${booking.selectedVehicle?.name ?? 'vehicle'}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
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
            },
          ),
        ],
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, BookingController controller, String current) {
    CustomBottomSheet.show(
      context,
      title: 'Payment method',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Cash'),
            leading: const Icon(Icons.money_rounded),
            trailing: current == 'cash' ? const Icon(Icons.check_rounded, color: Color(0xFF10B981)) : null,
            onTap: () {
              controller.setPaymentMethod('cash');
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            title: const Text('Wallet'),
            leading: const Icon(Icons.account_balance_wallet_outlined),
            trailing: current == 'wallet' ? const Icon(Icons.check_rounded, color: Color(0xFF10B981)) : null,
            onTap: () {
              controller.setPaymentMethod('wallet');
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            title: const Text('Card / UPI'),
            leading: const Icon(Icons.credit_card_rounded),
            trailing: current == 'razorpay' ? const Icon(Icons.check_rounded, color: Color(0xFF10B981)) : null,
            onTap: () {
              controller.setPaymentMethod('razorpay');
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showPromoSheet(BuildContext context, BookingController controller, String? currentPromo) {
    final textController = TextEditingController(text: currentPromo);
    CustomBottomSheet.show(
      context,
      title: 'Apply Coupon',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: textController,
              decoration: const InputDecoration(
                hintText: 'Enter promo code (e.g. RIDE100)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                controller.applyPromoCode(textController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleSelectionTile extends StatelessWidget {
  final VehicleTypeModel vehicle;
  final double? calculatedPrice;
  final String dropTimeStr;
  final int? etaMinutes;
  final bool isSelected;
  final VoidCallback onTap;

  const _VehicleSelectionTile({
    required this.vehicle,
    required this.calculatedPrice,
    required this.dropTimeStr,
    required this.etaMinutes,
    required this.isSelected,
    required this.onTap,
  });

  /// Bundled art for a vehicle type, used only when the admin has not
  /// uploaded an image for it.
  ///
  /// These live under assets/images/taxi/ — the paths used to point at
  /// assets/*.png, which never existed in this project and produced
  /// "Unable to load asset: assets/bike.png" on every row.
  static String _assetForVehicle(String iconType, String name) {
    final lower = '$iconType $name'.toLowerCase();
    if (lower.contains('bike') || lower.contains('moto')) {
      return 'assets/images/taxi/bike.png';
    }
    if (lower.contains('scooter')) return 'assets/images/taxi/scooter_cat.png';
    if (lower.contains('auto') || lower.contains('rickshaw')) {
      return 'assets/images/taxi/auto_cat.png';
    }
    if (lower.contains('truck') || lower.contains('tempo')) {
      return 'assets/images/taxi/truck_cat.png';
    }
    if (lower.contains('mover') || lower.contains('packer')) {
      return 'assets/images/taxi/movers_cat.png';
    }
    if (lower.contains('parcel') || lower.contains('delivery')) {
      return 'assets/images/taxi/parcel.png';
    }
    if (lower.contains('cab') || lower.contains('car') || lower.contains('sedan') ||
        lower.contains('suv') || lower.contains('taxi')) {
      return 'assets/images/taxi/car.png';
    }
    return 'assets/images/taxi/booknow.png';
  }

  @override
  Widget build(BuildContext context) {
    final assetPath = _assetForVehicle(vehicle.iconType, vehicle.name);

    // The admin-uploaded image is the source of truth; the bundled asset is
    // only a fallback for vehicle types that have none configured yet.
    // map_icon is tried second because the backend often has only one of the
    // two set for a given type.
    //
    // resolveMedia is what makes this work at all: uploads come back as
    // relative paths ('/uploads/...') as often as absolute URLs, and
    // CachedNetworkImage cannot fetch a relative path.
    final rawImage = vehicle.image.trim().isNotEmpty
        ? vehicle.image.trim()
        : vehicle.mapIcon.trim();
    final backendImageUrl = ApiConfig.resolveMedia(rawImage);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: const Color(0xFF0F172A), width: 1.5)
              : Border.all(color: const Color(0xFFF1F5F9), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: Vehicle Icon & ETA
            Column(
              children: [
                backendImageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: backendImageUrl,
                        width: 42,
                        height: 34,
                        fit: BoxFit.contain,
                        errorWidget: (context, url, error) => Image.asset(
                          assetPath,
                          width: 42,
                          height: 34,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Image.asset(
                        assetPath,
                        width: 42,
                        height: 34,
                        fit: BoxFit.contain,
                      ),
                const SizedBox(height: 4),
                Text(
                  etaMinutes != null ? "$etaMinutes min" : "Nearby",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Middle: Details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Available ride',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Closest driver ${etaMinutes != null ? "$etaMinutes mins away" : "nearby"} - $dropTimeStr',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: Price Column
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  calculatedPrice != null ? '₹${calculatedPrice!.round()}' : '--',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the vehicle catalogue could not be fetched.
///
/// The screen previously rendered a spinner for both "loading" and "failed",
/// which meant a dead endpoint was indistinguishable from a slow one and the
/// user had no way to retry.
class _VehicleLoadError extends StatelessWidget {
  const _VehicleLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.directions_car_filled_outlined,
              size: 40,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 12),
            Text(
              'No rides available right now',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
