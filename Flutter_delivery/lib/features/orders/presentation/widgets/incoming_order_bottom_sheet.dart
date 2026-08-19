import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/delivery_order.dart';

String _fmtKm(double? km) => km == null ? '-- kms' : '${km.toStringAsFixed(2)} kms';

/// Rider to restaurant.
///
/// `pickupDistanceKm` is only present when the offer arrived over the socket —
/// dispatch computes it and bolts it on. An order picked up by the REST poll
/// has no such field, which is why this used to read a confident "0.00 kms".
/// Both coordinates are in the payload, so compute it rather than show a
/// number that is simply wrong.
double? _pickupKm(DeliveryOrder order, Position? rider) {
  if (order.pickupDistanceKm != null) return order.pickupDistanceKm;
  final r = order.restaurant.location;
  if (rider == null || r == null) return null;
  return Geolocator.distanceBetween(
        rider.latitude, rider.longitude, r.lat, r.lng,
      ) /
      1000.0;
}

/// Restaurant to customer — the leg the rider is paid for.
///
/// The backend never sends this on either path, so it is always computed.
double? _dropKm(DeliveryOrder order) {
  if (order.tripDistanceKm != null) return order.tripDistanceKm;
  final r = order.restaurant.location;
  final d = order.deliveryAddress.location;
  if (r == null || d == null) return null;
  return Geolocator.distanceBetween(r.lat, r.lng, d.lat, d.lng) / 1000.0;
}

class IncomingOrderBottomSheet extends StatefulWidget {
  final DeliveryOrder order;

  /// Where the rider is now, used to work out the distance to the
  /// restaurant when the payload does not carry one.
  final Position? riderPosition;
  final ValueListenable<int> secondsLeft;
  final Future<void> Function() onAccept;
  final VoidCallback onReject;
  
  const IncomingOrderBottomSheet({
    Key? key,
    required this.order,
    required this.secondsLeft,
    required this.onAccept,
    required this.onReject,
    this.riderPosition,
  }) : super(key: key);

  @override
  State<IncomingOrderBottomSheet> createState() => _IncomingOrderBottomSheetState();
}

class _IncomingOrderBottomSheetState extends State<IncomingOrderBottomSheet> {
  bool _isAccepting = false;

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    return Container(
      margin: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 24.h),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Main Card
          Container(
            width: double.infinity,
            margin: EdgeInsets.only(top: 16.h), // Space for the overlapping badge
            padding: EdgeInsets.fromLTRB(20.w, 32.h, 20.w, 20.h),
            decoration: BoxDecoration(
              color: const Color(0xFF141414), // Dark grey background matching screenshot
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Estimated earnings',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  '₹${order.riderEarning.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 42.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 12.h),
                // Pickup / Drop distances
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Pickup: ${_fmtKm(_pickupKm(order, widget.riderPosition))}',
                      style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w600),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10.w),
                      child: Text('|', style: TextStyle(color: Colors.white54, fontSize: 13.sp)),
                    ),
                    Text(
                      'Drop: ${_fmtKm(_dropKm(order))}',
                      style: TextStyle(color: Colors.white70, fontSize: 13.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                const Divider(color: Colors.white12, thickness: 1, height: 1),
                SizedBox(height: 24.h),
                // Restaurant info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: const Color(0xFF332014),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        'Pick up',
                        style: TextStyle(
                          color: const Color(0xFFFF7A00),
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.restaurant.name,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            order.restaurant.address,
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13.sp,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Icon(Icons.schedule, color: Colors.white54, size: 14.sp),
                              SizedBox(width: 4.w),
                              Text(
                                '0 mins away',
                                style: TextStyle(color: Colors.white54, fontSize: 12.sp),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32.h),
                // Accept button
                SizedBox(
                  width: double.infinity,
                  height: 54.h,
                  child: ElevatedButton(
                    onPressed: _isAccepting
                        ? null
                        : () async {
                            setState(() => _isAccepting = true);
                            await widget.onAccept();
                            if (mounted) setState(() => _isAccepting = false);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1EBE5D),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF1EBE5D).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      elevation: 0,
                    ),
                    child: _isAccepting
                        ? SizedBox(
                            width: 24.sp,
                            height: 24.sp,
                            child: const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Accept order',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          
          // Floating "New order" Badge
          Positioned(
            top: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'New order',
                style: TextStyle(
                  color: const Color(0xFF1EBE5D),
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
