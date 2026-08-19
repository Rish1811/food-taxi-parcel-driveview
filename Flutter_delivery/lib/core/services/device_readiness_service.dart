import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import 'order_overlay_service.dart';

/// One prerequisite for reliably receiving orders.
class ReadinessCheck {
  const ReadinessCheck({
    required this.id,
    required this.title,
    required this.description,
    required this.satisfied,
    required this.critical,
  });

  final String id;
  final String title;
  final String description;
  final bool satisfied;

  /// Critical means orders will be missed outright, not merely degraded.
  final bool critical;
}

/// Checks the device settings that decide whether a rider actually receives
/// orders, and opens the right screen to fix each one.
///
/// The foreground service asks Android to keep the process alive, but on Xiaomi,
/// Oppo, Vivo, Realme and Huawei that request is overridden by the vendor's own
/// battery and autostart rules. On those ROMs a rider can be "online" for hours
/// and never be offered anything, with nothing in the app to explain why. This is
/// what Zomato and Swiggy's permission onboarding exists to prevent.
class DeviceReadinessService {
  static const MethodChannel _channel =
      MethodChannel('app.fooddelivery/device_readiness');

  static Future<T> _call<T>(String method, T fallback) async {
    if (!Platform.isAndroid) return fallback;
    try {
      final value = await _channel.invokeMethod<T>(method);
      return value ?? fallback;
    } catch (_) {
      return fallback;
    }
  }

  static Future<String> manufacturer() async {
    final value = await _call<String>('manufacturer', '');
    return value.toLowerCase();
  }

  /// True when this ROM exposes an autostart screen at all. Stock Android and
  /// Pixels do not, and offering a button that cannot open anything is worse
  /// than not showing the step.
  static Future<bool> hasAutoStartSettings() =>
      _call<bool>('hasAutoStartSettings', false);

  static Future<List<ReadinessCheck>> evaluate() async {
    if (!Platform.isAndroid) return const [];

    final notifications = await Permission.notification.isGranted;
    final battery = await _call<bool>('isIgnoringBatteryOptimizations', true);
    final overlay = await OrderOverlayService.hasPermission();
    final hasAutoStart = await hasAutoStartSettings();

    return [
      ReadinessCheck(
        id: 'notifications',
        title: 'Order notifications',
        description:
            'Required to alert you when a new order arrives. Without this you '
            'will not be told about orders at all.',
        satisfied: notifications,
        critical: true,
      ),
      ReadinessCheck(
        id: 'battery',
        title: 'Unrestricted battery usage',
        description:
            'Stops Android pausing the app when your screen is off. This is the '
            'most common reason riders stop getting orders after a while.',
        satisfied: battery,
        critical: true,
      ),
      if (hasAutoStart)
        // Deliberately not treated as satisfied/unsatisfied: there is no API to
        // read this back on any of these ROMs, so claiming to know its state
        // would be a lie. It is presented as a step to confirm once.
        const ReadinessCheck(
          id: 'autostart',
          title: 'Autostart / background run',
          description:
              'Your phone brand blocks apps from running in the background '
              'unless you allow it here. Turn on Autostart for this app.',
          satisfied: false,
          critical: true,
        ),
      ReadinessCheck(
        id: 'overlay',
        title: 'Display over other apps',
        description:
            'Shows the order card on top of whatever you are doing, so you can '
            'accept without opening the app.',
        satisfied: overlay,
        critical: false,
      ),
    ];
  }

  static Future<void> fix(String id) async {
    switch (id) {
      case 'notifications':
        await Permission.notification.request();
        if (!await Permission.notification.isGranted) {
          await _call<bool>('openAppSettings', false);
        }
        break;
      case 'battery':
        await _call<bool>('requestIgnoreBatteryOptimizations', false);
        break;
      case 'autostart':
        final opened = await _call<bool>('openAutoStartSettings', false);
        if (!opened) await _call<bool>('openAppSettings', false);
        break;
      case 'overlay':
        await OrderOverlayService.requestPermission();
        break;
    }
  }

  /// Whether anything the rider must fix is still outstanding.
  ///
  /// Autostart is excluded: it can never report as satisfied, so including it
  /// would make the prompt reappear forever and train riders to dismiss it.
  static Future<bool> hasBlockingIssues() async {
    final checks = await evaluate();
    return checks.any(
      (c) => c.critical && !c.satisfied && c.id != 'autostart',
    );
  }
}
