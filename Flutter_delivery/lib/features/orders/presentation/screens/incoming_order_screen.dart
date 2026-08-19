import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/features/orders/presentation/widgets/incoming_order_bottom_sheet.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/constants/map_styles.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/services/location_service.dart';
import 'package:food_user_application/core/services/sound_service.dart';
import 'package:food_user_application/core/utils/polyline_decoder.dart';
import 'package:food_user_application/features/auth/application/auth_controller.dart';
import 'package:food_user_application/features/auth/application/auth_state.dart';
import 'package:food_user_application/features/orders/application/incoming_order_controller.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/data/orders_repository.dart';
import 'package:food_user_application/features/orders/presentation/widgets/slide_to_accept_button.dart';

const _incomingOnlineGreen = Color(0xFF1EBE5D);

/// Full-screen, Rapido/Uber-style incoming-order alert. Stacked over the
/// entire app by [main.dart]'s overlay builder whenever
/// [incomingOrderControllerProvider] is non-null — works regardless of the
/// current GoRouter location, and is the single UI path for orders arriving
/// via Socket.IO (app open) or FCM (backgrounded/locked).
class IncomingOrderScreen extends ConsumerStatefulWidget {
  const IncomingOrderScreen({super.key, required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<IncomingOrderScreen> createState() => _IncomingOrderScreenState();
}

class _IncomingOrderScreenState extends ConsumerState<IncomingOrderScreen> {
  // ValueNotifier so the once-a-second tick only rebuilds the small countdown
  // texts below, not this screen's whole Scaffold/map/bottom-sheet subtree.
  final ValueNotifier<int> _secondsLeft = ValueNotifier<int>(45);
  Timer? _timer;
  bool _resolving = false;

  GoogleMapController? _mapController;
  List<LatLng> _routePoints = [];
  double? _etaMins;
  bool _boundsFitted = false;

  BitmapDescriptor? _bikeMarkerIcon;
  StreamSubscription<Position>? _positionSub;
  bool _routeFetchInFlight = false;
  bool _cameraCentered = false;

  @override
  void initState() {
    super.initState();
    HapticService.light();
    SoundService.playRingtone();

    final deadline = widget.order.acceptanceDeadlineAt;
    _secondsLeft.value = deadline != null
        ? deadline.difference(DateTime.now()).inSeconds.clamp(0, 45)
        : 45;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft.value <= 1) {
        timer.cancel();
        _expire();
        return;
      }
      _secondsLeft.value--;
    });

