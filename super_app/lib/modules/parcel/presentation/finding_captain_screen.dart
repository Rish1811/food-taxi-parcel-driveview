import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/core/maps/app_map_style.dart';
import 'package:superapp_user/design_system/components/feedback/taxi_snackbar_utils.dart';
import 'package:superapp_user/modules/taxi/ride/application/ride_tracking_controller.dart';
import 'package:superapp_user/modules/parcel/application/delivery_booking_controller.dart';

/// Step 3: the booking exists and dispatch is notifying nearby captains.
///
/// Reuses the ride tracking controller because a delivery *is* a ride with
/// `serviceType: parcel` — so acceptance, cancellation and live state all
/// arrive on the same socket events rather than a parallel implementation.
class FindingCaptainScreen extends ConsumerStatefulWidget {
  final String rideId;
  const FindingCaptainScreen({super.key, required this.rideId});

  @override
  ConsumerState<FindingCaptainScreen> createState() => _FindingCaptainScreenState();
}

class _FindingCaptainScreenState extends ConsumerState<FindingCaptainScreen> {
  bool _cancelling = false;
  bool _left = false;

  Future<void> _cancel() async {
    if (_cancelling) return;
    setState(() => _cancelling = true);

    final ok = await ref
        .read(rideTrackingControllerProvider(widget.rideId).notifier)
        .cancelRide(reason: 'Cancelled by sender');

    if (!mounted) return;
    if (ok) {
      ref.read(deliveryBookingProvider.notifier).reset();
      context.go('/taxi');
    } else {
      SnackbarUtils.error(context, 'Could not cancel. Please try again.');
      setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(rideTrackingControllerProvider(widget.rideId));
    final ride = tracking.ride;
    final booking = ref.watch(deliveryBookingProvider);

    ref.listen(rideTrackingControllerProvider(widget.rideId), (previous, next) {
      final r = next.ride;
      if (r == null || _left) return;

      // A captain accepted — hand over to live tracking.
      if (r.driver != null && r.status.toLowerCase() != 'searching') {
        _left = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.pushReplacement('/taxi/rides/${widget.rideId}/track');
        });
        return;
      }

      // Dispatch gave up, or the parcel was cancelled elsewhere.
      if (r.isCancelled) {
        _left = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/taxi');
        });
      }
    });

    final pickup = ride != null
        ? LatLng(ride.pickup.lat, ride.pickup.lng)
        : LatLng(booking.pickup?.lat ?? 22.7196, booking.pickup?.lng ?? 75.8577);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GoogleMap(
                    style: AppMapStyle.muted,
                    initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    markers: {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: pickup,
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      ),
                      if (ride != null)
                        Marker(
                          markerId: const MarkerId('drop'),
                          position: LatLng(ride.drop.lat, ride.drop.lng),
                          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                        ),
                    },
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: const [
                              BoxShadow(color: Color(0x1A000000), blurRadius: 10),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PARCEL ROUTE',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 0.7,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                  )),
                              Text(
                                ride?.pickupAddress ??
                                    booking.pickup?.address ??
                                    'Pickup location',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  children: [
                    const Text(
                      'Finding your delivery captain',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Booking created. Notifying nearby captains…',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Column(
                        children: [
                          const Text('EXPECTED PRICE',
                              style: TextStyle(
                                fontSize: 9.5,
                                letterSpacing: 0.7,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFEA580C),
                              )),
                          const SizedBox(height: 2),
                          Text(
                            'Rs ${(ride?.fare ?? booking.quote?.total ?? 0).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                          ),
                          if (booking.quote != null)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: Text(
                                'Estimated for about ${booking.quote!.distanceKm.toStringAsFixed(1)} km. '
                                'Includes ${booking.quote!.serviceTaxPercentage.toStringAsFixed(2)}% service tax.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 10.5, color: Color(0xFF9A3412)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Chip(icon: Icons.bolt, label: 'FAST DISPATCH'),
                        SizedBox(width: 10),
                        _Chip(icon: Icons.verified_user_outlined, label: 'PARCEL SAFETY'),
                      ],
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _cancelling ? null : _cancel,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          backgroundColor: const Color(0xFFFEF2F2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _cancelling
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text(
                                'CANCEL SEARCH',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.4,
                                ),
                              ),
                      ),
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

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: TaxiColors.primary),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: Color(0xFF334155),
              )),
        ],
      ),
    );
  }
}
