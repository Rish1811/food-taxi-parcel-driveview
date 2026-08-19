import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:food_user_application/features/rides/data/models/taxi_ride.dart';

const _rideBlue = Color(0xFF1B6FF3);

/// Four-step progress strip: Accepted → On the way → On trip → At destination.
///
/// The driver's single most common question mid-ride is "what did I already
/// tell the app?" — a stage they can see is a stage they don't tap twice.
///
/// The order follows k9's lifecycle, where `started` (the pickup) comes
/// *before* `arrived` (reaching the destination). Listing them the intuitive
/// way round would show the strip going backwards at the pickup.
class RideStageTimeline extends StatelessWidget {
  const RideStageTimeline({super.key, required this.stage});

  final RideStage stage;

  static const _steps = <RideStage, String>{
    RideStage.accepted: 'Accepted',
    RideStage.arriving: 'On the way',
    RideStage.started: 'On trip',
    RideStage.arrived: 'At destination',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactive = isDark ? Colors.white24 : const Color(0xFFE3E6EC);
    final entries = _steps.entries.toList();
    final currentIndex = entries.indexWhere((e) => e.key == stage);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(top: 7.h),
                child: Container(
                  height: 3.h,
                  margin: EdgeInsets.symmetric(horizontal: 4.w),
                  decoration: BoxDecoration(
                    color: i <= currentIndex ? _rideBlue : inactive,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
            ),
          _Dot(
            done: i < currentIndex,
            active: i == currentIndex,
            inactive: inactive,
            label: entries[i].value,
          ),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.done,
    required this.active,
    required this.inactive,
    required this.label,
  });

  final bool done;
  final bool active;
  final Color inactive;
  final String label;

  @override
  Widget build(BuildContext context) {
    final filled = done || active;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = active
        ? _rideBlue
        : (isDark ? Colors.white38 : const Color(0xFFB0B8C8));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: active ? 14.w : 10.w,
          height: active ? 14.w : 10.w,
          decoration: BoxDecoration(
            color: filled ? _rideBlue : inactive,
            shape: BoxShape.circle,
            border: active
                ? Border.all(
                    color: _rideBlue.withValues(alpha: 0.3), width: 3)
                : null,
          ),
          child: done
              ? Icon(Icons.check, size: 7.sp, color: Colors.white)
              : null,
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 9.sp,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
