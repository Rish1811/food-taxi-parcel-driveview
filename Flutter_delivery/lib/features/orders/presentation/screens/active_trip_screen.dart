import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/router/app_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:confetti/confetti.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/core/services/location_service.dart';
import 'package:food_user_application/core/utils/map_launcher.dart';
import 'package:food_user_application/core/constants/app_constants.dart';
import 'package:food_user_application/core/constants/map_styles.dart';
import 'package:food_user_application/core/utils/polyline_decoder.dart';
import 'package:food_user_application/features/auth/application/auth_controller.dart';
import 'package:food_user_application/features/auth/application/auth_state.dart';
import '../widgets/otp_bottom_sheet.dart';
import 'package:food_user_application/features/orders/application/active_trip_visibility_controller.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/application/orders_state.dart';
import 'package:food_user_application/features/chat/presentation/screens/chat_screen.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';
import 'package:food_user_application/features/orders/data/orders_repository.dart';
import 'package:food_user_application/features/orders/presentation/widgets/collect_payment_sheet.dart';
import 'package:food_user_application/features/support/data/support_repository.dart';

const _tripOnlineGreen = Color(0xFF1EBE5D);

/// Full-screen "active trip" map view, stacked over the app by [main.dart]'s
/// overlay builder whenever there is an active order and the trip hasn't
/// been minimized. Mirrors [IncomingOrderScreen]'s overlay pattern so it
/// works regardless of the current GoRouter location, and automatically
/// reappears if the app is relaunched mid-delivery.
final GlobalKey<NavigatorState> _activeTripNavKey = GlobalKey<NavigatorState>();

class ActiveTripScreen extends ConsumerWidget {
  const ActiveTripScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Navigator(
      key: _activeTripNavKey,
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => const _ActiveTripScaffold(),
      ),
    );
  }
}

class _ActiveTripScaffold extends ConsumerStatefulWidget {
  const _ActiveTripScaffold();

  @override
  ConsumerState<_ActiveTripScaffold> createState() => _ActiveTripScaffoldState();
}

class _ActiveTripScaffoldState extends ConsumerState<_ActiveTripScaffold> {
  GoogleMapController? _mapController;
  List<LatLng> _routePoints = [];
  LatLng? _routeDestination;
  double? _etaMins;
  String? _routeKey;
  Timer? _routeRefreshTimer;
  BitmapDescriptor? _bikeMarkerIcon;
  BitmapDescriptor? _restaurantMarkerIcon;
  String? _restaurantMarkerUrl;
  bool _restaurantMarkerLoading = false;
  StreamSubscription<Position>? _positionSub;
  bool _routeFetchInFlight = false;
  DeliveryOrder? _lastOrder;
  double _currentHeading = 0.0;
  Position? _previousPos;
  final ConfettiController _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  bool _isCompleting = false;
  bool _isActionLoading = false;

