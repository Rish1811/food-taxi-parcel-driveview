import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:food_user_application/features/orders/presentation/widgets/slide_to_accept_button.dart';
import 'sound_service.dart';

const _applicationId = 'com.k9bharat.delivery';
const _pendingOrderPrefsKey = 'pending_overlay_order';

/// SharedPreferences that reflect what is actually on disk right now.
///
/// The pending-order key is written by one isolate (the FCM background handler)
/// and read by two others (the overlay engine, the main app on resume).
/// getInstance() hands back a per-isolate cached singleton holding a snapshot
/// taken the first time it was called in that isolate, and it never re-reads on
/// its own — so a reader whose isolate was already warm sees a value from before
/// the write and concludes there is no pending order.
///
/// Every cross-isolate read of that key goes through here.
Future<SharedPreferences> _freshPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  try {
    await prefs.reload();
  } catch (_) {
    // Best effort — fall back to whatever the cache holds.
  }
  return prefs;
}

/// Floating "bubble" over the home screen for a new-order alert that arrives
/// while the app is backgrounded — the Rapido/Uber-style overlay, distinct
/// from the lock-screen full-screen-intent notification which already
/// covers the locked-device case.
class OrderOverlayService {
  static Future<bool> hasPermission() async {
    if (!Platform.isAndroid) return false;
    return await FlutterOverlayWindow.isPermissionGranted();
  }

  static Future<void> requestPermission() async {
    if (!Platform.isAndroid) return;
    if (!await FlutterOverlayWindow.isPermissionGranted()) {
      await FlutterOverlayWindow.requestPermission();
    }
  }

  /// Persists [data] so the main isolate can pick it up on resume, then
  /// shows the bubble. Safe to call from the background FCM isolate.
  ///
  /// Returns whether the bubble is actually confirmed on screen. Some OEM
  /// ROMs (MIUI/ColorOS/etc.) silently drop `TYPE_APPLICATION_OVERLAY`
  /// windows even with the permission granted, and the plugin call can also
  /// throw outright — either way the caller needs a truthful answer so it
  /// can fall back to the full-screen-intent notification instead of
  /// leaving the rider with nothing on screen despite the push arriving.
  static Future<bool> showForOrder(Map<String, dynamic> data) async {
    if (!Platform.isAndroid) return false;
    if (!await FlutterOverlayWindow.isPermissionGranted()) return false;

    final encoded = jsonEncode(data);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingOrderPrefsKey, encoded);

      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData(encoded);
        return true;
      }

      await FlutterOverlayWindow.showOverlay(
        // matchParent, NOT WRAP_CONTENT (-2).
        //
        // This is why the card was cut off on some phones and not others. A
        // Flutter platform view never reports its content height to Android:
        // FlutterView.onMeasure returns the space it is offered, not the space
        // the widget tree wants, and there is no round trip where Dart can say
        // "I need N pixels". Under WRAP_CONTENT the window height was therefore
        // decided by the OEM's window manager rather than by the content, and it
        // landed differently per ROM, per density, and per status bar / notch
        // geometry. Where it landed short, the card was clipped -- exactly the
        // reported "cut off on some devices".
        //
        // A full-height window is deterministic and can never clip. The widget
        // tree keeps the card at the top and lets taps below it fall through to
        // dismiss, so this does not go back to being a screen-blocker.
        height: WindowSize.matchParent,
        width: WindowSize.matchParent,
        alignment: OverlayAlignment.topCenter,
        flag: OverlayFlag.focusPointer,
        enableDrag: false,
        positionGravity: PositionGravity.auto,
        overlayTitle: 'New order',
      );

      // Give the platform channel a moment to actually add the window
      // before trusting it succeeded.
      await Future.delayed(const Duration(milliseconds: 400));
      final active = await FlutterOverlayWindow.isActive();

      // Push the payload over the in-memory channel as well, not only via
      // SharedPreferences. The overlay's disk read has proven fragile on some
      // ROMs (Vivo sat on the loading card even after the reload() fix), and
      // shareData needs no disk at all — the overlay's listener receives it
      // directly. Retried because the overlay engine registers that listener
      // asynchronously and an early send is simply dropped. The prefs copy
      // stays: it is what the main isolate consumes on resume, and the
      // overlay still falls back to it when every send loses the race.
      if (active) {
        for (var attempt = 0; attempt < 4; attempt++) {
          await Future.delayed(Duration(milliseconds: 250 * (attempt + 1)));
          try {
            await FlutterOverlayWindow.shareData(encoded);
          } catch (_) {
            // Engine not ready yet — next attempt.
          }
        }
      }
      return active;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openAppWithOrder(Map<String, dynamic> data) async {
    if (!Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingOrderPrefsKey, jsonEncode(data));
    await reopenApp();
  }

  static Future<void> close() async {
    if (!Platform.isAndroid) return;
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (_) {}
  }

  /// Closes the bubble if it is showing [orderId] — used when another rider
  /// accepted first.
  ///
  /// If the stored payload is for a DIFFERENT order the window is left alone: a
  /// newer offer has already replaced this one in place via [shareData], and
  /// closing would throw away a live offer. If nothing is stored the window is
  /// closed anyway, since the only thing it can be showing is the payload the main
  /// isolate already consumed — which is this one.
  static Future<void> closeForOrder(String orderId) async {
    if (!Platform.isAndroid) return;

    final prefs = await _freshPrefs();
    final raw = prefs.getString(_pendingOrderPrefsKey);
    if (raw != null) {
      try {
        final pending = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final pendingId =
            (pending['orderMongoId'] ?? pending['orderId'] ?? pending['_id'])
                ?.toString();
        if (pendingId != null && pendingId != orderId) return;
      } catch (_) {
        // Unreadable payload — treat as ours and clear it.
      }
      await prefs.remove(_pendingOrderPrefsKey);
    }

    await close();
  }

  static Future<Map<String, dynamic>?> consumePendingOrder() async {
    final prefs = await _freshPrefs();
    final raw = prefs.getString(_pendingOrderPrefsKey);
    if (raw == null) return null;
    await prefs.remove(_pendingOrderPrefsKey);
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  static Future<void> reopenApp() async {
    const intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',
      package: _applicationId,
      componentName: '$_applicationId.MainActivity',
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK, Flag.FLAG_ACTIVITY_REORDER_TO_FRONT],
    );
    await intent.launch();
  }
}

