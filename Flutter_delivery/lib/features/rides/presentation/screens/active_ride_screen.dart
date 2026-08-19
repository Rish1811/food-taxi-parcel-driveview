import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:food_user_application/core/constants/map_styles.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/services/location_service.dart';
import 'package:food_user_application/core/utils/map_launcher.dart';
import 'package:food_user_application/features/rides/application/active_ride_controller.dart';
import 'package:food_user_application/features/rides/data/models/taxi_ride.dart';
import 'package:food_user_application/features/rides/data/ride_route_service.dart';
import 'package:food_user_application/features/rides/presentation/widgets/collect_fare_sheet.dart';
import 'package:food_user_application/features/rides/presentation/widgets/ride_otp_sheet.dart';
import 'package:food_user_application/features/rides/presentation/widgets/ride_stage_timeline.dart';

const _rideBlue = Color(0xFF1B6FF3);
const _rideGreen = Color(0xFF1EBE5D);
const _rideRed = Color(0xFFF04438);

/// Screens 2–5 of the ride flow — **Accept, Arrive, Pickup, Drop** — as one
/// stage-driven trip screen.
///
/// Four separate routes would each need the same map, the same passenger card
/// and the same reconnect handling, and would let the driver navigate back to
/// a stage the server has already moved past. Instead the stage drives the
/// panel: the map target, the headline and the single primary action all come
/// from [TaxiRide.stage], which is whatever the server last confirmed.
class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  GoogleMapController? _mapController;
  bool _busy = false;

  List<LatLng> _routePoints = const [];
  double? _etaMins;
  Timer? _routeTimer;
  StreamSubscription<Position>? _positionSub;
  Position? _driverPosition;

  /// Which leg the drawn route belongs to, so it is refetched when the target
  /// changes at pickup rather than continuing to show the way to a place the
  /// driver has already reached.
  String? _routeLegKey;

  /// The leg the camera has already been framed for, so it is only fitted once.
  String? _fittedLegKey;
  bool _routeFetchInFlight = false;

  /// The point the driver is heading to right now: the pickup until the
  /// passenger is on board, the drop afterwards.
  LatLng? _targetOf(TaxiRide ride) => ride.stage.isOnBoard ? ride.drop : ride.pickup;

  @override
  void initState() {
    super.initState();
    _driverPosition = ref.read(locationServiceProvider).lastPosition;
    _positionSub =
        ref.read(locationServiceProvider).positionStream.listen(_onPosition);
    // The route needs a GPS fix; if one is already warm draw immediately,
    // otherwise the first position event below triggers it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRoute());
    _routeTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _refreshRoute(),
    );
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    _positionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _onPosition(Position position) {
    if (!mounted) return;

    // Deliberately NOT setState: this fires on every GPS fix, and rebuilding
    // here rebuilds the GoogleMap with it — that is what made the screen stutter.
    // The blue dot is drawn natively by myLocationEnabled, and this value is
    // only ever read as the route's origin.
    final previous = _driverPosition;
    _driverPosition = position;

    if (_routePoints.isEmpty) {
      _refreshRoute();
      return;
    }
    // Otherwise only redraw once the driver has actually moved far enough for
    // the line to be wrong; the 30s timer covers the rest.
    if (previous != null) {
      final moved = Geolocator.distanceBetween(
        previous.latitude,
        previous.longitude,
        position.latitude,
        position.longitude,
      );
      if (moved > 150) _refreshRoute();
    }
  }

  /// Resolves a position for the route origin.
  ///
  /// `lastPosition` stays null until the movement-gated stream first emits,
  /// which never happens for a driver sitting still at the pickup — the exact
  /// case where the route matters most. Falling back rather than giving up is
  /// the difference between a drawn route and a blank map.
  Future<Position?> _resolveOrigin() async {
    final cached = _driverPosition ?? ref.read(locationServiceProvider).lastPosition;
    if (cached != null) return cached;
    try {
      return await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition();
    } catch (_) {
      return null;
    }
  }

  /// Redraws the road route from the driver to whatever they are heading for.
  Future<void> _refreshRoute() async {
    if (_routeFetchInFlight) return;
    final ride = ref.read(activeRideControllerProvider).value;
    if (ride == null) return;

    final target = _targetOf(ride);
    if (target == null) return;

    _routeFetchInFlight = true;
    final from = await _resolveOrigin();
    if (from == null) {
      _routeFetchInFlight = false;
      return;
    }
    _driverPosition = from;

    final route = await ref.read(rideRouteServiceProvider).fetch(
          from: LatLng(from.latitude, from.longitude),
          to: target,
        );
    _routeFetchInFlight = false;
    if (!mounted || route == null || route.isEmpty) return;

    final legKey = '${ride.id}:${ride.stage.isOnBoard}';
    setState(() {
      _routePoints = route.points;
      _etaMins = route.durationMins;
      _routeLegKey = legKey;
    });

    // Frame the route once per leg. Re-fitting on every 30s refresh would yank
    // the camera back while the driver is panning or zooming to read the road.
    if (_fittedLegKey != legKey) {
      _fittedLegKey = legKey;
      _fitRoute();
    }
  }

  void _fitRoute() {
    final controller = _mapController;
    if (controller == null || _routePoints.isEmpty) return;

    var minLat = _routePoints.first.latitude;
    var maxLat = minLat;
    var minLng = _routePoints.first.longitude;
    var maxLng = minLng;
    for (final p in _routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        64,
      ),
    );
  }

  Future<void> _advance(TaxiRide ride) async {
    if (_busy) return;

    // Two of the four transitions need something from the driver first. Both
    // are hard gates the backend also enforces — the OTP because it proves the
    // right passenger boarded, the fare because completion settles money and
    // cannot be undone from the app.
    if (ride.stage.nextNeedsOtp) {
      // Loop rather than one shot: a mistyped code is the common case, and
      // making the driver find the button again for every retry — with a
      // passenger waiting — is the wrong place to be strict.
      while (mounted) {
        final otp = await showRideOtpSheet(context);
        if (!mounted) return;
        if (otp == null) {
          // Dismissed without a code. Say so — silently returning to a screen
          // that still reads "Passenger picked up" is indistinguishable from
          // the button being broken.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Trip not started — the passenger code is needed'),
            ),
          );
          return;
        }

        setState(() => _busy = true);
        HapticService.medium();
        final result =
            await ref.read(activeRideControllerProvider.notifier).advance(otp: otp);
        if (!mounted) return;
        setState(() => _busy = false);

        final failure = result.when(
          success: (_) => null,
          failure: (error) => error.message,
        );
        if (failure == null) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure), backgroundColor: _rideRed),
        );
      }
      return;
    }

    if (ride.stage.nextSettlesFare) {
      final settlement = await showCollectFareSheet(context, ride);
      if (settlement == null || !mounted) return;
      await _run(
        () => ref.read(activeRideControllerProvider.notifier).advance(
              paymentMethod: settlement.paymentMethod,
              fare: settlement.fare,
              collectedByDriver: settlement.collectedByDriver,
            ),
      );
      return;
    }

    await _run(() => ref.read(activeRideControllerProvider.notifier).advance());
  }

  Future<void> _run(
    Future<Result<TaxiRide, AppError>> Function() action,
  ) async {
    setState(() => _busy = true);
    HapticService.medium();
    final result = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {},
      failure: (error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: _rideRed),
      ),
    );
  }

  /// Reasons the operator can actually act on.
  ///
  /// A free-text box produces "cancel" and "asdf" in equal measure; a fixed
  /// list is the only version of this whose output is worth reading.
  static const _cancelReasons = <String>[
    'Passenger not at the pickup',
    'Passenger asked me to cancel',
    'Wrong or unreachable pickup address',
    'Vehicle problem',
    'Too far to reach the pickup',
  ];

  Future<void> _confirmCancel() async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF181C25) : Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 22.h, 24.w, 4.h),
                  child: Text(
                    'Why are you cancelling?',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18.sp,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 12.h),
                  child: Text(
                    'The passenger is waiting. Frequent cancellations reduce '
                    'how many rides you are offered.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                for (final r in _cancelReasons)
                  ListTile(
                    title: Text(r, style: TextStyle(fontSize: 14.sp)),
                    onTap: () => Navigator.of(ctx).pop(r),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(24.w, 8.h, 24.w, 12.h),
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Keep this ride'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (reason == null || !mounted) return;

    final result =
        await ref.read(activeRideControllerProvider.notifier).cancel(reason: reason);
    if (!mounted) return;
    result.when(
      success: (_) {},
      failure: (error) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: _rideRed),
      ),
    );
  }

  Future<void> _call(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rideAsync = ref.watch(activeRideControllerProvider);
    final ride = rideAsync.value;

    // At pickup the destination flips from pickup to drop, so the route has to
    // be redrawn for the new leg the moment the stage advances.
    //
    // Deferred to after the frame on purpose: this listener fires while the
    // provider is updating, which can be mid-build, and calling setState there
    // throws — which is what froze the screen the instant the OTP was accepted.
    ref.listen(activeRideControllerProvider, (previous, next) {
      final was = previous?.value?.stage.isOnBoard;
      final now = next.value?.stage.isOnBoard;
      if (was == now) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _routePoints = const [];
          _etaMins = null;
          _routeLegKey = null;
        });
        _refreshRoute();
      });
    });

    if (rideAsync.isLoading && ride == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (ride == null) {
      // Completed or cancelled while this screen was open. Pop back rather
      // than showing an empty trip.
      return _buildNoRide(isDark);
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF10131A) : Colors.white,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMap(ride)),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(child: _buildStageHeader(ride, isDark)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildActionSheet(ride, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRide(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF10131A) : Colors.white,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 64.sp, color: _rideGreen),
            SizedBox(height: 12.h),
            Text(
              'No ride in progress',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16.sp,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: 16.h),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Back to home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(TaxiRide ride) {
    final target = _targetOf(ride);
    if (target == null) {
      return Container(color: const Color(0xFFEFF1F5));
    }

    // The leg changes at pickup; drop a stale route rather than drawing the way
    // to somewhere the driver has already been.
    final legKey = '${ride.id}:${ride.stage.isOnBoard}';
    final points = _routeLegKey == legKey ? _routePoints : const <LatLng>[];

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: target, zoom: 15),
      style: MapStyles.mutedGrey,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: {
        Marker(
          markerId: const MarkerId('target'),
          position: target,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            ride.stage.isOnBoard
                ? BitmapDescriptor.hueRed
                : BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: ride.stage.isOnBoard ? 'Drop' : 'Pickup',
          ),
        ),
      },
      polylines: {
        if (points.isNotEmpty)
          Polyline(
            polylineId: const PolylineId('leg'),
            points: points,
            color: _rideBlue,
            width: 6,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
          ),
      },
      onMapCreated: (controller) {
        _mapController = controller;
        if (points.isNotEmpty) _fitRoute();
      },
    );
  }

  Widget _buildStageHeader(TaxiRide ride, bool isDark) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C25) : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ride.stage.headline,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17.sp,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
              ),
              if (_etaMins != null)
                Padding(
                  padding: EdgeInsets.only(right: 4.w),
                  child: Text(
                    '${_etaMins!.round()} min',
                    style: TextStyle(
                      color: _rideBlue,
                      fontWeight: FontWeight.w900,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              GestureDetector(
                onTap: _busy ? null : _confirmCancel,
                child: Padding(
                  padding: EdgeInsets.all(8.r),
                  child: Icon(Icons.close_rounded, size: 20.sp, color: _rideRed),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          RideStageTimeline(stage: ride.stage),
        ],
      ),
    );
  }

  Widget _buildActionSheet(TaxiRide ride, bool isDark) {
    final surface = isDark ? const Color(0xFF181C25) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];
    final target = _targetOf(ride);
    final address =
        ride.stage.isOnBoard ? ride.dropAddress : ride.pickupAddress;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPassengerRow(ride, textColor, subText),
              SizedBox(height: 16.h),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    ride.stage.isOnBoard
                        ? Icons.flag_rounded
                        : Icons.my_location_rounded,
                    size: 18.sp,
                    color: ride.stage.isOnBoard ? _rideRed : _rideGreen,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      address.isEmpty ? 'Location unavailable' : address,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                  if (target != null)
                    GestureDetector(
                      onTap: () => MapLauncher.launchGoogleMaps(
                        target.latitude,
                        target.longitude,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(8.r),
                        child: Icon(
                          Icons.navigation_rounded,
                          color: _rideBlue,
                          size: 22.sp,
                        ),
                      ),
                    ),
                ],
              ),
              // Warns before the button is tapped, so the driver asks for the
              // code while the passenger is getting in rather than after.
              if (ride.stage.nextNeedsOtp) ...[
                SizedBox(height: 14.h),
                _buildOtpHint(isDark),
              ],
              SizedBox(height: 18.h),
              SizedBox(
                height: 54.h,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : () => _advance(ride),
                  style: ElevatedButton.styleFrom(
                    // Green only on the step that ends the trip, so the final,
                    // irreversible tap does not look like the three before it.
                    backgroundColor:
                        ride.stage.nextSettlesFare ? _rideGreen : _rideBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27.r),
                    ),
                  ),
                  child: _busy
                      ? SizedBox(
                          width: 22.w,
                          height: 22.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      // Shrink-to-fit rather than ellipsise: 'PASSENGER PICKED
                      // UP' and 'REACHED DESTINATION' are long, and uppercase
                      // with letter-spacing makes them longer still. Truncating
                      // the one button that drives the trip forward would be
                      // worse than a slightly smaller label on a narrow phone.
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            ride.stage.actionLabel.toUpperCase(),
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15.sp,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPassengerRow(TaxiRide ride, Color textColor, Color? subText) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22.r,
          backgroundColor: _rideBlue.withOpacity(0.12),
          child: Icon(Icons.person_rounded, color: _rideBlue, size: 24.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ride.passenger.name,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.sp,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                '₹${ride.fare.toStringAsFixed(0)} · '
                '${ride.isCash ? 'Cash' : 'Paid online'}',
                style: TextStyle(color: subText, fontSize: 12.sp),
              ),
            ],
          ),
        ),
        if (ride.passenger.phone.isNotEmpty)
          GestureDetector(
            onTap: () => _call(ride.passenger.phone),
            child: Container(
              padding: EdgeInsets.all(9.r),
              decoration: const BoxDecoration(
                color: _rideGreen,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.call_rounded, color: Colors.white, size: 18.sp),
            ),
          ),
      ],
    );
  }

  Widget _buildOtpHint(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: _rideBlue.withOpacity(isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Icon(Icons.pin_rounded, color: _rideBlue, size: 20.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Ask the passenger for their start code',
              style: TextStyle(
                color: _rideBlue,
                fontWeight: FontWeight.w700,
                fontSize: 13.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
