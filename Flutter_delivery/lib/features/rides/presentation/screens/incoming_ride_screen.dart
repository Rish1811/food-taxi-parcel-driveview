import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:food_user_application/core/constants/map_styles.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/services/sound_service.dart';
import 'package:food_user_application/features/orders/presentation/widgets/slide_to_accept_button.dart';
import 'package:food_user_application/features/rides/application/incoming_ride_controller.dart';
import 'package:food_user_application/features/rides/data/models/taxi_ride.dart';

const _rideBlue = Color(0xFF1B6FF3);
const _rideRed = Color(0xFFF04438);

/// Screen 1 of the ride flow — **request coming**.
///
/// Stacked over the whole app by [main.dart] whenever
/// [incomingRideControllerProvider] is non-null, exactly like the food
/// incoming-order alert, so it works from any route and covers offers that
/// arrive over the socket or over FCM.
class IncomingRideScreen extends ConsumerStatefulWidget {
  const IncomingRideScreen({super.key, required this.ride});

  final TaxiRide ride;

  @override
  ConsumerState<IncomingRideScreen> createState() => _IncomingRideScreenState();
}

class _IncomingRideScreenState extends ConsumerState<IncomingRideScreen> {
  /// A ValueNotifier rather than setState so the per-second tick rebuilds only
  /// the countdown, not the map underneath it.
  late final ValueNotifier<int> _secondsLeft;
  Timer? _timer;
  bool _resolving = false;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    HapticService.light();
    SoundService.playRingtone();

    // The server sends the real accept window; 20s is only the fallback for a
    // payload that predates it. Counting down longer than the server allows
    // would show a live button for an offer already reassigned.
    _secondsLeft = ValueNotifier<int>(widget.ride.expiresInSeconds ?? 20);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft.value <= 1) {
        timer.cancel();
        _expire();
        return;
      }
      _secondsLeft.value--;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _secondsLeft.dispose();
    _mapController?.dispose();
    SoundService.stopRingtone();
    super.dispose();
  }

  void _expire() {
    if (_resolving) return;
    _resolving = true;
    SoundService.stopRingtone();
    ref.read(incomingRideControllerProvider.notifier).expire();
  }

  Future<void> _accept() async {
    if (_resolving) return;
    setState(() => _resolving = true);
    _timer?.cancel();
    SoundService.stopRingtone();
    HapticService.medium();

    final result = await ref.read(incomingRideControllerProvider.notifier).accept();
    if (!mounted) return;
    result.when(
      // The trip screen takes over from the active-ride controller; nothing to
      // navigate to here.
      success: (_) {},
      failure: (error) {
        setState(() => _resolving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message), backgroundColor: _rideRed),
        );
      },
    );
  }

  void _decline() {
    if (_resolving) return;
    _resolving = true;
    _timer?.cancel();
    SoundService.stopRingtone();
    HapticService.light();
    ref.read(incomingRideControllerProvider.notifier).decline();
  }

  /// Frames pickup and drop together so the driver can judge the job before
  /// the countdown runs out — a map centred on one end tells them nothing.
  void _fitBounds() {
    final ride = widget.ride;
    final pickup = ride.pickup;
    final drop = ride.drop;
    final controller = _mapController;
    if (controller == null || pickup == null) return;

    if (drop == null) {
      controller.animateCamera(CameraUpdate.newLatLngZoom(pickup, 15));
      return;
    }
    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            pickup.latitude < drop.latitude ? pickup.latitude : drop.latitude,
            pickup.longitude < drop.longitude ? pickup.longitude : drop.longitude,
          ),
          northeast: LatLng(
            pickup.latitude > drop.latitude ? pickup.latitude : drop.latitude,
            pickup.longitude > drop.longitude ? pickup.longitude : drop.longitude,
          ),
        ),
        72,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ride = widget.ride;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF10131A) : Colors.white,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap(isDark, ride)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildCountdownBar()),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildOfferSheet(isDark, ride),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark, TaxiRide ride) {
    final pickup = ride.pickup;
    if (pickup == null) {
      // A rare offer with no coordinates is still worth showing — the
      // addresses and fare below are enough to decide on.
      return Container(color: isDark ? const Color(0xFF10131A) : const Color(0xFFEFF1F5));
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: pickup, zoom: 14),
      style: MapStyles.mutedGrey,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      liteModeEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
        if (ride.drop != null)
          Marker(
            markerId: const MarkerId('drop'),
            position: ride.drop!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: const InfoWindow(title: 'Drop'),
          ),
      },
      polylines: {
        if (ride.drop != null)
          Polyline(
            polylineId: const PolylineId('offer'),
            points: [pickup, ride.drop!],
            color: _rideBlue,
            width: 4,
            patterns: [PatternItem.dash(24), PatternItem.gap(12)],
          ),
      },
      onMapCreated: (controller) {
        _mapController = controller;
        _fitBounds();
      },
    );
  }

  Widget _buildCountdownBar() {
    return ValueListenableBuilder<int>(
      valueListenable: _secondsLeft,
      builder: (context, seconds, _) {
        final total = widget.ride.expiresInSeconds ?? 20;
        final fraction = total == 0 ? 0.0 : (seconds / total).clamp(0.0, 1.0);
        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: _rideBlue,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.local_taxi_rounded, color: Colors.white, size: 22.sp),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New ride request',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.sp,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4.r),
                      child: LinearProgressIndicator(
                        value: fraction,
                        minHeight: 4.h,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                '${seconds}s',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20.sp,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfferSheet(bool isDark, TaxiRide ride) {
    final surface = isDark ? const Color(0xFF181C25) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
              SizedBox(height: 16.h),
              _buildFareRow(ride, textColor, subText),
              SizedBox(height: 18.h),
              _buildLeg(
                color: const Color(0xFF1EBE5D),
                label: 'PICKUP',
                address: ride.pickupAddress.isEmpty
                    ? 'Pickup location'
                    : ride.pickupAddress,
                textColor: textColor,
                subText: subText,
              ),
              SizedBox(height: 12.h),
              _buildLeg(
                color: _rideRed,
                label: 'DROP',
                address:
                    ride.dropAddress.isEmpty ? 'Drop location' : ride.dropAddress,
                textColor: textColor,
                subText: subText,
              ),
              SizedBox(height: 20.h),
              SlideToAcceptButton(
                onAccept: _accept,
                isLoading: _resolving,
                text: 'Accept ride',
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: _resolving ? null : _decline,
                child: Text(
                  'Decline',
                  style: TextStyle(
                    color: subText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFareRow(TaxiRide ride, Color textColor, Color? subText) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '₹${ride.fare.toStringAsFixed(0)}',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w900,
                fontSize: 30.sp,
                height: 1,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              ride.isCash ? 'Collect cash' : 'Paid online',
              style: TextStyle(
                color: ride.isCash ? const Color(0xFFE85B17) : const Color(0xFF1EBE5D),
                fontWeight: FontWeight.w800,
                fontSize: 12.sp,
              ),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (ride.distanceMeters > 0)
              Text(
                '${ride.distanceKm.toStringAsFixed(1)} km',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16.sp,
                ),
              ),
            if (ride.durationMinutes > 0) ...[
              SizedBox(height: 2.h),
              Text(
                '~${ride.durationMinutes} min',
                style: TextStyle(color: subText, fontSize: 12.sp),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildLeg({
    required Color color,
    required String label,
    required String address,
    required Color textColor,
    required Color? subText,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(top: 5.h),
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: subText,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.sp,
                  letterSpacing: 0.8,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14.sp,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
