import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/auth_controller.dart';
import '../../application/auth_state.dart';
import '../widgets/auth_widgets.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  const OtpVerifyScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  static const _otpLength = 4;
  late final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (index) => TextEditingController(text: '${index + 1}'),
  );
  late final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  bool _isSubmitting = false;
  bool _isResending = false;
  String? _errorText;
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _secondsLeft = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _errorText = null;
    });
    final result = await ref
        .read(authControllerProvider.notifier)
        .requestOtp(widget.phone);
    if (!mounted) return;
    setState(() => _isResending = false);
    result.when(
      success: (_) => _startResendTimer(),
      failure: (error) => setState(() => _errorText = error.message),
    );
  }

  Future<void> _submit() async {
    if (_otp.length != _otpLength) {
      setState(() => _errorText = 'Enter the complete OTP');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final result = await ref
        .read(authControllerProvider.notifier)
        .verifyOtp(phone: widget.phone, otp: _otp);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result is AuthFailure) {
      setState(() => _errorText = result.message);
    }
    // On success the router redirect (driven by authControllerProvider) will
    // navigate automatically based on the new auth state.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 20.h),
              Image.asset(
                'assets/image/verifyotp.png',
                height: 120.h,
                fit: BoxFit.contain,
              ),
              SizedBox(height: 32.h),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  text: 'Verify ',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primaryColor,
                  ),
                  children: [
                    TextSpan(
                      text: 'your number',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                'Enter the OTP sent to',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                '+91 ${widget.phone}',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              SizedBox(height: 40.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_otpLength, (index) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.w),
                    child: SizedBox(
                      width: 56.w,
                      height: 64.h,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: TextStyle(
                          fontSize: 24.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: authInputDecoration(
                          context,
                          label: '',
                        ).copyWith(
                          counterText: '',
                          labelText: null,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (value) {
                          if (value.isNotEmpty && index < _otpLength - 1) {
                            _focusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _focusNodes[index - 1].requestFocus();
                          }
                          if (index == _otpLength - 1 && value.isNotEmpty) {
                            FocusScope.of(context).unfocus();
                          }
                        },
                      ),
                    ),
                  );
                }),
              ),
              if (_errorText != null) ...[
                SizedBox(height: 16.h),
                Text(
                  _errorText!,
                  style: TextStyle(color: Colors.redAccent, fontSize: 13.sp),
                ),
              ],
              SizedBox(height: 40.h),
              AuthPrimaryButton(
                label: 'Verify & Continue',
                isLoading: _isSubmitting,
                onPressed: _submit,
                icon: Container(
                  padding: EdgeInsets.all(2.w),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check,
                    color: AppTheme.primaryColor,
                    size: 14.sp,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              _secondsLeft > 0
                  ? RichText(
                      text: TextSpan(
                        text: 'Resend OTP in ',
                        style: TextStyle(fontSize: 13.sp, color: Colors.grey),
                        children: [
                          TextSpan(
                            text: '$_secondsLeft s',
                            style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
              SizedBox(height: 40.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.shield_outlined, color: AppTheme.primaryColor, size: 24.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Didn't receive the OTP?",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Make sure your number is correct and check your SMS inbox.',
                            style: TextStyle(fontSize: 11.sp, color: Colors.grey, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    if (_secondsLeft == 0) ...[
                      SizedBox(width: 8.w),
                      OutlinedButton(
                        onPressed: _isResending ? null : _resend,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: const BorderSide(color: AppTheme.primaryColor),
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
                        ),
                        child: _isResending
                            ? SizedBox(
                                width: 14.w,
                                height: 14.w,
                                child: const CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text('Resend OTP', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 24.h),
            ],
          ),
        ),
      ),
    );
  }
}