class OrderBubbleApp extends StatelessWidget {
  const OrderBubbleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      color: Colors.transparent,
      home: _OrderOverlayUI(),
    );
  }
}

/// Chrome shared by the loading and loaded states of the overlay.
///
/// The window is now full height (see showForOrder), so this is what keeps the
/// alert anchored to the top and stops it becoming a screen-blocker again:
///
///  - Real status bar / notch insets instead of the hardcoded 64px that used to
///    sit here. Cutout heights differ by device, which is why the card looked
///    correctly placed on some phones and jammed under the status bar on others.
///  - The card scrolls if it is ever taller than the screen. On a short or
///    heavily-scaled display the content can exceed the viewport, and a clipped
///    card with the Accept button below the fold is unusable — scrolling
///    degrades instead of truncating.
///  - Everything below the card is transparent and dismisses on tap, so the rest
///    of the screen still behaves as if the overlay were not there.
class _OverlayShell extends StatelessWidget {
  const _OverlayShell({required this.child, required this.onDismiss});

  final Widget child;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              ConstrainedBox(
                // Capped so the scroll view has a bounded height to shrink-wrap
                // into: it then takes the content's height, or this cap if the
                // content is bigger, and scrolls the remainder.
                constraints: BoxConstraints(maxHeight: constraints.maxHeight * 0.92),
                child: SingleChildScrollView(
                  // 48 below the real inset, so the card clears the status bar
                  // and any camera cutout on every device with comfortable spacing.
                  padding: EdgeInsets.fromLTRB(16, topInset + 48, 16, 0),
                  child: child,
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OrderOverlayUI extends StatefulWidget {
  const _OrderOverlayUI();

  @override
  State<_OrderOverlayUI> createState() => _OrderOverlayUIState();
}

class _OrderOverlayUIState extends State<_OrderOverlayUI> {
  Map<String, dynamic>? _orderData;

  /// FCM data values are always Strings, so parse rather than cast.
  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().trim() ?? '') ?? 0.0;
  }

  static String? _str(Object? v) {
    final text = v?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
  late int _secondsLeft;
  Timer? _countdownTimer;
  Timer? _failsafeTimer;
  bool _closing = false;
  bool _submitting = false;

  Timer? _watchdog;
  StreamSubscription<dynamic>? _dataSub;

  @override
  void initState() {
    super.initState();
    _secondsLeft = 45;

    _failsafeTimer = Timer(const Duration(seconds: 70), _forceClose);

    _watchdog = Timer(const Duration(seconds: 5), () {
      if (_orderData == null) {
        debugPrint('[Overlay] Nothing rendered within 5s — closing to free the screen.');
        _forceClose();
      }
    });

    _dataSub = FlutterOverlayWindow.overlayListener.listen((event) {
      try {
        final decoded = jsonDecode(event.toString());
        if (decoded is Map && mounted) {
          final map = Map<String, dynamic>.from(decoded);
          // showForOrder retries shareData several times to beat the race with
          // this listener registering — so the same order arrives more than
          // once. Re-applying it would reset the countdown and replay the
          // alert sound on each retry; only a genuinely different order does.
          final incomingId =
              (map['orderMongoId'] ?? map['orderId'] ?? map['_id'])?.toString();
          final currentId = (_orderData?['orderMongoId'] ??
                  _orderData?['orderId'] ??
                  _orderData?['_id'])
              ?.toString();
          if (incomingId != null && incomingId == currentId) return;

          setState(() {
            _orderData = map;
            _secondsLeft = 45;
          });
          _startCountdown();
          
          if (incomingId != null) {
            SharedPreferences.getInstance().then((prefs) {
              prefs.setString('overlay_rendered_order', incomingId);
            });
          }
        }
      } catch (e) {
        debugPrint('[Overlay] Ignoring unreadable shared data: $e');
      }
    });

    _loadOrder();
  }

  Future<void> _loadOrder({int attempt = 0}) async {
    // _freshPrefs (not getInstance) is what makes the retry below able to
    // succeed, and its absence is why the loading state stuck on some devices.
    //
    // getInstance() hands back a per-isolate cached snapshot and never re-reads
    // the disk. When the overlay engine is reused for a second order — which the
    // plugin does on some ROMs and never on others — that snapshot predates the
    // write the FCM isolate just made, so the key looks absent. The retry loop
    // re-called getInstance() and was handed the SAME stale object every time,
    // so it could not possibly recover: it burned a second and then force-closed.
    // A cold engine worked, a reused one did not, which is exactly the "some
    // devices, sometimes" shape of the report.
    //
    // The write is cross-isolate durable; only the reader's cache was stale.
    final prefs = await _freshPrefs();
    final raw = prefs.getString(_pendingOrderPrefsKey);
    if (raw == null) {
      if (attempt < 5) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (mounted) await _loadOrder(attempt: attempt + 1);
        return;
      }
      debugPrint('[Overlay] No pending order found — closing.');
      await _forceClose();
      return;
    }
    
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      await _forceClose();
      return;
    }

    if (mounted) {
      final incomingId = (decoded['orderMongoId'] ?? decoded['orderId'] ?? decoded['_id'])?.toString();
      setState(() {
        _orderData = Map<String, dynamic>.from(decoded);
      });
      _startCountdown();
      
      if (incomingId != null) {
        prefs.setString('overlay_rendered_order', incomingId);
      }
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    SoundService.playEffect('neworder.mp3');
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        _forceClose();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _forceClose() async {
    if (_closing) return;
    _closing = true;
    _countdownTimer?.cancel();
    _failsafeTimer?.cancel();
    _watchdog?.cancel();
    _dataSub?.cancel();
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (_) {
    } finally {
      _closing = false;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _failsafeTimer?.cancel();
    _watchdog?.cancel();
    _dataSub?.cancel();
    SoundService.stopEffect();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await SoundService.stopEffect();

    // Set autoAccept to true so the main app accepts it upon resuming
    if (_orderData != null) {
      _orderData!['autoAccept'] = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pendingOrderPrefsKey, jsonEncode(_orderData));
    }

    await OrderOverlayService.reopenApp();
    await _forceClose();
  }

  Future<void> _reject() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingOrderPrefsKey);
    await _forceClose();
  }

