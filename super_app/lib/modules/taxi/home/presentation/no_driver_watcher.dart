import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/modules/taxi/taxi_navigator_key.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_controller.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_state.dart';
import 'package:superapp_user/modules/taxi/home/application/ride_search_controller.dart';
import 'package:superapp_user/modules/taxi/home/application/ride_search_state.dart';

/// Surfaces "no drivers found" no matter which screen the rider is on.
///
/// The dispatch search runs for minutes, and riders wander off the
/// finding-driver screen while they wait. That screen already routes to
/// [NoDriverScreen] on [RideSearchPhase.noDrivers], but only while it is
/// mounted — anywhere else the search simply went silent. Watching the phase at
/// the app root guarantees the rider is told either way.
class NoDriverWatcher extends ConsumerStatefulWidget {
  final Widget child;
  const NoDriverWatcher({super.key, required this.child});

  @override
  ConsumerState<NoDriverWatcher> createState() => _NoDriverWatcherState();
}

class _NoDriverWatcherState extends ConsumerState<NoDriverWatcher> {
  /// One dialog per search. Dispatch can close a ride while a late socket event
  /// is still in flight, and without this the rider gets stacked dialogs.
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<RideSearchState>(rideSearchControllerProvider, (previous, next) {
      if (previous?.phase == next.phase) return;

      if (next.phase != RideSearchPhase.noDrivers) {
        _showing = false;
        return;
      }
      if (_showing) return;
      _showing = true;

      WidgetsBinding.instance.addPostFrameCallback((_) => _showNoDriverDialog());
    });

    return widget.child;
  }

  Future<void> _showNoDriverDialog() async {
    final context = taxiRootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      _showing = false;
      return;
    }

    final retry = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.search_off_rounded, size: 40, color: TaxiColors.primary),
        title: const Text('Driver not found'),
        content: const Text(
          'We could not find a driver nearby right now. '
          'Your booking has been cancelled and you have not been charged.',
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Try again'),
          ),
        ],
      ),
    );

    _showing = false;
    if (!context.mounted) return;

    // Clear the finished search either way, otherwise the stale `noDrivers`
    // phase re-triggers this dialog on the next rebuild.
    ref.read(rideSearchControllerProvider.notifier).reset();

    if (retry == true) {
      ref.read(bookingControllerProvider.notifier).goToStep(BookingStep.confirming);
      GoRouter.of(context).go('/home/confirm');
    } else {
      GoRouter.of(context).go('/home');
    }
  }
}