    _loadMarkerIcon();
    _fetchRoute();
    // GPS often isn't warm yet the instant this screen appears (fresh app
    // launch from a killed-state push, or the fix just hasn't landed) — the
    // one-shot fetch above silently no-ops if `lastPosition` is null, so we
    // also retry as soon as a live position arrives.
    _positionSub =
        ref.read(locationServiceProvider).positionStream.listen(_onPositionUpdate);
  }

  Future<Uint8List> _getBytesFromAsset(String path, int width) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final frame = await codec.getNextFrame();
    return (await frame.image.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
  }

  Future<void> _loadMarkerIcon() async {
    try {
      final bytes = await _getBytesFromAsset('assets/image/bike.png', 80);
      if (!mounted) return;
      setState(() => _bikeMarkerIcon = BitmapDescriptor.fromBytes(bytes));
    } catch (_) {
      // Falls back to the native "my location" blue dot.
    }
  }

  void _onPositionUpdate(Position pos) {
    if (_routePoints.isEmpty && !_routeFetchInFlight) _fetchRoute();
    if (!_boundsFitted && !_cameraCentered && _mapController != null) {
      _cameraCentered = true;
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
      );
    }
  }

  Future<void> _fetchRoute() async {
    final pos = ref.read(locationServiceProvider).lastPosition;
    if (pos == null) return;
    _routeFetchInFlight = true;
    final result = await ref.read(ordersRepositoryProvider).getRoute(
          widget.order.id,
          lat: pos.latitude,
          lng: pos.longitude,
          target: 'restaurant',
        );
    _routeFetchInFlight = false;
    if (!mounted) return;
    result.when(
      success: (data) {
        final encoded = data['polyline'] as String?;
        final points = (encoded != null && encoded.isNotEmpty)
            ? decodePolyline(encoded)
            : <LatLng>[];
        setState(() {
          _routePoints = points;
          _etaMins = (data['durationMins'] as num?)?.toDouble();
        });
        _fitBoundsIfReady();
      },
      failure: (_) {},
    );
  }

  void _fitBoundsIfReady() {
    if (_boundsFitted || _routePoints.isEmpty || _mapController == null) return;
    _boundsFitted = true;
    double minLat = _routePoints.first.latitude;
    double maxLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLng = _routePoints.first.longitude;
    for (final p in _routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        90,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _positionSub?.cancel();
    _secondsLeft.dispose();
    SoundService.stopRingtone();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_resolving) return;
    _resolving = true;
    _timer?.cancel();
    final error =
        await ref.read(incomingOrderControllerProvider.notifier).accept();
    // Without this the rider watched the order disappear with no explanation
    // and reasonably concluded the app had invented it.
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _decline() async {
    if (_resolving) return;
    _resolving = true;
    _timer?.cancel();
    await ref.read(incomingOrderControllerProvider.notifier).decline();
  }

  Future<void> _expire() async {
    if (_resolving) return;
    _resolving = true;
    await ref.read(incomingOrderControllerProvider.notifier).expire();
  }

  Widget _buildMap() {
    return StreamBuilder<Position>(
      stream: ref.read(locationServiceProvider).positionStream,
      initialData: ref.read(locationServiceProvider).lastPosition,
      builder: (context, snapshot) {
        final pos = snapshot.data;
        final initialTarget = pos != null
            ? LatLng(pos.latitude, pos.longitude)
            : (_routePoints.isNotEmpty ? _routePoints.first : const LatLng(0, 0));

        final authState = ref.read(authControllerProvider);
        final isBike = authState is AuthAuthenticated &&
            (authState.user.vehicleType?.toLowerCase() == 'bike' ||
                authState.user.vehicleType?.toLowerCase() == 'two_wheeler');
        final useCustomMarker = isBike && _bikeMarkerIcon != null;

        return GoogleMap(
          onMapCreated: (controller) {
            _mapController = controller;
            _fitBoundsIfReady();
          },
          initialCameraPosition: CameraPosition(target: initialTarget, zoom: 15),
          markers: {
            if (useCustomMarker && pos != null)
              Marker(
                markerId: const MarkerId('delivery_partner'),
                position: LatLng(pos.latitude, pos.longitude),
                icon: _bikeMarkerIcon!,
                anchor: const Offset(0.5, 0.5),
                rotation: pos.heading,
              ),
            if (_routePoints.isNotEmpty)
              Marker(
                markerId: const MarkerId('restaurant'),
                position: _routePoints.last,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange,
                ),
              ),
          },
          polylines: {
            if (_routePoints.length > 1)
              Polyline(
                polylineId: const PolylineId('pickup_route'),
                points: _routePoints,
                color: Theme.of(context).primaryColor,
                width: 5,
              ),
          },
          myLocationEnabled: !useCustomMarker,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          compassEnabled: false,
          mapToolbarEnabled: false,
          style: MapStyles.mutedGrey,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final order = widget.order;

    final etaLabel = _etaMins != null
        ? '${_etaMins!.round()} mins away'
        : (order.tripDurationMins != null
            ? '${order.tripDurationMins!.toStringAsFixed(0)} mins away'
            : null);

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _buildMap()),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.only(top: 12.h, right: 16.w, left: 16.w),
                child: Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: _decline,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24.r),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.close, size: 16, color: Colors.black87),
                          SizedBox(width: 6.w),
                          ValueListenableBuilder<int>(
                            valueListenable: _secondsLeft,
                            builder: (context, seconds, _) => Text(
                              'Deny · ${seconds}s',
                              style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black87, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                bottom: false,
                child: IncomingOrderBottomSheet(
                  order: order,
                  secondsLeft: _secondsLeft,
                  onAccept: _accept,
                  onReject: _decline,
                  // Lets the sheet work out the pickup distance itself when the
                  // payload carries none — which is every order that arrived by
                  // poll rather than over the socket.
                  riderPosition: ref.read(locationServiceProvider).lastPosition,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
