import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:superapp_user/core/maps/map_styles.dart';

/// Compass bearing from [a] to [b], in degrees clockwise from north.
///
/// Used to point the bike along its direction of travel. The heading reported by
/// the rider's device is unreliable for this: it comes from the phone's compass or
/// its last GPS course, so it is 0 when stationary and reflects however the phone
/// happens to be lying in a pocket or cradle rather than where the bike is going.
/// Deriving it from consecutive positions always matches the drawn movement.
double bearingBetween(LatLng a, LatLng b) {
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dLon = (b.longitude - a.longitude) * math.pi / 180;
  final y = math.sin(dLon) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) -
      math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

/// Index of the route vertex nearest [rider], searching only from [from]
/// onward so progress along the route is monotonic — a route that doubles back
/// near an earlier stretch must not snap the drawn line backwards.
///
/// Squared degree distance is enough to pick a nearest vertex at city scale;
/// haversine would order these identically.
///
/// ponytail: O(n) per position update (~2s) over a few thousand points —
/// window the scan only if profiling ever shows it mattering.
/// [maxLookahead] bounds how far forward to scan.
///
/// Unbounded is right when a fresh position arrives, which can jump a long way.
/// Per animation frame the marker has moved centimetres, so scanning the whole
/// remaining route 60 times a second would be wasted work — a short window finds
/// the same vertex.
int nearestRouteIndexAhead(
  List<LatLng> route,
  LatLng rider,
  int from, {
  int? maxLookahead,
}) {
  if (route.isEmpty) return 0;
  final start = from.clamp(0, route.length - 1);
  final end = maxLookahead == null
      ? route.length
      : (start + maxLookahead).clamp(0, route.length);
  var bestIdx = start;
  var bestDist = double.infinity;
  for (var i = start; i < end; i++) {
    final dLat = route[i].latitude - rider.latitude;
    final dLng = route[i].longitude - rider.longitude;
    final d = dLat * dLat + dLng * dLng;
    if (d < bestDist) {
      bestDist = d;
      bestIdx = i;
    }
  }
  return bestIdx;
}

/// Live tracking map for an in-progress order.
///
/// Draws the view model's already-decoded route (`routePoints`) plus the rider's
/// live position. Design goals:
///
///  * the route is decoded ONCE per route change, and only re-trimmed — never
///    re-decoded — on a location update;
///  * the rider marker animates between position updates rather than teleporting;
///  * the camera follows the rider;
///  * the `GoogleMap` widget is created once — only the marker/polyline layers
///    update, so the whole map never rebuilds.
///
/// Every coordinate is nullable and absence is honoured rather than substituted.
/// See [riderLat].
class LiveTrackingMap extends StatefulWidget {
  /// The rider's position, or null when it isn't known.
  ///
  /// Null is a first-class state, not a gap to paper over. Callers used to
  /// substitute the restaurant's coordinates here, and everything downstream
  /// believed them: a bike appeared on the restaurant before any rider had
  /// accepted, the camera locked onto it, and the route trim snapped to it — which
  /// on the pre-pickup leg is the route's LAST vertex, so the entire line was
  /// deleted. Pass null and those features simply switch off.
  final double? riderLat;
  final double? riderLng;
  final double heading;
  final double? restaurantLat;
  final double? restaurantLng;
  final double? customerLat;
  final double? customerLng;

  /// Server route, already decoded by the view model.
  final List<PointLatLng> routePoints;

  const LiveTrackingMap({
    super.key,
    required this.riderLat,
    required this.riderLng,
    required this.heading,
    this.restaurantLat,
    this.restaurantLng,
    this.customerLat,
    this.customerLng,
    this.routePoints = const [],
  });

  /// Whether we have a real rider position to draw.
  bool get hasRider => riderLat != null && riderLng != null;

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _controller;

  late final AnimationController _anim;
  BitmapDescriptor? _bikeIcon;
  BitmapDescriptor? _restaurantIcon;
  BitmapDescriptor? _customerIcon;

