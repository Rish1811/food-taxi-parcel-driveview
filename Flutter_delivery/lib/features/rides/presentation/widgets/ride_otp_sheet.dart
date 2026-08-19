import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:food_user_application/core/services/haptic_service.dart';

const _rideBlue = Color(0xFF1B6FF3);

/// Step 4 of the ride flow — **pickup**.
///
/// The passenger reads the code from their app and the driver types it here.
/// The backend refuses to start a ride without it, so this is a hard gate, not
/// a confirmation dialog: it is the only check that the person getting in is
/// the person who booked.
Future<String?> showRideOtpSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: const _RideOtpSheet(),
    ),
  );
}

class _RideOtpSheet extends StatefulWidget {
  const _RideOtpSheet();

  @override
  State<_RideOtpSheet> createState() => _RideOtpSheetState();
}

/// k9 generates ride OTPs as `1000 + random*9000` — always exactly four digits.
const _otpLength = 4;

class _RideOtpSheetState extends State<_RideOtpSheet> {
  final _controller = TextEditingController();
  bool _valid = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final next = _controller.text.trim().length == _otpLength;
    if (next != _valid) setState(() => _valid = next);

    // Submit the moment the fourth digit lands. Requiring a second tap on a
    // button that is disabled until then is what made this feel broken: tap a
    // fraction early, nothing happens, and there is nothing on screen to say
    // why.
    if (next) _submit();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_valid || _submitted) return;
    _submitted = true;
    HapticService.medium();
    Navigator.of(context).pop(_controller.text.trim());
  }

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
                'Start the trip',
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20.sp,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Ask the passenger for the 4-digit code shown in their app.',
                textAlign: TextAlign.center,
                style: TextStyle(color: subText, fontSize: 13.sp, height: 1.4),
              ),
              SizedBox(height: 22.h),
              TextField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: _otpLength,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onSubmitted: (_) => _submit(),
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 30.sp,
                  letterSpacing: 12,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '0000',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white24 : Colors.grey[350],
                    letterSpacing: 12,
                    fontSize: 30.sp,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF20242E) : const Color(0xFFF2F4F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 18.h),
                ),
              ),
              SizedBox(height: 18.h),
              SizedBox(
                height: 54.h,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _valid ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rideBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _rideBlue.withOpacity(0.4),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(27.r),
                    ),
                  ),
                  child: Text(
                    'START TRIP',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15.sp,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
