import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:superapp_user/core/maps/route_polyline_service.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/core/maps/app_map_style.dart';
import 'package:superapp_user/core/maps/polyline_decoder.dart';
import 'package:superapp_user/core/maps/vehicle_marker_icons.dart';
import 'package:superapp_user/design_system/components/ride/custom_bottom_sheet.dart';
import 'package:superapp_user/design_system/components/ride/loading_widget.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/modules/taxi/home/application/home_providers.dart';
import 'package:superapp_user/modules/taxi/ride/application/ride_tracking_controller.dart';
import 'package:superapp_user/modules/taxi/ride/data/models/ride_model.dart';

class RideTrackingScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideTrackingScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideTrackingScreen> createState() => _RideTrackingScreenState();
}

class _RideTrackingScreenState extends ConsumerState<RideTrackingScreen> {
  GoogleMapController? _mapController;
  bool _navigatedToRating = false;

  Future<void> _callDriver(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(rideTrackingControllerProvider(widget.rideId));
    final controller = ref.read(rideTrackingControllerProvider(widget.rideId).notifier);
    final ride = trackingState.ride;
    final icons = ref.watch(vehicleMarkerIconsProvider).value;

    final family = VehicleMarkerIcons.familyFor(
      iconType: ride?.vehicleIconType,
      vehicleType: ride?.vehicleType,
      vehicleMake: ride?.driver?.vehicleMake,
      vehicleModel: ride?.driver?.vehicleModel,
      serviceType: ride?.serviceType,
    );
    final driverIcon = icons?[family] ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

    ref.listen(rideTrackingControllerProvider(widget.rideId), (previous, next) {
      final r = next.ride;
      if (r != null && r.isCompleted && !_navigatedToRating) {
        _navigatedToRating = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.pushReplacement('/taxi/rides/${widget.rideId}/rate');
        });
      }
      if (r != null && r.isCancelled) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.go('/taxi');
        });
      }
      if (r?.lastDriverLocation != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(r!.lastDriverLocation!.lat, r.lastDriverLocation!.lng)),
        );
      }
    });

    if (trackingState.isLoading || ride == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: LoadingWidget(message: 'Loading your ride…'),
      );
    }

    final statusLabel = _getStatusLabel(ride.status, ride.liveStatus);
    final driver = ride.driver;
    final driverName = driver?.name ?? 'RISHI';
    final vehicleDetails = (driver?.vehicleNumber.isNotEmpty == true)
        ? '${driver?.vehicleNumber} • ${driver?.vehicleMake ?? 'bike'}'
        : 'DL01AD1234 • bike';
    final driverRating = driver?.rating ?? 4.8;
    final driverPhone = driver?.phone ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Google Map Background (Light Silver Muted Theme)
          GoogleMap(
            style: AppMapStyle.muted,
            initialCameraPosition: CameraPosition(
              target: LatLng(ride.pickup.lat, ride.pickup.lng),
              zoom: 15,
            ),
            onMapCreated: (c) => _mapController = c,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            polylines: {
              if (_getRoutePoints(ride).isNotEmpty)
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: _getRoutePoints(ride),
                  color: const Color(0xFF0F172A),
                  width: 5,
                  jointType: JointType.round,
                  startCap: Cap.roundCap,
                  endCap: Cap.roundCap,
                ),
            },
            markers: {
              Marker(
                markerId: const MarkerId('pickup'),
                position: LatLng(ride.pickup.lat, ride.pickup.lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                infoWindow: InfoWindow(
                  title: 'Pickup Location',
                  snippet: ride.pickupAddress,
                ),
              ),
              Marker(
                markerId: const MarkerId('drop'),
                position: LatLng(ride.drop.lat, ride.drop.lng),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(
                  title: 'Drop Location',
                  snippet: ride.dropAddress,
                ),
              ),
              for (int i = 0; i < ride.stops.length; i++)
                Marker(
                  markerId: MarkerId('stop_$i'),
                  position: LatLng(ride.stops[i].location.lat, ride.stops[i].location.lng),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  infoWindow: InfoWindow(
                    title: 'Stop ${i + 1}',
                    snippet: ride.stops[i].address,
                  ),
                ),
              if (ride.lastDriverLocation != null)
                Marker(
                  markerId: const MarkerId('driver'),
                  position: LatLng(ride.lastDriverLocation!.lat, ride.lastDriverLocation!.lng),
                  rotation: ride.lastDriverHeading ?? 0,
                  icon: driverIcon,
                  anchor: const Offset(0.5, 0.5),
                  flat: true,
                ),
            },
          ),

          // Top Header Overlay (Light Theme Back Button, Live Pill Bar, SOS)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      _LightCircleIconButton(
                        icon: Icons.arrow_back,
                        onTap: () => Navigator.of(context).maybePop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.sensors, size: 13, color: Color(0xFF00C853)),
                                  SizedBox(width: 4),
                                  Text(
                                    'LIVE TRACKING',
                                    style: TextStyle(
                                      color: Color(0xFF00C853),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(Icons.north_east, size: 12, color: Color(0xFF00C853)),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                ride.pickupAddress.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _LightCircleIconButton(
                        icon: Icons.sos,
                        color: TaxiColors.error,
                        onTap: () => context.push('/taxi/sos?rideId=${widget.rideId}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Bottom Sheet Panel (Light Theme UI with Driver Details, Call & Chat Options)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Title & OTP Badge Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            statusLabel,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        if (ride.otp.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'OTP ',
                                  style: TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  ride.otp,
                                  style: const TextStyle(
                                    color: Color(0xFF991B1B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // --- ACCEPTED DRIVER DETAILS CARD WITH CHAT & CALL ---
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Row(
                        children: [
                          // Driver Avatar Box
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              image: (driver?.profileImage.isNotEmpty == true)
                                  ? DecorationImage(
                                      image: NetworkImage(driver!.profileImage),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (driver?.profileImage.isEmpty ?? true)
                                ? const Icon(Icons.person_outline_rounded, color: Color(0xFF0F172A), size: 24)
                                : null,
                          ),
                          const SizedBox(width: 12),

                          // Driver Info Text Column
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  driverName.toUpperCase(),
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  vehicleDetails,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
                                    const SizedBox(width: 3),
                                    Text(
                                      driverRating.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Call & Chat Buttons
                          _LightIconButton(
                            icon: Icons.chat_bubble_outline_rounded,
                            onTap: () => context.push('/taxi/rides/${widget.rideId}/chat'),
                          ),
                          const SizedBox(width: 8),
                          _LightIconButton(
                            icon: Icons.call_outlined,
                            onTap: () => _callDriver(driverPhone),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pickup, Drop & Stops Address Timeline Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00C853),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  ride.pickupAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                height: 12,
                                child: VerticalDivider(color: Color(0xFFCBD5E1), thickness: 1.5),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 14, color: Color(0xFFFF5C2B)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  ride.dropAddress,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          for (int i = 0; i < ride.stops.length; i++) ...[
                            const Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  height: 12,
                                  child: VerticalDivider(color: Color(0xFFCBD5E1), thickness: 1.5),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.location_on, size: 14, color: Color(0xFF3B82F6)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Stop ${i + 1}: ${ride.stops[i].address}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFF334155),
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Cancel Ride Button (if ride is cancellable)
                    if (_isCancellable(ride.status))
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: trackingState.isCancelling
                              ? null
                              : () => _confirmCancel(context, controller),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Text(
                            trackingState.isCancelling ? 'Cancelling…' : 'Cancel ride',
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<LatLng> _getRoutePoints(RideModel ride) {
    final decoded = PolylineDecoder.decode(ride.routePolyline);
    if (decoded.isNotEmpty) return decoded;

    final driverLat = ride.lastDriverLocation?.lat;
    final driverLng = ride.lastDriverLocation?.lng;
    final start = (driverLat != null && driverLng != null)
        ? LatLng(driverLat, driverLng)
        : LatLng(ride.pickup.lat, ride.pickup.lng);
    final drop = LatLng(ride.drop.lat, ride.drop.lng);
    final stops = ride.stops
        .map((s) => LatLng(s.location.lat, s.location.lng))
        .toList();
    return RoutePolylineService.getRoutePointsSync(start, drop, stops);
  }

  String _getStatusLabel(String status, [String? liveStatus]) {
    final s = status.toLowerCase();
    final ls = (liveStatus ?? '').toLowerCase();

    if (s == 'requested' || s == 'searching') {
      return 'Finding your driver…';
    }
    if (s == 'arrived' || ls == 'arrived' || s == 'driver_arrived') {
      return 'Driver has arrived at pickup';
    }
    if (s == 'ongoing' || s == 'started' || s == 'in_progress' || ls == 'started') {
      return 'Trip in progress';
    }
    if (s == 'accepted' || s == 'arriving' || ls == 'arriving') {
      return 'Driver is on the way';
    }
    if (s == 'completed') {
      return 'Ride completed';
    }
    if (s == 'cancelled') {
      return 'Ride cancelled';
    }
    return status.isNotEmpty ? status : 'Driver is on the way';
  }

  bool _isCancellable(String status) {
    final s = status.toLowerCase();
    return s == 'requested' || s == 'searching' || s == 'accepted';
  }

  void _confirmCancel(BuildContext context, RideTrackingController controller) {
    CustomBottomSheet.show(
      context,
      title: 'Cancel this ride?',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Frequent cancellations may affect your account.'),
          const SizedBox(height: 20),
          TaxiPrimaryButton(
            label: 'Yes, cancel ride',
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await controller.cancelRide(reason: 'Changed my mind');
              if (success && context.mounted) context.go('/taxi');
            },
          ),
        ],
      ),
    );
  }
}

class _LightCircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _LightCircleIconButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(side: BorderSide(color: Color(0xFFE2E8F0), width: 1.2)),
      elevation: 3,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icon, color: color ?? const Color(0xFF0F172A), size: 20),
        ),
      ),
    );
  }
}

class _LightIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _LightIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF0F172A), size: 20),
        ),
      ),
    );
  }
}