  /// Built once and reused for every rebuild.
  ///
  /// A freshly-allocated Set here on each build gave the platform view a new
  /// gesture-recognizer configuration sixty times a second, which tore down any
  /// pinch in progress before it could be recognised — the map simply would not
  /// zoom. The recognizers are stateless, so one instance is enough.
  static final Set<Factory<OneSequenceGestureRecognizer>> _mapGestureRecognizers = {
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
  };

  /// Frozen at first build.
  ///
  /// This was rebuilt from the live marker position, so it changed on every one of
  /// those sixty rebuilds. GoogleMap only reads it when the platform view is
  /// created, and feeding it a moving target invites the view to be reconfigured
  /// underneath the user, resetting their zoom.
  late final CameraPosition _frozenInitialCamera;

  /// Direction the bike icon points, derived from its actual movement.
  double _bearing = 0;

  /// Correction for the artwork's own orientation.
  ///
  /// Marker.rotation is measured clockwise from north and rotates the image as
  /// drawn, so it only lines up if the art points up-screen. assets/images/bike.png
  /// is drawn facing DOWN, which made the rider appear to ride in reverse: pointing
  /// south while travelling north.
  static const _iconHeadingOffset = 180.0;

  /// Restaurant and customer never move, so their markers are built once and
  /// reused. They were being reallocated on every animation frame along with the
  /// rider's.
  Set<Marker>? _staticMarkers;

  /// Last frame actually painted, used to cap the repaint rate.
  Duration _lastPaint = Duration.zero;

  /// ~20fps. A vehicle sliding across a map is indistinguishable from 60fps at
  /// this rate, and every repaint rebuilds the GoogleMap subtree — which is what
  /// made the screen lag.
  static const _minPaintGap = Duration(milliseconds: 50);

  /// When the previous position arrived, used to measure the update interval.
  DateTime? _lastPositionAt;

  /// Floor and ceiling for the glide.
  ///
  /// The floor keeps a burst of rapid pings from looking jittery. The ceiling stops
  /// one long gap — a tunnel, a backgrounded rider app — from producing a crawl
  /// that is still animating when the next position lands.
  static const _minLegDuration = Duration(milliseconds: 900);
  static const _maxLegDuration = Duration(seconds: 12);

  /// How long to spend gliding to the next position: as long as the last gap took.
  ///
  /// Interpolating over the real interval is what makes the marker move
  /// continuously instead of stepping. It is deliberately reactive rather than
  /// predictive — no extrapolating past the last known point, so the bike is never
  /// drawn somewhere the rider has not actually reported being.
  Duration _durationForNextLeg() {
    final previous = _lastPositionAt;
    _lastPositionAt = DateTime.now();
    if (previous == null) return _minLegDuration;

    final gap = _lastPositionAt!.difference(previous);
    if (gap < _minLegDuration) return _minLegDuration;
    if (gap > _maxLegDuration) return _maxLegDuration;
    return gap;
  }

  /// Rider position endpoints for the in-flight tween.
  LatLng _from = const LatLng(0, 0);
  LatLng _to = const LatLng(0, 0);

  /// The interpolated position actually painted.
  late LatLng _current;

  /// Cached polyline, rebuilt when the route identity changes or the rider moves.
  Set<Polyline> _polylines = {};
  int _routeSignature = 0;

  /// The full server route, decoded to map coords once per route change.
  List<LatLng> _route = const [];

  /// How far along [_route] the rider has got. Only ever advances, so a route
  /// that doubles back near itself can't snap the drawn line backwards.
  int _progressIndex = 0;

  @override
  void initState() {
    super.initState();
    _current = _cameraTarget();
    _from = _current;
    _to = _current;
    _frozenInitialCamera = CameraPosition(target: _current, zoom: 15);

    _loadCustomMarker();
    _loadPinIcons();

    // Duration is set per update from the MEASURED gap between positions — see
    // _durationForNextLeg. A fixed value cannot work: positions arrive every ~4s
    // over a live socket but only every ~10s on the REST fallback, and a 1.4s tween
    // meant the bike darted forward then sat frozen for the remaining 8.6s.
    _anim = AnimationController(vsync: this, duration: _minLegDuration)
      ..addListener(_onTick);

    _rebuildPolyline();
  }

