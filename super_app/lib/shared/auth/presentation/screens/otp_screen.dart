import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:superapp_user/shared/auth/presentation/widgets/hero_curve_clipper.dart';
import 'package:superapp_user/shared/auth/presentation/screens/profile_setup_screen.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  /// Echoed back by the backend on dev/staging builds so the field can be
  /// prefilled. Null in production.
  final String? devOtp;
  final String? name;
  final String? fromPath;

  const OtpScreen({
    super.key,
    required this.phoneNumber,
    this.devOtp,
    this.name,
    this.fromPath,
  });

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  int _resendCountdown = 30;
  Timer? _timer;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) debugPrint('[AUTH] OTP screen opened for +91 ${widget.phoneNumber}');
    _startResendTimer();

    // Auto-prefill 1234 in dev mode for smooth 1-tap verification
    final code = widget.devOtp ?? '1234';
    if (code.length == 4) {
      for (int i = 0; i < 4; i++) {
        _controllers[i].text = code[i];
      }
    }

    // Auto focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
      }
    });
  }

  @override
  void dispose() {
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
    _timer?.cancel();
    setState(() => _resendCountdown = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        if (mounted) setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _enteredOtp => _controllers.map((c) => c.text).join();

  void _onOtpDigitChanged(int index, String value) {
    if (value.isNotEmpty) {
      Haptics.light();
      if (index < 3) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        // Auto-submit once all four digits are in — but only if a verification
        // isn't already running, so this can't race the Verify button and
        // submit the single-use OTP twice.
        if (_enteredOtp.length == 4 && !_isVerifying) {
          _verifyOtp();
        }
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _verifyOtp() async {
    // Re-entry guard: the button and the auto-submit path must never both fire.
    // Combined with the view model's single-flight, the OTP is submitted once.
    if (_isVerifying) return;

    final enteredOtp = _enteredOtp;
    if (enteredOtp.length < 4) {
      _showSnackBar(AppSnackbarType.warning, 'Please enter the 4-digit code');
      return;
    }

    setState(() => _isVerifying = true);
    Haptics.medium();

    if (kDebugMode) debugPrint('[AUTH] OTP entered: $enteredOtp');

    final notifier = ref.read(authViewModelProvider.notifier);
    // Submit exactly what the user typed. Substituting the echoed dev OTP would
    // let any wrong code "succeed"; a real "1234" still matches the dev OTP.
    final session = await notifier.verifyOtp(
      phone: widget.phoneNumber,
      otp: enteredOtp,
      name: widget.name,
    );

    if (!mounted) return;
    setState(() => _isVerifying = false);

    if (session == null) {
      // Failure path: no session was created, no auth state changed, no
      // navigation — the user stays a guest.
      _showSnackBar(AppSnackbarType.error, notifier.lastError ?? 'Invalid OTP. Please try again.');
      Haptics.error();
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      return;
    }

    Haptics.success();
    if (kDebugMode) debugPrint('[AUTH] Login completed · redirecting');

    // OtpScreen is pushed imperatively (Navigator/MaterialPageRoute), so it is
    // NOT inside a GoRoute subtree — GoRouterState.of(context) would throw. The
    // redirect target is already threaded in via widget.fromPath.
    final target = widget.fromPath ?? RouteNames.home;

    // A brand-new account has no usable name yet — finish onboarding before
    // dropping the user into the app.
    if (session.needsProfileSetup) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ProfileSetupScreen(redirectTo: target),
        ),
      );
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    context.go(target);
  }

  void _handleResendOtp() async {
    if (_resendCountdown > 0) return;
    Haptics.light();
    final result = await ref.read(authViewModelProvider.notifier).requestOtp(widget.phoneNumber);
    if (!mounted) return;
    if (!result.ok) {
      _showSnackBar(
        AppSnackbarType.error,
        ref.read(authViewModelProvider.notifier).lastError ?? 'Could not resend OTP.',
      );
      return;
    }
    _startResendTimer();
    _showSnackBar(AppSnackbarType.success, 'New OTP code sent to +91 ${widget.phoneNumber}');
  }

  void _showSnackBar(AppSnackbarType type, String msg) {
    if (!mounted) return;
    AppSnackbar.show(context, msg, type: type, duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final bgColor = isDark ? AppColors.backgroundDark : const Color(0xFFFAF9F6);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // Top Curved Hero Image Banner
              SizedBox(
                height: 240,
                width: double.infinity,
                child: Stack(
                  children: [
                    ClipPath(
                      clipper: HeroCurveClipper(),
                      child: const SizedBox(
                        height: 240,
                        width: double.infinity,
                        child: SmartImage(
                          url: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&q=80&w=800',
                          category: ImageCategory.food,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: MediaQuery.of(context).padding.top + 8,
                      left: 16,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: () {
                            Haptics.light();
                            context.pop();
                          },
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Title & Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Verify OTP 🔒',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter the 4-digit code sent to +91 ${widget.phoneNumber}',
                      style: TextStyle(fontSize: 13.5, color: secondaryColor, height: 1.3),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 4 PIN Code Entry Cells
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(4, (index) {
                    final isFocused = _focusNodes[index].hasFocus;
                    return Container(
                      width: 58,
                      height: 60,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: isDark
                            ? (isFocused ? const Color(0xFF2E2E2E) : AppColors.cardDark)
                            : (isFocused ? Colors.white : const Color(0xFFF3F4F6)),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isFocused
                              ? const Color(0xFFFF5700)
                              : (isDark ? AppColors.borderDark : const Color(0xFFE0E0E0)),
                          width: isFocused ? 1.8 : 1.0,
                        ),
                        boxShadow: isFocused
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFF5700).withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          cursorColor: const Color(0xFFFF5700),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            counterText: '',
                            filled: false,
                            fillColor: Colors.transparent,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) => _onOtpDigitChanged(index, val),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              const SizedBox(height: 32),

              // Verify Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26),
                      ),
                    ),
                    onPressed: _isVerifying ? null : _verifyOtp,
                    child: _isVerifying
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text(
                            'Verify & Continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Resend OTP Countdown & Button
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Didn\'t receive OTP? ',
                    style: TextStyle(fontSize: 13.5, color: secondaryColor),
                  ),
                  if (_resendCountdown > 0)
                    Text(
                      'Resend in ${_resendCountdown}s',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _handleResendOtp,
                      child: Text(
                        'Resend OTP',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
