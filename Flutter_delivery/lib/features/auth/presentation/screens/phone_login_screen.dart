import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_theme.dart';
import '../../application/auth_controller.dart';
import '../widgets/auth_widgets.dart';

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    final phone = _phoneController.text.trim();
    final result = await ref.read(authControllerProvider.notifier).requestOtp(phone);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    result.when(
      success: (_) => context.push('/otp-verify', extra: phone),
      failure: (error) => setState(() => _errorText = error.message),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String subtitle) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16.sp, color: AppTheme.primaryColor),
          ),
          SizedBox(width: 6.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 9.sp, color: Colors.grey, height: 1.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 40.h),
                Center( 
                  child: Image.asset(
                    'assets/image/login.png',
                    height: 210.h,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: 24.h),
                RichText(
                  text: TextSpan(
                    text: 'Welcome, ',
                    style: TextStyle(
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text: 'Partner',
                        style: TextStyle(color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Enter your mobile number to start\ndelivering with us.',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 36.h),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                  decoration: authInputDecoration(
                    context,
                    label: '',
                    hint: 'Mobile number',
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(left: 16.w, right: 12.w),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇮🇳', style: TextStyle(fontSize: 20.sp)),
                          SizedBox(width: 8.w),
                          Text(
                            '+91',
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
                          ),
                          SizedBox(width: 4.w),
                          Icon(Icons.keyboard_arrow_down, size: 20.sp, color: Colors.black87),
                          SizedBox(width: 12.w),
                          Container(
                            width: 1,
                            height: 24.h,
                            color: Colors.grey.withValues(alpha: 0.3),
                          ),
                        ],
                      ),
                    ),
                  ).copyWith(counterText: '', labelText: null),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Enter your mobile number';
                    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(v)) {
                      return 'Enter a valid 10-digit mobile number';
                    }
                    return null;
                  },
                ),
                if (_errorText != null) ...[
                  SizedBox(height: 10.h),
                  Text(
                    _errorText!,
                    style: TextStyle(color: Colors.redAccent, fontSize: 13.sp),
                  ),
                ],
                SizedBox(height: 28.h),
                AuthPrimaryButton(
                  label: 'Send OTP',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
                SizedBox(height: 70.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFeatureItem(
                      Icons.verified_user_outlined,
                      'Safe & Secure',
                      'Your data is\nalways protected',
                    ),
                    SizedBox(width: 8.w),
                    _buildFeatureItem(
                      Icons.timer_outlined,
                      'Quick Login',
                      'Fast & easy\nonboarding',
                    ),
                    SizedBox(width: 8.w),
                    _buildFeatureItem(
                      Icons.local_offer_outlined,
                      'Better Earnings',
                      'Deliver more\nearn more',
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
