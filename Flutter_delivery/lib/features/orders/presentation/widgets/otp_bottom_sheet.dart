import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/services/haptic_service.dart';

Future<String?> showOtpBottomSheet(BuildContext context, {required String customerName}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      child: OtpBottomSheetContent(customerName: customerName),
    ),
  );
}

class OtpBottomSheetContent extends StatefulWidget {
  final String customerName;
  const OtpBottomSheetContent({super.key, required this.customerName});

  @override
  State<OtpBottomSheetContent> createState() => _OtpBottomSheetContentState();
}

class _OtpBottomSheetContentState extends State<OtpBottomSheetContent> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _controller.addListener(_onTextChanged);
  }

  bool _submitted = false;

  void _onTextChanged() {
    // Trim before measuring. `TextInputType.number` is only a keyboard *hint* —
    // it does not stop an IME inserting a space, comma or full stop, and this
    // device's numeric pad has all three next to the digits. Without a filter a
    // stray character made "192." four characters long, so this popped a code
    // the server then rejected as invalid even though the driver had typed the
    // right digits.
    final raw = _controller.text;
    final text = raw.trim();

    // TEMPORARY DEBUG — every keystroke, so a digit that never lands is
    // visible rather than inferred from an empty-looking box.
    debugPrint(
      '[OTP FIELD] raw=${jsonEncode(raw)} len=${raw.length} '
      'trimmed=${jsonEncode(text)} len=${text.length} '
      'codes=[${text.codeUnits.join(',')}] submitted=$_submitted',
    );

    if (text.length == 4 && !_submitted) {
      _submitted = true;
      debugPrint('[OTP FIELD] submitting ${jsonEncode(text)}');
      HapticService.medium();
      Navigator.of(context).pop(text);
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Same trimmed view the submit path uses, so the boxes never show a
    // character that would not actually be sent.
    final text = _controller.text.trim();

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline_rounded, color: const Color(0xFF1EBE5D), size: 20.sp),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter Delivery OTP',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16.sp, color: Colors.black87),
                    ),
                    Text(
                      'Ask ${widget.customerName.isNotEmpty ? widget.customerName : "customer"} for 4-digit code',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 18.sp, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),

          Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: 0.0,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  autofocus: true,
                  // The actual guarantee that only digits reach the server.
                  // keyboardType alone is a hint to the IME, nothing more.
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(counterText: ''),
                ),
              ),

              GestureDetector(
                onTap: () => _focusNode.requestFocus(),
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) {
                    final char = index < text.length ? text[index] : '';
                    final isFocused = index == text.length || (index == 3 && text.length == 4);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 54.w,
                      height: 58.h,
                      decoration: BoxDecoration(
                        color: char.isNotEmpty ? const Color(0xFFF0FDF4) : Colors.grey[50],
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: isFocused
                              ? const Color(0xFF1EBE5D)
                              : (char.isNotEmpty ? const Color(0xFF86EFAC) : Colors.grey[300]!),
                          width: isFocused ? 2.0 : 1.0,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF1EBE5D).withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        char,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1E1E1E),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
        ],
      ),
    );
  }
}
