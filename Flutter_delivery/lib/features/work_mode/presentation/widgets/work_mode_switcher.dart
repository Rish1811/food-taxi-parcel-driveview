import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Result's `when` is a freezed extension — it only resolves where the
// declaring library is imported, even though Result itself is never named here.
import 'package:food_user_application/core/error/result.dart';
import 'dart:async';

import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/features/orders/application/incoming_order_controller.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/profile/application/availability_controller.dart';
import 'package:food_user_application/features/rides/application/incoming_ride_controller.dart';
import 'package:food_user_application/features/work_mode/presentation/widgets/online_selfie_gate.dart';
import 'package:food_user_application/features/work_mode/application/work_mode_controller.dart';
import 'package:food_user_application/features/work_mode/data/work_mode.dart';
import 'package:food_user_application/features/work_mode/data/work_mode_repository.dart';

const _foodOrange = Color(0xFFE85B17);
const _taxiBlue = Color(0xFF1B6FF3);
const _bothPurple = Color(0xFF7C4DFF);

/// The Food / Taxi / Both switch — the app's headline control.
///
/// Choosing a mode is what decides which dispatcher may reach this driver, so
/// it is a server call, not a local preference. A mode the driver is not
/// approved for is shown disabled with the reason rather than hidden, so it is
/// obvious the option exists and why it is unavailable.
class WorkModeSwitcher extends ConsumerWidget {
  const WorkModeSwitcher({super.key});

  static Color colorOf(WorkMode mode) {
    switch (mode) {
      case WorkMode.delivery:
        return _foodOrange;
      case WorkMode.taxi:
        return _taxiBlue;
      case WorkMode.all:
        return _bothPurple;
    }
  }

  static IconData iconOf(WorkMode mode) {
    switch (mode) {
      case WorkMode.delivery:
        return Icons.restaurant_rounded;
      case WorkMode.taxi:
        return Icons.local_taxi_rounded;
      case WorkMode.all:
        return Icons.all_inclusive_rounded;
    }
  }

  Future<void> _select(
    BuildContext context,
    WidgetRef ref,
    WorkMode mode,
    WorkModeStatus status,
  ) async {
    if (!mode.isAllowedFor(status.capabilities)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mode.unavailableReason())),
      );
      return;
    }
    HapticService.light();

    // Turning rides on mid-shift needs today's selfie, same as going online
    // does — without it the mode switches and no ride ever arrives.
    String? selfieUrl;
    final wasAcceptingRides = status.mode.acceptsRides;
    if (mode.acceptsRides && !wasAcceptingRides) {
      final gate = await ensureOnlineSelfie(context, ref, needsRides: true);
      if (!gate.proceed || !context.mounted) return;
      selfieUrl = gate.imageUrl;
    }

    final result =
        await ref.read(workModeControllerProvider.notifier).select(mode);
    if (!context.mounted) return;
    await result.when(
      success: (_) async {
        // Anything already on screen for the service just switched off is now
        // wrong. Drop it rather than leaving a food alert ringing at a driver
        // who has just gone Taxi-only.
        if (!mode.acceptsFood) {
          ref.read(incomingOrderControllerProvider.notifier).dismiss();
        }
        if (!mode.acceptsRides) {
          ref.read(incomingRideControllerProvider.notifier).dismiss();
        }
        // The list is polled every 15s; refresh now so the change is visible
        // immediately instead of the toggle appearing to do nothing.
        unawaited(ref.read(ordersControllerProvider.notifier).refreshAvailable());

        // The mode is stored server-side, but `Driver.isOnline` is a separate
        // field that dispatch also filters on — bring it in line with the mode
        // the driver just picked.
        final rideError = await ref
            .read(availabilityControllerProvider.notifier)
            .syncRideAvailability(selfieImageUrl: selfieUrl);
        if (rideError != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No ride requests: $rideError')),
          );
        }
      },
      failure: (error) async => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFF04438),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workModeControllerProvider);
    final status = async.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A driver approved for one service only has nothing to choose. Showing a
    // switcher where two of three options can never be picked is worse than
    // showing none.
    if (status == null || status.isSingleService) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(4.r),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF20242E) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        children: [
          for (final mode in WorkMode.values)
            Expanded(
              child: _ModeTab(
                mode: mode,
                selected: status.mode == mode,
                enabled: mode.isAllowedFor(status.capabilities),
                onTap: () => _select(context, ref, mode, status),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.mode,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final WorkMode mode;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = WorkModeSwitcher.colorOf(mode);
    final Color foreground;
    if (selected) {
      foreground = Colors.white;
    } else if (!enabled) {
      foreground = isDark ? Colors.white24 : Colors.grey.shade400;
    } else {
      foreground = isDark ? Colors.grey.shade300 : Colors.grey.shade700;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(vertical: 11.h),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(WorkModeSwitcher.iconOf(mode), size: 16.sp, color: foreground),
            SizedBox(width: 6.w),
            Text(
              mode.label,
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w800,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