  @override
  Widget build(BuildContext context) {
    // NEVER return an empty widget here.
    //
    // The window is already attached by the time build runs. Returning
    // SizedBox.shrink() leaves a full-height window with nothing drawn in it and
    // no way for the rider to get rid of it — the original home-screen freeze.
    // Both states below go through _OverlayShell, which always paints something
    // and always leaves the area below it tappable to dismiss.
    if (_orderData == null) {
      // A small card in the same place the order card appears, NOT a full-screen
      // black scrim. The scrim was what read as "the app glitching" on the home
      // screen: it blacked out the whole display for the few hundred ms between
      // the window attaching and the payload being read, which on a slow cold
      // start of the overlay engine is long enough to photograph.
      return _OverlayShell(
        onDismiss: _forceClose,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'New order incoming…',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // This map came from an FCM push, where EVERY value is a String — FCM rejects
    // any other type in `data`. Casting them with `as num?` threw
    // "type 'String' is not a subtype of type 'num?' in type cast", so the overlay
    // rendered a red error box over the launcher instead of the order card. The
    // Accept/Reject buttons only looked broken because they were never drawn.
    final driverEarning = _num(_orderData?['earnings'] ?? _orderData?['riderEarning'] ?? _orderData?['price'] ?? _orderData?['earningAmount'] ?? _orderData?['total']);

    // The push carries ONE road distance for the whole trip, as `tripDistanceKm`
    // (with `distance` as an alias). There are no separate pickup/drop distances,
    // so the previous keys were always absent and both values were silently 0.
    final tripDistance = _num(_orderData?['tripDistanceKm'] ?? _orderData?['distance']);

    // Rider-to-restaurant distance is per-rider, so it only rides on the socket
    // payload — one FCM message is built for the whole broadcast and cannot carry
    // it. Render the line without a distance rather than a confident "0.0 Km".
    final pickupDistance = _num(_orderData?['pickupDistanceKm']);

    // The payload is flat: there is no nested `restaurant` or `deliveryAddress`
    // object to read an address out of, only these string fields.
    final pickupAddr = _str(_orderData?['pickupAddress']) ??
        _str(_orderData?['restaurantAddress']) ??
        _str(_orderData?['restaurantName']) ??
        'Pickup Location';
    final dropAddr = _str(_orderData?['dropAddress']) ??
        _str(_orderData?['customerAddress']) ??
        'Drop Location';

    final customerName = _str(_orderData?['customerName']) ?? 'Customer';

    final tripDurationMinsRaw = _num(_orderData?['tripDurationMins']);
    final tripTimeMins = tripDurationMinsRaw > 0 ? tripDurationMinsRaw : (tripDistance * 3.0);
    final displayTripTime = tripTimeMins > 0 ? tripTimeMins.toStringAsFixed(0) : '--';

    return _OverlayShell(
      onDismiss: _forceClose,
      child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, -4)),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Price Header
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              driverEarning > 0 ? '₹ ${driverEarning.toStringAsFixed(2)}' : '₹ —',
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.black87),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Three blocks row
                          // Row(
                          //   children: [
                          //     _buildStatBlock(
                          //       Icons.access_time_filled_rounded, 
                          //       Colors.amber[600]!, 
                          //       'TRIP TIME', 
                          //       '$displayTripTime MINS'
                          //     ),
                          //     const SizedBox(width: 8),
                          //     _buildStatBlock(
                          //       Icons.location_on_rounded, 
                          //       Colors.blue, 
                          //       'DISTANCE', 
                          //       '${tripDistance.toStringAsFixed(1)} km'
                          //     ),
                          //     const SizedBox(width: 8),
                          //     _buildStatBlock(
                          //       Icons.shopping_bag_rounded, 
                          //       Colors.amber[600]!, 
                          //       'TOTAL ITEMS', 
                          //       '1 Items' // Assumed default if missing
                          //     ),
                          //   ],
                          // ),
                          
                          const SizedBox(height: 16),
                          
                          // Timeline container
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildTimelineRow(
                                  title: 'RESTAURANT PICKUP',
                                  name: _str(_orderData?['restaurantName']) ?? 'Restaurant',
                                  address: pickupAddr,
                                  dotColor: const Color(0xFFE85B17), // Orange
                                  phoneColor: const Color(0xFFE85B17),
                                ),
                                // Dashed line placeholder
                                Padding(
                                  padding: const EdgeInsets.only(left: 3, top: 4, bottom: 4),
                                  child: Container(width: 2, height: 16, color: Colors.grey[300]),
                                ),
                                _buildTimelineRow(
                                  title: 'CUSTOMER DROP',
                                  name: customerName,
                                  address: dropAddr,
                                  dotColor: Colors.blue,
                                  phoneColor: Colors.blue,
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          // Slide to accept and Reject Row
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: _submitting ? null : _accept,
                                  child: Container(
                                    height: 62,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE85B17), // Orange
                                      borderRadius: BorderRadius.circular(31),
                                    ),
                                    alignment: Alignment.center,
                                    child: _submitting
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Text(
                                            'ACCEPT   ·   ${_secondsLeft}s',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 15,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: _reject,
                                child: Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.red[200]!, width: 2),
                                  ),
                                  child: Icon(Icons.close_rounded, color: Colors.red[700], size: 32),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildStatBlock(IconData icon, Color iconColor, String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[500]),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineRow({
    required String title, 
    required String name, 
    required String address, 
    required Color dotColor,
    required Color phoneColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: dotColor)),
              const SizedBox(height: 4),
              Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87)),
              const SizedBox(height: 2),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