  // --- Debug-only route simulator (kDebugMode) -----------------------------
  // Walks a synthetic position along the last fetched polyline so testers can
  // watch the customer app's live tracking react without physically moving.
  static const double _simSpeedMps = 8.0; // ~29 km/h simulated rider speed
  Timer? _simTimer;
  bool _isSimulating = false;
  List<LatLng> _simRoutePoints = [];
  List<double> _simCumulativeDistances = [];
  double _simDistanceCovered = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMarkerIcon();
    });
    _positionSub = ref.read(locationServiceProvider).positionStream.listen(_onPositionUpdate);
  }

  @override
  void dispose() {
    _routeRefreshTimer?.cancel();
    _positionSub?.cancel();
    _simTimer?.cancel();
    _confettiController.dispose();
    super.dispose();
  }

  void _toggleSimulation() {
    _isSimulating ? _stopSimulation() : _startSimulation();
  }

  void _startSimulation() {
    if (_routePoints.length < 2) {
      _showSnack('No route to simulate yet');
      return;
    }
    _simRoutePoints = List.of(_routePoints);
    _simCumulativeDistances = _computeCumulativeDistances(_simRoutePoints);
    _simDistanceCovered = 0;
    _simTimer?.cancel();
    _simTimer = Timer.periodic(const Duration(seconds: 1), (_) => _stepSimulation());
    setState(() => _isSimulating = true);
  }

  void _stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    if (mounted) setState(() => _isSimulating = false);
  }

  List<double> _computeCumulativeDistances(List<LatLng> points) {
    final distances = <double>[0];
    for (var i = 1; i < points.length; i++) {
      final d = Geolocator.distanceBetween(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
      distances.add(distances.last + d);
    }
    return distances;
  }

  void _stepSimulation() {
    _simDistanceCovered += _simSpeedMps;
    final total = _simCumulativeDistances.last;
    final lastIndex = _simRoutePoints.length - 1;
    if (_simDistanceCovered >= total) {
      _emitSimulatedPoint(lastIndex - 1 < 0 ? 0 : lastIndex - 1, lastIndex, 1.0);
      _stopSimulation();
      return;
    }
    var segIndex = 0;
    for (var i = 0; i < _simCumulativeDistances.length - 1; i++) {
      if (_simDistanceCovered >= _simCumulativeDistances[i] &&
          _simDistanceCovered <= _simCumulativeDistances[i + 1]) {
        segIndex = i;
        break;
      }
    }
    final segStart = _simCumulativeDistances[segIndex];
    final segEnd = _simCumulativeDistances[segIndex + 1];
    final segLength = segEnd - segStart;
    final t = segLength > 0 ? (_simDistanceCovered - segStart) / segLength : 0.0;
    _emitSimulatedPoint(segIndex, segIndex + 1, t);
  }

  void _emitSimulatedPoint(int fromIdx, int toIdx, double t) {
    final from = _simRoutePoints[fromIdx];
    final to = _simRoutePoints[toIdx];
    final lat = from.latitude + (to.latitude - from.latitude) * t;
    final lng = from.longitude + (to.longitude - from.longitude) * t;
    final rawHeading = Geolocator.bearingBetween(from.latitude, from.longitude, to.latitude, to.longitude);
    final heading = rawHeading < 0 ? rawHeading + 360 : rawHeading;
    ref.read(locationServiceProvider).emitSimulatedPosition(
          latitude: lat,
          longitude: lng,
          heading: heading,
          speed: _simSpeedMps,
        );
  }

  Future<Uint8List> _getBytesFromAsset(String path, int width) async {
    final data = await rootBundle.load(path);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  Future<void> _loadMarkerIcon() async {
    try {
      final bytes = await _getBytesFromAsset('assets/image/bike.png', 80);
      if (!mounted) return;
      setState(() => _bikeMarkerIcon = BitmapDescriptor.fromBytes(bytes));
    } catch (_) {
      // Falls back to the native blue dot if the asset fails to decode.
    }
  }

  Future<void> _loadRestaurantMarkerIcon(String imageUrl) async {
    if (_restaurantMarkerUrl == imageUrl || _restaurantMarkerLoading) return;
    _restaurantMarkerLoading = true;
    try {
      final response = await Dio().get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = Uint8List.fromList(response.data ?? const []);
      const photoSize = 96;
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: photoSize,
        targetHeight: photoSize,
      );
      final frame = await codec.getNextFrame();
      final markerBytes = await _framedMarkerBytes(frame.image, photoSize);
      if (!mounted) return;
      setState(() {
        _restaurantMarkerIcon = BitmapDescriptor.fromBytes(markerBytes);
        _restaurantMarkerUrl = imageUrl;
      });
    } catch (e) {
      // Falls back to the default pin if the photo fails to load.
      debugPrint('[ActiveTrip] restaurant marker photo failed to load ($imageUrl): $e');
    } finally {
      _restaurantMarkerLoading = false;
    }
  }

  /// Draws a rounded-square framed photo with a downward pointer, mirroring
  /// the "restaurant photo pin" look used by other delivery apps.
  Future<Uint8List> _framedMarkerBytes(ui.Image image, int photoSize) async {
    const border = 6.0;
    const pointerHeight = 16.0;
    final canvasSize = photoSize + border * 2;
    final totalHeight = canvasSize + pointerHeight;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, canvasSize, totalHeight));

    final frameRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, canvasSize, canvasSize),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      frameRRect.shift(const Offset(0, 2)),
      Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(frameRRect, Paint()..color = Colors.white);

    final photoRect = Rect.fromLTWH(border, border, photoSize.toDouble(), photoSize.toDouble());
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(photoRect, const Radius.circular(10)));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      photoRect,
      Paint(),
    );
    canvas.restore();

    final pointer = Path()
      ..moveTo(canvasSize / 2 - 10, canvasSize)
      ..lineTo(canvasSize / 2 + 10, canvasSize)
      ..lineTo(canvasSize / 2, totalHeight)
      ..close();
    canvas.drawPath(pointer, Paint()..color = Colors.white);

    final picture = recorder.endRecording();
    final renderedImage = await picture.toImage(canvasSize.round(), totalHeight.round());
    final data = await renderedImage.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  void _onPositionUpdate(Position position) {
    if (_routePoints.isEmpty && !_routeFetchInFlight && _lastOrder != null) {
      _fetchRoute(_lastOrder!, _targetFor(_lastOrder!));
    }

    // Prefer the device's own compass-fused heading (updates continuously,
    // even while turning in place) over a bearing computed between two GPS
    // fixes, which only changes once the rider has actually moved.
    final hasDeviceHeading = position.headingAccuracy >= 0 && position.heading >= 0;
    double? nextHeading;
    if (hasDeviceHeading) {
      nextHeading = position.heading;
    } else if (_previousPos != null) {
      final distance = Geolocator.distanceBetween(
        _previousPos!.latitude,
        _previousPos!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance > 1.5) { // update heading if moved more than 1.5 meters
        nextHeading = Geolocator.bearingBetween(
          _previousPos!.latitude,
          _previousPos!.longitude,
          position.latitude,
          position.longitude,
        );
      }
    }
    if (nextHeading != null && mounted) {
      setState(() => _currentHeading = nextHeading!);
    }
    _previousPos = position;
  }

  void _maybeFetchRoute(DeliveryOrder order) {
    _lastOrder = order;
    final target = _targetFor(order);
    if (target == 'restaurant') {
      final photo = order.restaurant.displayImage;
      debugPrint(
        '[ActiveTrip] restaurant media — cover: ${order.restaurant.coverImages}, '
        'menu: ${order.restaurant.menuImages}, profile: ${order.restaurant.profileImage}, '
        'using: $photo',
      );
      if (photo != null && photo.isNotEmpty) {
        _loadRestaurantMarkerIcon(photo);
      }
    }
    final key = '${order.id}::$target';
    if (key == _routeKey) return;
    _routeKey = key;
    _fetchRoute(order, target);

    _routeRefreshTimer?.cancel();
    _routeRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final ordersState = ref.read(ordersControllerProvider);
      if (ordersState is OrdersLoaded && ordersState.hasActiveOrder) {
        _fetchRoute(ordersState.currentOrder!, target);
      }
    });
  }

  String _targetFor(DeliveryOrder order) {
    final navigateToRestaurant = order.currentPhase == 'en_route_to_pickup' ||
        order.currentPhase == 'at_pickup';
    return navigateToRestaurant ? 'restaurant' : 'customer';
  }

  Future<void> _fetchRoute(DeliveryOrder order, String target) async {
    final pos = ref.read(locationServiceProvider).lastPosition;
    if (pos == null || _routeFetchInFlight) return;
    _routeFetchInFlight = true;
    final result = await ref.read(ordersRepositoryProvider).getRoute(
          order.id,
          lat: pos.latitude,
          lng: pos.longitude,
          target: target,
        );
    _routeFetchInFlight = false;
    if (!mounted) return;
    result.when(
      success: (data) {
        final encoded = data['polyline'] as String?;
        final points = (encoded != null && encoded.isNotEmpty)
            ? decodePolyline(encoded)
            : <LatLng>[];
        final destLoc = target == 'restaurant'
            ? order.restaurant.location
            : order.deliveryAddress.location;
        final destination = destLoc != null
            ? LatLng(destLoc.lat, destLoc.lng)
            : (points.isNotEmpty ? points.last : null);
        setState(() {
          _routePoints = points;
          _routeDestination = destination;
          _etaMins = (data['durationMins'] as num?)?.toDouble();
        });
        if (destination != null && _mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngBounds(
              _boundsFor(LatLng(pos.latitude, pos.longitude), destination),
              80,
            ),
          );
        }
      },
      failure: (_) {},
    );
  }

  LatLngBounds _boundsFor(LatLng a, LatLng b) {
    return LatLngBounds(
      southwest: LatLng(
        a.latitude < b.latitude ? a.latitude : b.latitude,
        a.longitude < b.longitude ? a.longitude : b.longitude,
      ),
      northeast: LatLng(
        a.latitude > b.latitude ? a.latitude : b.latitude,
        a.longitude > b.longitude ? a.longitude : b.longitude,
      ),
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _runAction(Future<Result<DeliveryOrder, AppError>> Function() call) async {
    _stopSimulation();
    if (_isActionLoading) return;
    setState(() => _isActionLoading = true);
    final result = await call();
    if (mounted) setState(() => _isActionLoading = false);
    result.when(success: (_) {}, failure: (error) => _showSnack(error.message));
  }

  ({String label, IconData icon, Future<void> Function() action})? _actionFor(DeliveryOrder order) {
    final controller = ref.read(ordersControllerProvider.notifier);
    switch (order.currentPhase) {
      case 'en_route_to_pickup':
        return (
          label: 'Reached pickup',
          icon: Icons.storefront_outlined,
          action: () => _runAction(() => controller.reachedPickup(order.id)),
        );
      case 'at_pickup':
        return (
          label: 'Confirm pickup',
          icon: Icons.check_circle_outline,
          action: () => _runAction(() => controller.confirmPickup(order.id)),
        );
      case 'en_route_to_delivery':
        return (
          label: 'Reached drop',
          icon: Icons.flag_outlined,
          action: () => _runAction(() => controller.reachedDrop(order.id)),
        );
      case 'at_drop':
        if (order.dropOtpRequired && !order.dropOtpVerified) {
          return (
            label: 'Verify OTP',
            icon: Icons.verified_user_outlined,
            action: () => _promptDropOtp(order),
          );
        }
        if (!order.isPaid) {
          return (
            label: 'Collect payment',
            icon: Icons.payments_outlined,
            action: () => _showCollectPaymentSheet(order),
          );
        }
        return (
          label: 'Complete delivery',
          icon: Icons.done_all_rounded,
          action: () => _completeDelivery(order),
        );
      default:
        return null;
    }
  }

  Future<void> _completeDelivery(DeliveryOrder order) async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);
    
    _confettiController.play();
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    final result = await ref.read(ordersControllerProvider.notifier).completeOrder(order.id);
    result.when(
      success: (_) {
        ref.read(activeTripVisibilityControllerProvider.notifier).show();
        if (mounted) {
           ref.read(activeTripVisibilityControllerProvider.notifier).hide();
           ref.read(goRouterProvider).go('/main');
        }
      },
      failure: (error) {
        _showSnack(error.message);
        if (mounted) setState(() => _isCompleting = false);
      },
    );
  }

  Future<void> _promptDropOtp(DeliveryOrder order) async {
    final controller = ref.read(ordersControllerProvider.notifier);
    final otp = await showOtpBottomSheet(context, customerName: order.customerName);
    debugPrint('[OTP SEND] sheet returned ${jsonEncode(otp)} len=${otp?.length}');

    if (otp == null || otp.length != 4) {
      debugPrint('[OTP SEND] not sent — need exactly 4 digits');
      if (otp != null && mounted) {
        _showSnack('Enter all 4 digits of the customer\'s code');
      }
      return;
    }

    debugPrint('[OTP SEND] verifying ${jsonEncode(otp)} for order ${order.id}');
    final result = await controller.verifyDropOtp(order.id, otp);
    result.when(
      success: (updatedOrder) async {
        // COD (or any unpaid) order: don't complete just because the OTP
        // matched — wait for payment to actually be collected first.
        if (!updatedOrder.isPaid) {
          if (mounted) await _showCollectPaymentSheet(updatedOrder);
          return;
        }
        if (_isCompleting) return;
        setState(() => _isCompleting = true);

        _confettiController.play();
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          final completeResult = await ref.read(ordersControllerProvider.notifier).completeOrder(order.id);
          completeResult.when(
            success: (_) {
              ref.read(activeTripVisibilityControllerProvider.notifier).hide();
              ref.read(goRouterProvider).go('/main');
            },
            failure: (error) {
              _showSnack(error.message);
              if (mounted) setState(() => _isCompleting = false);
            }
          );
        }
      },
      failure: (error) => _showSnack(error.message),
    );
  }

  Future<void> _showCollectPaymentSheet(DeliveryOrder order) async {
    final collected = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CollectPaymentSheet(order: order),
    );
    if (collected == true && mounted) {
      await _completeDelivery(order);
    }
  }

  void _openChat(DeliveryOrder order) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(order: order)),
    );
  }

  void _openRestaurantGallery(DeliveryOrder order) {
    final images = order.restaurant.allImages;
    if (images.isEmpty) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _RestaurantGalleryViewer(
        images: images,
        restaurantName: order.restaurant.name,
      ),
    );
  }

  Future<void> _dial(String phone) async {
    if (phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _showEmergencyHelp() async {
    final result = await ref.read(supportRepositoryProvider).getEmergencyHelp();
    if (!mounted) return;
    result.when(
      success: (data) {
        final phone = data['accidentHelpline'] as String? ?? data['medicalEmergency'] as String?;
        if (phone != null && phone.isNotEmpty) {
          _dial(phone);
        } else {
          _showSnack('No emergency contact available');
        }
      },
      failure: (error) => _showSnack(error.message),
    );
  }

  Widget _buildMap(DeliveryOrder order) {
    final authState = ref.watch(authControllerProvider);
    final isBike = authState is AuthAuthenticated &&
        (authState.user.vehicleType?.toLowerCase() == 'bike' ||
            authState.user.vehicleType?.toLowerCase() == 'two_wheeler');
    final useCustomMarker = isBike && _bikeMarkerIcon != null;

    return StreamBuilder<Position>(
      stream: ref.read(locationServiceProvider).positionStream,
      initialData: ref.read(locationServiceProvider).lastPosition,
      builder: (context, snapshot) {
        final pos = snapshot.data;
        final initialTarget = pos != null
            ? LatLng(pos.latitude, pos.longitude)
            : (_routeDestination ?? const LatLng(0, 0));
        final isPickupPhase = _targetFor(order) == 'restaurant';
        final hasGalleryImages = order.restaurant.allImages.isNotEmpty;
        final useRestaurantMarker = isPickupPhase && _restaurantMarkerIcon != null;

        return GoogleMap(
          onMapCreated: (controller) => _mapController = controller,
          initialCameraPosition: CameraPosition(target: initialTarget, zoom: 15),
          markers: {
            if (_routeDestination != null)
              Marker(
                markerId: const MarkerId('trip_destination'),
                position: _routeDestination!,
                icon: useRestaurantMarker
                    ? _restaurantMarkerIcon!
                    : BitmapDescriptor.defaultMarkerWithHue(
                        isPickupPhase ? BitmapDescriptor.hueOrange : BitmapDescriptor.hueViolet,
                      ),
                onTap: isPickupPhase && hasGalleryImages
                    ? () {
                        HapticService.light();
                        _openRestaurantGallery(order);
                      }
                    : null,
              ),
            if (useCustomMarker && pos != null)
              Marker(
                markerId: const MarkerId('delivery_partner'),
                position: LatLng(pos.latitude, pos.longitude),
                icon: _bikeMarkerIcon!,
                anchor: const Offset(0.5, 0.5),
                rotation: _currentHeading,
                flat: true,
              ),
          },
          polylines: {
            if (_routePoints.length > 1)
              Polyline(
                polylineId: const PolylineId('active_trip_route'),
                points: _routePoints,
                color: Theme.of(context).primaryColor,
                width: 5,
              ),
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          compassEnabled: false,
          mapToolbarEnabled: false,
          style: MapStyles.mutedGrey,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersState = ref.watch(ordersControllerProvider);

    ref.listen<OrdersState>(ordersControllerProvider, (previous, next) {
      if (next is OrdersLoaded && next.hasActiveOrder) {
        _maybeFetchRoute(next.currentOrder!);
      }
    });

    if (ordersState is! OrdersLoaded || !ordersState.hasActiveOrder) {
      return const SizedBox.shrink();
    }
    final order = ordersState.currentOrder!;

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeFetchRoute(order));

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final isPickupPhase = _targetFor(order) == 'restaurant';
    final title = isPickupPhase ? 'Reach pickup' : 'Reach drop';
    final etaLabel = _etaMins != null
        ? '${_etaMins!.round()} mins away'
        : (order.tripDurationMins != null
            ? '${order.tripDurationMins!.toStringAsFixed(0)} mins away'
            : null);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ref.read(activeTripVisibilityControllerProvider.notifier).hide();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(child: _buildMap(order)),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    _circleIconButton(
                      Icons.menu_rounded,
                      () => ref.read(activeTripVisibilityControllerProvider.notifier).hide(),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24.r),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.waving_hand_rounded, color: theme.primaryColor, size: 18.sp),
                          SizedBox(width: 6.w),
                          Text(
                            title.replaceFirst(' ', '\n'),
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.sp, color: Colors.black87, height: 1.1),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    _circleIconButton(Icons.report_problem_outlined, _showEmergencyHelp),
                    SizedBox(width: 4.w),
                    _circleIconButton(
                      Icons.refresh_rounded,
                      () {
                        ref.read(ordersControllerProvider.notifier).refreshCurrent();
                        _routeKey = null;
                        _maybeFetchRoute(order);
                      },
                    ),
                    if (kDebugMode) ...[
                      SizedBox(width: 4.w),
                      GestureDetector(
                        onTap: () {
                          HapticService.light();
                          _toggleSimulation();
                        },
                        child: Container(
                          width: 40.r,
                          height: 40.r,
                          decoration: BoxDecoration(
                            color: _isSimulating ? Colors.redAccent : Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Icon(
                            _isSimulating ? Icons.stop_rounded : Icons.route_rounded,
                            color: _isSimulating ? Colors.white : Colors.black87,
                            size: 18.sp,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(width: 4.w),
                    _circleIconButton(
                      Icons.call_rounded,
                      () => _dial(isPickupPhase ? (order.restaurant.phone ?? '') : order.customerPhone),
                    ),
                  ],
                ),
              ),
            ),
            if (_isSimulating)
              Positioned(
                top: 70.h,
                left: 16.w,
                right: 16.w,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      'Simulating movement — test only',
                      style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 16.w,
              bottom: 280.h,
              child: GestureDetector(
                onTap: () {
                  HapticService.light();
                  final pos = ref.read(locationServiceProvider).lastPosition;
                  if (pos != null && _mapController != null) {
                    _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Icon(Icons.my_location_rounded, color: Colors.black87, size: 22.sp),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: _buildBottomCard(theme, isDarkMode, textColor, subTextColor, order, etaLabel, isPickupPhase),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.05,
                numberOfParticles: 25,
                gravity: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        HapticService.light();
        onTap();
      },
      child: Container(
        width: 40.r,
        height: 40.r,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 18.sp),
      ),
    );
  }

  Widget _buildBottomCard(
    ThemeData theme,
    bool isDarkMode,
    Color textColor,
    Color? subTextColor,
    DeliveryOrder order,
    String? etaLabel,
    bool isPickupPhase,
  ) {
    final action = _actionFor(order);
    final name = isPickupPhase ? order.restaurant.name : order.customerName;
    final address = isPickupPhase ? order.restaurant.address : order.deliveryAddress.fullAddress;
    final destLat = isPickupPhase ? order.restaurant.location?.lat : order.deliveryAddress.location?.lat;
    final destLng = isPickupPhase ? order.restaurant.location?.lng : order.deliveryAddress.location?.lng;

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 16.h),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(32.r),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, -5)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        isPickupPhase ? 'Pick up' : 'Drop',
                        style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w800, fontSize: 10.sp),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Builder(
                      builder: (context) {
                        final rawImg = isPickupPhase ? order.restaurant.displayImage : order.customerPhoto;
                        final resolvedImg = AppConstants.resolveMediaUrl(rawImg);
                        final defaultIcon = isPickupPhase ? Icons.storefront_rounded : Icons.person_rounded;

                        return GestureDetector(
                          onTap: isPickupPhase && order.restaurant.allImages.isNotEmpty
                              ? () {
                                  HapticService.light();
                                  _openRestaurantGallery(order);
                                }
                              : null,
                          child: ClipOval(
                            child: Container(
                              width: 48.r,
                              height: 48.r,
                              color: Colors.grey[200],
                              alignment: Alignment.center,
                              child: resolvedImg.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: resolvedImg,
                                      fit: BoxFit.cover,
                                      width: 48.r,
                                      height: 48.r,
                                      placeholder: (_, __) => Icon(defaultIcon, color: Colors.grey[500]),
                                      errorWidget: (_, __, ___) => Icon(defaultIcon, color: Colors.grey[500]),
                                    )
                                  : Icon(defaultIcon, color: Colors.grey[500]),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 2.h),
                      Text(name, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp, color: textColor)),
                      if (address.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(top: 4.h),
                          child: Text(address, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, color: subTextColor)),
                        ),
                      if (etaLabel != null)
                        Padding(
                          padding: EdgeInsets.only(top: 6.h),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded, size: 14.sp, color: subTextColor),
                              SizedBox(width: 4.w),
                              Text(etaLabel, style: TextStyle(fontSize: 13.sp, color: subTextColor)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => _dial(isPickupPhase ? (order.restaurant.phone ?? '') : order.customerPhone),
                        child: Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.call_outlined, 
                            size: 16.sp, 
                            color: textColor,
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: () => _openChat(order),
                        child: Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded, 
                            size: 16.sp, 
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Divider(height: 1, color: isDarkMode ? Colors.white12 : Colors.grey[200]),
            SizedBox(height: 20.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _dial(isPickupPhase ? (order.restaurant.phone ?? '') : order.customerPhone),
                    icon: Icon(Icons.call_rounded, size: 20.sp, color: theme.primaryColor),
                    label: Text('Call', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14.sp)),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      side: BorderSide(color: Colors.grey[200]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (destLat != null && destLng != null) {
                        MapLauncher.launchGoogleMaps(destLat, destLng);
                      } else {
                        _showSnack('Location not available');
                      }
                    },
                    icon: Icon(Icons.map_outlined, size: 20.sp, color: theme.primaryColor),
                    label: Text('Map', style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14.sp)),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 14.h),
                      side: BorderSide(color: Colors.grey[200]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            SizedBox(
              width: double.infinity,
              height: 54.h,
              child: ElevatedButton(
                onPressed: _isActionLoading
                    ? null
                    : () {
                        HapticService.light();
                        action?.action();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _tripOnlineGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _tripOnlineGreen.withOpacity(0.6),
                  elevation: 0,
                  // Horizontal only. The SizedBox above already fixes the
                  // height, so vertical padding here was stacked on top of it
                  // and pushed the two text lines past the button's bounds.
                  padding: EdgeInsets.symmetric(horizontal: 14.w),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                ),
                child: Row(
                  children: [
                    Icon(action?.icon ?? Icons.shield_outlined, size: 22.sp),
                    SizedBox(width: 10.w),
                    Expanded(
                      // Both lines are single-line and ellipsised: 'Complete
                      // delivery' and 'Collect payment' wrapped to two lines on
                      // a narrow screen, which is what tipped a 54h button into
                      // a visible overflow stripe.
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isActionLoading ? 'Processing...' : (action?.label ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15.sp,
                              height: 1.15,
                            ),
                          ),
                          Text(
                            _isActionLoading ? 'Please wait' : 'Secure your delivery',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                              height: 1.15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_rounded, size: 14.sp, color: _tripOnlineGreen),
                SizedBox(width: 6.w),
                Text(
                  'Your safety is our priority',
                  style: TextStyle(fontSize: 12.sp, color: subTextColor, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen swipeable viewer for a restaurant's uploaded photos, opened
/// when the delivery partner taps the restaurant's map marker or avatar.
class _RestaurantGalleryViewer extends StatefulWidget {
  const _RestaurantGalleryViewer({required this.images, required this.restaurantName});

  final List<String> images;
  final String restaurantName;

  @override
  State<_RestaurantGalleryViewer> createState() => _RestaurantGalleryViewerState();
}

class _RestaurantGalleryViewerState extends State<_RestaurantGalleryViewer> {
  final PageController _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: widget.images[i],
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, __, ___) =>
                      const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16.sp),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 32.h,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.symmetric(horizontal: 3.w),
                    width: active ? 20.w : 6.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: active ? Colors.white : Colors.white38,
                      borderRadius: BorderRadius.circular(3.r),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}