  /// Where to point the camera when it is first created.
  ///
  /// GoogleMap demands a non-null target, so this picks the first coordinate we
  /// actually have instead of inventing one. The previous code hardcoded Indore's
  /// centre as a fallback, which made a missing coordinate look like a real place
  /// several hundred kilometres from some customers.
  LatLng _cameraTarget() {
    if (widget.hasRider) return LatLng(widget.riderLat!, widget.riderLng!);
    if (widget.restaurantLat != null && widget.restaurantLng != null) {
      return LatLng(widget.restaurantLat!, widget.restaurantLng!);
    }
    if (widget.customerLat != null && widget.customerLng != null) {
      return LatLng(widget.customerLat!, widget.customerLng!);
    }
    final pts = widget.routePoints;
    if (pts.isNotEmpty) return LatLng(pts.first.latitude, pts.first.longitude);
    // Nothing at all to show. Centre of India, zoomed out — obviously not a
    // specific place, which is the honest signal here.
    return const LatLng(20.5937, 78.9629);
  }

  /// Builds the restaurant/customer pins by painting a Material glyph into a
  /// teardrop, rather than shipping a PNG per marker.
  ///
  /// The default `BitmapDescriptor.defaultMarkerWithHue` balloons are the generic
  /// Google pins — two indistinguishable coloured teardrops. Drawing them keeps
  /// each one recognisable at a glance and crisp at any device pixel ratio.
  Future<void> _loadPinIcons() async {
    try {
      final results = await Future.wait([
        _pinFromIcon(Icons.restaurant_rounded, const Color(0xFFE23744)),
        _pinFromIcon(Icons.home_rounded, const Color(0xFF1BA672)),
      ]);
      if (!mounted) return;
      setState(() {
        _restaurantIcon = results[0];
        _customerIcon = results[1];
        // The cached pins were built with the fallback balloons.
        _staticMarkers = null;
      });
    } catch (e) {
      // Falls back to the default balloons — see _buildMarkers.
      debugPrint('Error building map pins: $e');
    }
  }

  static Future<BitmapDescriptor> _pinFromIcon(IconData icon, Color color) async {
    const double w = 96;
    const double h = 122;
    const double r = 44;
    const center = Offset(w / 2, r + 4);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(
      center.translate(0, 4),
      r,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // Tail down to the exact coordinate, so anchor (0.5, 1.0) points at the place.
    final tail = Path()
      ..moveTo(w / 2 - 14, center.dy + r - 10)
      ..lineTo(w / 2, h)
      ..lineTo(w / 2 + 14, center.dy + r - 10)
      ..close();
    canvas.drawPath(tail, Paint()..color = color);

    canvas.drawCircle(center, r, Paint()..color = Colors.white);
    canvas.drawCircle(center, r - 5, Paint()..color = color);

    final glyph = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: r,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white,
        ),
      )
      ..layout();
    glyph.paint(canvas, center - Offset(glyph.width / 2, glyph.height / 2));

