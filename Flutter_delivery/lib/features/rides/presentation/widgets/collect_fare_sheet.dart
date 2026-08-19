import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/features/rides/data/models/taxi_ride.dart';

const _rideGreen = Color(0xFF1EBE5D);

/// What the driver reports having collected when ending the trip.
class FareSettlement {
  const FareSettlement({
    required this.fare,
    required this.paymentMethod,
    required this.collectedByDriver,
  });

  final double fare;

  /// `cash` or whatever the ride was booked with. Sent back so the server
  /// records how the money actually moved, not how it was expected to.
  final String paymentMethod;

  /// True when the driver physically took the money and now owes it to the
  /// platform — this is what drives the cash-in-hand ledger.
  final bool collectedByDriver;
}

/// Final step of the ride — **drop**. Confirms the amount before the trip is
/// closed, because completion is what settles the fare and cannot be undone
/// from the app.
Future<FareSettlement?> showCollectFareSheet(
  BuildContext context,
  TaxiRide ride,
) {
  return showModalBottomSheet<FareSettlement>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CollectFareSheet(ride: ride),
  );
}

class _CollectFareSheet extends StatelessWidget {
  const _CollectFareSheet({required this.ride});

  final TaxiRide ride;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF181C25) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final subText = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 20.h),
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
              SizedBox(height: 20.h),
              Text(
                ride.isCash ? 'Collect from passenger' : 'Trip total',
                style: TextStyle(
                  color: subText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '₹${ride.fare.toStringAsFixed(0)}',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 40.sp,
                  height: 1,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                ride.isCash
                    ? 'Take the cash before ending the trip. The amount is '
                        'added to your cash in hand.'
                    : 'Already paid online. Do not collect cash.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subText, fontSize: 13.sp, height: 1.4),
              ),
              SizedBox(height: 24.h),
              SizedBox(
                height: 54.h,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    HapticService.medium();
                    Navigator.of(context).pop(
                      FareSettlement(
                        fare: ride.fare,
                        paymentMethod: ride.paymentMethod,
                        collectedByDriver: ride.isCash,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rideGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27.r),
                    ),
                  ),
                  child: Text(
                    ride.isCash ? 'CASH RECEIVED · END TRIP' : 'END TRIP',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.sp,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8.h),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Not yet',
                  style: TextStyle(color: subText, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