    final image = await recorder.endRecording().toImage(w.ceil(), h.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: 3,
    );
  }

  Future<void> _loadCustomMarker() async {
    try {
      final icon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/bike.png',
      );
      if (mounted) {
        setState(() {
          _bikeIcon = icon;
        });
      }
    } catch (e) {
      debugPrint('Error loading bike marker icon: $e');
    }
  }

  @override
  void didUpdateWidget(covariant LiveTrackingMap old) {
    super.didUpdateWidget(old);

    if (widget.hasRider) {
      final target = LatLng(widget.riderLat!, widget.riderLng!);

      if (!old.hasRider) {
        // FIRST real fix: snap, never animate. _current was only ever a camera
        // placeholder (usually the restaurant), so tweening from it sent the bike
        // sliding across the map the moment a rider was assigned.
        _anim.stop();
        // Seed the interval clock so the FIRST glide has a real gap to measure
        // against instead of falling back to the floor.
        _lastPositionAt = DateTime.now();
        _current = target;
        _from = target;
        _to = target;
        // Re-frame now that there is something real to frame.
        WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
      } else if (target != _to) {
        // Subsequent updates animate, so the marker glides instead of teleporting.
        _from = _current;
        _to = target;
        // Point the bike along the leg it is about to travel.
        _bearing = bearingBetween(_from, _to);
        _lastPaint = Duration.zero;
        _anim
          ..duration = _durationForNextLeg()
          ..reset()
          ..forward();
      }
    }

    // Static pins depend on these, so drop the cache when any of them change.
    if (old.restaurantLat != widget.restaurantLat ||
        old.restaurantLng != widget.restaurantLng ||
        old.customerLat != widget.customerLat ||
        old.customerLng != widget.customerLng) {
      _staticMarkers = null;
    }

    // Always call: it self-guards, re-decoding only when the route identity
    // actually changed and otherwise just re-trimming the drawn line to the
    // rider's new position.
    _rebuildPolyline();
  }

  void _onTick() {
    final t = Curves.linear.transform(_anim.value);
    final next = LatLng(
      _from.latitude + (_to.latitude - _from.latitude) * t,
      _from.longitude + (_to.longitude - _from.longitude) * t,
    );

    // Two guards, both to stop needless rebuilds of the GoogleMap subtree.
    //
    // 1e-6 degrees is roughly 10cm — well under a pixel at street zoom, so below
    // that there is nothing to show. And even when it is moving, painting more than
    // ~20 times a second buys nothing the eye can resolve on a sliding vehicle,
    // while costing a full rebuild each time. Together these were the lag.
    //
    // The final frame is never skipped, so the marker always lands exactly on the
    // reported position rather than a fraction short of it.
    final isLastFrame = _anim.value >= 1.0;
    final movedEnough =
        (next.latitude - _current.latitude).abs() > 1e-6 ||
        (next.longitude - _current.longitude).abs() > 1e-6;
    if (!isLastFrame) {
      if (!movedEnough) return;
      final elapsed = _anim.lastElapsedDuration ?? Duration.zero;
      if (elapsed - _lastPaint < _minPaintGap) return;
      _lastPaint = elapsed;
    }

    setState(() => _current = next);
    // Wipe the line as the marker glides, not only when a new position lands.
    //
    // Without this the bike slid smoothly along a line that only shortened every
    // few seconds, so the travelled stretch lagged visibly behind it. The scan is
    // windowed because a frame's worth of movement is tiny, and the polyline is
    // rebuilt ONLY when the index actually changes — route vertices are metres
    // apart, so that is a handful of times a second rather than sixty.
    if (widget.hasRider && _route.isNotEmpty) {
      final advanced = nearestRouteIndexAhead(
        _route,
        _current,
        _progressIndex,
        maxLookahead: 48,
      );
      if (advanced != _progressIndex) {
        _progressIndex = advanced;
        _polylines = _routePolyline(_route.sublist(_progressIndex));
      }
    }

    // Never follow a placeholder position, or the camera locks onto the
    // restaurant and the customer cannot see the rest of the route.
    if (_isAutoFollowEnabled && widget.hasRider) {
      _controller?.moveCamera(CameraUpdate.newLatLng(_current));
    }
  }

  bool _isAutoFollowEnabled = true;

  Future<void> _zoomIn() async {
    _controller?.animateCamera(CameraUpdate.zoomIn());
  }

  Future<void> _zoomOut() async {
    _controller?.animateCamera(CameraUpdate.zoomOut());
  }

  Future<void> _recenterRider() async {
    setState(() => _isAutoFollowEnabled = true);
    await _fitBounds();
  }

  /// Draws the backend's real road route when there is one, and a dotted arc
  /// between the restaurant and the customer when there is not.
  ///
  /// A straight line is not a route, and drawing one styled identically to a real
  /// route would pass it off as the rider's actual path. Dots and a curve are what
  /// make the difference legible: it reads as "these two places are linked" rather
  /// than "this is the road taken", which is exactly how Zomato shows an order that
  /// has not been picked up yet. A solid line here would still be a lie.
  void _rebuildPolyline() {
    // Hash the endpoints too, not just the count: a re-cut route can easily come
    // back with the same number of points, and keying on length alone left the
    // stale line on screen.
    final pts = widget.routePoints;
    final sig = pts.isEmpty
        ? 0
        : Object.hash(pts.length, pts.first.latitude, pts.first.longitude,
            pts.last.latitude, pts.last.longitude);
    final routeChanged = sig != _routeSignature;
    if (!routeChanged && _polylines.isNotEmpty) {
      _trimToRider();
      return;
    }
    // Track the ROAD route, not _polylines: the pending dotted arc also populates
    // _polylines, and counting it as "had a route" suppressed the camera re-fit at
    // the moment the real route finally arrived.
    final hadRoadRoute = _route.isNotEmpty;
    _routeSignature = sig;
    _progressIndex = 0;

    if (pts.isEmpty) {
      if (kDebugMode) debugPrint('[MAP] No road route yet — drawing pending arc');
      _route = const [];
      _polylines = _pendingPolyline();
      return;
    }

    _route = pts.map((p) => LatLng(p.latitude, p.longitude)).toList();
    _trimToRider();
    if (kDebugMode) {
      debugPrint('[MAP] Route loaded: ${_route.length} points');
    }

    // The route just arrived (or changed) — re-fit the camera so the whole
    // path is visible, not just the rider/restaurant/customer pins.
    if (!hadRoadRoute && _controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
    }
  }

  /// Redraws the route starting at the rider rather than at its original origin.
  ///
  /// The route endpoint is only polled every 30s, so between refreshes the line
  /// would keep its travelled stretch painted behind the bike. Snapping the head
  /// of the line to the nearest route point ahead of the rider consumes it as they
  /// ride, with no extra Directions calls.
  ///
  /// Requires a genuine rider fix — see [LiveTrackingMap.riderLat].
  void _trimToRider() {
    if (_route.isEmpty) {
      _polylines = _pendingPolyline();
      return;
    }

    // No genuine rider fix → draw the route untouched. Trimming to the
    // placeholder (the restaurant) would delete the entire pre-pickup route,
    // whose last vertex IS the restaurant.
    if (!widget.hasRider) {
      _progressIndex = 0;
      _polylines = _routePolyline(_route);
      return;
    }

    final rider = LatLng(widget.riderLat!, widget.riderLng!);

    _progressIndex = nearestRouteIndexAhead(_route, rider, _progressIndex);

    // Deliberately NOT prepending the rider's own coordinate. The backend
    // stitches Google's per-step geometry, so vertices land every few metres and
    // the nearest one is already under the bike. Prepending would also head the
    // line at the tween's target while the marker paints the interpolated
    // position, putting the line a hop ahead of the bike on every update.
    final remaining = _route.sublist(_progressIndex);
    // Nearly-consumed route: fall back to the full line rather than blanking the
    // map. The rider is essentially at the destination anyway.
    _polylines = _routePolyline(remaining.length < 2 ? _route : remaining);
  }

  /// Dotted arc from the restaurant to the delivery address, shown while no road
  /// route exists yet — i.e. before a rider has been assigned and located.
  ///
  /// Curved and dotted on purpose. A dead-straight solid line would look like a
  /// route; this reads as a link between two places, which is all it is.
  Set<Polyline> _pendingPolyline() {
    final aLat = widget.restaurantLat;
    final aLng = widget.restaurantLng;
    final bLat = widget.customerLat;
    final bLng = widget.customerLng;
    if (aLat == null || aLng == null || bLat == null || bLng == null) return {};

    final a = LatLng(aLat, aLng);
    final b = LatLng(bLat, bLng);

    // Quadratic bezier bowed perpendicular to the straight line. The control
    // offset is a fraction of the span, so the bow stays proportional at any zoom
    // instead of collapsing on short trips or ballooning on long ones.
    final dLat = b.latitude - a.latitude;
    final dLng = b.longitude - a.longitude;
    final ctrl = LatLng(
      (a.latitude + b.latitude) / 2 - dLng * 0.18,
      (a.longitude + b.longitude) / 2 + dLat * 0.18,
    );

    const steps = 48;
    final arc = <LatLng>[];
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final u = 1 - t;
      arc.add(LatLng(
        u * u * a.latitude + 2 * u * t * ctrl.latitude + t * t * b.latitude,
        u * u * a.longitude + 2 * u * t * ctrl.longitude + t * t * b.longitude,
      ));
    }

    return {
      Polyline(
        polylineId: const PolylineId('pending_route'),
        color: const Color(0xFF9AA0A6),
        width: 4,
        points: arc,
        patterns: [PatternItem.dot, PatternItem.gap(14)],
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    };
  }

  Set<Polyline> _routePolyline(List<LatLng> points) {
    if (points.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        color: const Color(0xFFFF7A00),
        width: 5,
        points: points,
        // Rounded caps and joints are what stop a dense road route from looking
        // like a chain of hard-mitred segments at corners.
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        geodesic: true,
      ),
    };
  }

  /// Restaurant and customer markers, built once per coordinate/icon change.
  ///
  /// These were reallocated on every animation frame alongside the rider's, for
  /// two pins that never move.
  Set<Marker> _buildStaticMarkers() {
    return {
      if (widget.restaurantLat != null && widget.restaurantLng != null)
        Marker(
          markerId: const MarkerId('restaurant'),
          position: LatLng(widget.restaurantLat!, widget.restaurantLng!),
          // Anchored at the tail tip so the pin points at the actual coordinate.
          // Matches the default balloon's anchor, so the fallback lands identically.
          anchor: const Offset(0.5, 1.0),
          icon: _restaurantIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Restaurant'),
        ),
      if (widget.customerLat != null && widget.customerLng != null)
        Marker(
          markerId: const MarkerId('customer'),
          position: LatLng(widget.customerLat!, widget.customerLng!),
          anchor: const Offset(0.5, 1.0),
          icon: _customerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Your address'),
        ),
    };
  }

  Set<Marker> _buildMarkers() {
    final statics = _staticMarkers ??= _buildStaticMarkers();
    return {
      // Only ever drawn for a real rider position. Drawing it unconditionally put
      // a bike on the restaurant before any rider had even accepted the order, and
      // showed a wrong location for an assigned rider we could not yet locate. No
      // marker is the honest answer in both cases.
      if (widget.hasRider)
        Marker(
          markerId: const MarkerId('rider'),
          position: _current,
          // Derived from movement, not the device heading — see bearingBetween.
          rotation: (_bearing + _iconHeadingOffset) % 360,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          icon: _bikeIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: const InfoWindow(title: 'Delivery partner'),
        ),
      ...statics,
    };
  }

  /// Dotted link from the rider to the head of the remaining route.
  ///
  /// The route line starts at the nearest untravelled VERTEX. At city zoom that is
  /// indistinguishable from the marker, but zoomed in — or whenever the rider is off
  /// the road network at all, inside a building, a gated society or a market lane —
  /// the bike floats visibly apart from the line with nothing joining them.
  ///
  /// Dotted rather than solid on purpose: this stretch is NOT a road route. Drawing
  /// it in the same solid orange as the real route would claim Directions returned a
  /// path through a building. Dots say "the rider is over here" and match the arc
  /// used before a rider is assigned.
  ///
  /// Only drawn once the gap is actually worth showing — a sub-metre stub of dots
  /// under the icon is noise. And built as a two-point line rather than prepending
  /// the live position to the route, which would copy the whole remaining list on
  /// every repaint.
  Set<Polyline> _connectorPolyline() {
    if (!widget.hasRider || _route.isEmpty) return const {};
    if (_progressIndex >= _route.length) return const {};

    final head = _route[_progressIndex];
    // ~1e-5 degrees is roughly a metre; below that the marker covers the gap.
    final apart = (head.latitude - _current.latitude).abs() > 1e-5 ||
        (head.longitude - _current.longitude).abs() > 1e-5;
    if (!apart) return const {};

    return {
      Polyline(
        polylineId: const PolylineId('route_connector'),
        color: const Color(0xFFFF7A00),
        width: 4,
        points: [_current, head],
        patterns: [PatternItem.dot, PatternItem.gap(10)],
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        geodesic: true,
      ),
    };
  }

  Future<void> _fitBounds() async {
    final controller = _controller;
    if (controller == null) return;

    final pts = <LatLng>[
      // Same fallback trap as the marker: without a fix these are the
      // restaurant's coordinates, so including them would silently weight the
      // camera towards a place the rider may not be.
      if (widget.hasRider) LatLng(widget.riderLat!, widget.riderLng!),
      if (widget.restaurantLat != null && widget.restaurantLng != null)
        LatLng(widget.restaurantLat!, widget.restaurantLng!),
      if (widget.customerLat != null && widget.customerLng != null)
        LatLng(widget.customerLat!, widget.customerLng!),
      // The route can bow well away from the straight line between those
      // three points on real roads — without these, the camera can crop
      // the middle of the polyline right off the edge of the visible map.
      // Only the untravelled remainder: fitting the whole original route keeps
      // zooming out to include road the rider already left behind.
      if (_route.isNotEmpty) ..._route.sublist(_progressIndex),
    ];
    if (pts.length < 2) return;

    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;
    for (final p in pts) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    if (kDebugMode) {
      debugPrint(
        '[MAP] Fitting camera to ${pts.length} points '
        '(${widget.routePoints.length} from route) — '
        'bounds=($minLat,$minLng)-($maxLat,$maxLng)',
      );
    }
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        56,
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        GoogleMap(
          style: MapStyles.mutedGrey,
          initialCameraPosition: _frozenInitialCamera,
          markers: _buildMarkers(),
          polylines: {..._polylines, ..._connectorPolyline()},
          gestureRecognizers: _mapGestureRecognizers,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          zoomGesturesEnabled: true,
          scrollGesturesEnabled: true,
          tiltGesturesEnabled: true,
          rotateGesturesEnabled: true,
          mapToolbarEnabled: false,
          compassEnabled: true,
          liteModeEnabled: false,
          onCameraMoveStarted: () {
            if (_isAutoFollowEnabled) {
              setState(() => _isAutoFollowEnabled = false);
            }
          },
          onMapCreated: (c) {
            _controller = c;
            WidgetsBinding.instance.addPostFrameCallback((_) => _fitBounds());
          },
        ),

        // Floating Zoom In / Zoom Out / Recenter Control Buttons
        Positioned(
          right: 12,
          bottom: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapControlButton(
                icon: Icons.add_rounded,
                tooltip: 'Zoom in',
                isDark: isDark,
                onTap: _zoomIn,
              ),
              const SizedBox(height: 8),
              _MapControlButton(
                icon: Icons.remove_rounded,
                tooltip: 'Zoom out',
                isDark: isDark,
                onTap: _zoomOut,
              ),
              const SizedBox(height: 8),
              _MapControlButton(
                icon: Icons.center_focus_strong_rounded,
                tooltip: 'Recenter on route',
                isDark: isDark,
                isActive: _isAutoFollowEnabled,
                onTap: _recenterRider,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final bool isActive;
  final VoidCallback onTap;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    this.isActive = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFF7A00)
                : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: isActive
                  ? const Color(0xFFFF7A00)
                  : (isDark ? const Color(0xFF383838) : const Color(0xFFE2E4E8)),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white : const Color(0xFF1E1E1E)),
            size: 20,
          ),
        ),
      ),
    );
  }
}
