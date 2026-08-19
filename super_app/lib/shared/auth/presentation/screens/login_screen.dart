import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';
import 'package:superapp_user/design_system/components/media/smart_image.dart';
import 'package:superapp_user/app/routing/route_names.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:superapp_user/shared/auth/presentation/widgets/hero_curve_clipper.dart';
import 'package:superapp_user/shared/auth/presentation/screens/otp_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? fromPath;
  final int initialTabIndex;

  const LoginScreen({
    super.key,
    this.fromPath,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  final _phoneFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();

  bool _isNewUserMode = false;
  bool _isLoading = false;

  late AnimationController _btnScaleController;
  late Animation<double> _btnScaleAnimation;

  @override
  void initState() {
    super.initState();
    _btnScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _btnScaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _btnScaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();

    _phoneFocus.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();

    _btnScaleController.dispose();
    super.dispose();
  }

  String _getRedirectTarget() {
    final queryFrom = GoRouterState.of(context).uri.queryParameters['from'];
    return widget.fromPath ?? queryFrom ?? RouteNames.home;
  }

  void _handleContinue() async {
    Haptics.light();
    _btnScaleController.forward().then((_) => _btnScaleController.reverse());

    final phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');

    if (phone.length < 10) {
      _showErrorSnackBar('Please enter a valid 10-digit mobile number');
      return;
    }

    final name = _nameController.text.trim();
    if (_isNewUserMode && name.length < 2) {
      _showErrorSnackBar('Please enter your full name');
      return;
    }

    setState(() => _isLoading = true);

    if (kDebugMode) debugPrint('[AUTH] Phone entered: +91 $phone · requesting OTP');
    final result = await ref.read(authViewModelProvider.notifier).requestOtp(phone);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.ok) {
      _showErrorSnackBar(
        ref.read(authViewModelProvider.notifier).lastError ?? 'Could not send OTP. Please try again.',
      );
      return;
    }

    Haptics.medium();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => OtpScreen(
          phoneNumber: phone,
          name: _isNewUserMode ? name : null,
          devOtp: result.devOtp ?? '1234',
          fromPath: _getRedirectTarget(),
        ),
      ),
    );
  }

  void _handleContinueAsGuest() {
    Haptics.light();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.home);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    AppSnackbar.error(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF757575);
    final bgColor = isDark ? AppColors.backgroundDark : const Color(0xFFFAF9F6);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // 1. Top Food Hero Banner (Matching Image Wave Arc)
              _buildCurvedHeroHeader(context),

              // 2. Orange Verified Badge Icon
              Transform.translate(
                offset: const Offset(0, -24),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF5700),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF5700).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.verified_user_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),

              // 3. Title & Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    Text(
                      _isNewUserMode ? 'Complete your Profile' : 'Enter your phone number',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isNewUserMode
                          ? 'Enter your name to register your account with +91 ${_phoneController.text.trim()}'
                          : 'We will send a 4-digit verification code to verify your phone number.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: secondaryTextColor,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Phone Input Box (Matching exact orange border blueprint)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: _buildPhoneInputBox(textColor, secondaryTextColor, isDark),
              ),

              if (_isNewUserMode) ...[
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildModernInputField(
                    controller: _nameController,
                    focusNode: _nameFocus,
                    hintText: 'Full Name (Required)',
                    icon: Icons.person_outline_rounded,
                    textColor: textColor,
                    secondaryColor: secondaryTextColor,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: _buildModernInputField(
                    controller: _emailController,
                    focusNode: _emailFocus,
                    hintText: 'Email Address (Optional)',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    textColor: textColor,
                    secondaryColor: secondaryTextColor,
                    isDark: isDark,
                  ),
                ),
              ],

              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Haptics.light();
                  setState(() {
                    _isNewUserMode = !_isNewUserMode;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isNewUserMode ? 'Already registered? ' : 'New to K9? ',
                        style: TextStyle(fontSize: 13.5, color: secondaryTextColor),
                      ),
                      Text(
                        _isNewUserMode ? 'Sign In' : 'Create Account',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFFF5700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // 5. Continue Orange Primary Button (Gradient + White Right Arrow)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ScaleTransition(
                  scale: _btnScaleAnimation,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6D00), Color(0xFFFF3D00)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4500).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleContinue,
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _isNewUserMode ? 'Continue & Send OTP' : 'Continue',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                              ],
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // 6. Terms & Privacy Check Note
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, color: Color(0xFFFF5700), size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(fontSize: 11.5, color: secondaryTextColor, height: 1.3),
                          children: [
                            const TextSpan(text: 'By continuing, you agree to our '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  context.push(RouteNames.termsConditions);
                                },
                            ),
                            const TextSpan(text: '\n& '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  context.push(RouteNames.privacyPolicy);
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 7. OR Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28.0),
                child: Row(
                  children: [
                    Expanded(child: Divider(color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB), thickness: 1)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: isDark ? AppColors.borderDark : const Color(0xFFE5E5E5), thickness: 1)),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 8. Continue as Guest Button (Pill Outlined)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: InkWell(
                  onTap: _handleContinueAsGuest,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.cardDark : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                        width: 1.2,
                      ),
                      boxShadow: isDark
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_outline_rounded, color: Color(0xFFFF5700), size: 19),
                        SizedBox(width: 8),
                        Text(
                          'Continue as Guest',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF5700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // 9. Bottom 3 Trust Features (100% Secure, Quick & Easy, Loved by Millions)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildTrustFeature(
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF2E7D32),
                      bgColor: const Color(0xFFE8F5E9),
                      title: '100% Secure',
                      subtitle: 'Your data is safe\nwith us',
                      textColor: textColor,
                      secondaryColor: secondaryTextColor,
                    ),
                    _buildTrustFeature(
                      icon: Icons.flash_on_rounded,
                      iconColor: const Color(0xFFF57C00),
                      bgColor: const Color(0xFFFFF3E0),
                      title: 'Quick & Easy',
                      subtitle: 'Get started in\njust seconds',
                      textColor: textColor,
                      secondaryColor: secondaryTextColor,
                    ),
                    _buildTrustFeature(
                      icon: Icons.favorite_rounded,
                      iconColor: const Color(0xFFE91E63),
                      bgColor: const Color(0xFFFCE4EC),
                      title: 'Loved by Millions',
                      subtitle: 'Trusted by food\nlovers like you',
                      textColor: textColor,
                      secondaryColor: secondaryTextColor,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),
            ],
          ),
        ),
      ),
    );
  }

  /// Top Full-bleed Hero Image Header with Wave Arc Clipper
  Widget _buildCurvedHeroHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return SizedBox(
      height: 260,
      width: double.infinity,
      child: Stack(
        children: [
          ClipPath(
            clipper: HeroCurveClipper(),
            child: const SizedBox(
              height: 260,
              width: double.infinity,
              child: SmartImage(
                url: 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&q=80&w=800',
                category: ImageCategory.food,
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (Navigator.of(context).canPop())
            Positioned(
              top: topPadding + 8,
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
    );
  }

  /// Phone Input Box with exact Orange Border & Flag Prefix from Blueprint
  Widget _buildPhoneInputBox(Color textColor, Color secondaryColor, bool isDark) {
    return Container(
      height: 60,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFF5700),
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF5700).withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Flag + +91 Prefix
          Padding(
            padding: const EdgeInsets.only(left: 18.0, right: 12.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🇮🇳', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
              ],
            ),
          ),

          // Vertical Divider line
          Container(
            width: 1,
            height: 28,
            color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
          ),

          const SizedBox(width: 14),

          // Input TextField
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 18.0),
              child: TextField(
                controller: _phoneController,
                focusNode: _phoneFocus,
                readOnly: false,
                keyboardType: TextInputType.phone,
                cursorColor: const Color(0xFFFF5700),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  fontSize: 15.5,
                  fontWeight: FontWeight.w500,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: InputDecoration(
                  filled: false,
                  fillColor: Colors.transparent,
                  hintText: 'Enter 10-digit mobile number',
                  hintStyle: TextStyle(
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          if (_isNewUserMode)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.edit_rounded, size: 18, color: Color(0xFFFF5700)),
                onPressed: () {
                  Haptics.light();
                  setState(() => _isNewUserMode = false);
                  _phoneFocus.requestFocus();
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Modern text input field for name & email
  Widget _buildModernInputField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData icon,
    required Color textColor,
    required Color secondaryColor,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isFocused = focusNode.hasFocus;

    return Container(
      height: 60,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFocused
              ? const Color(0xFFFF5700)
              : (isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
          width: 1.8,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: const Color(0xFFFF5700).withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Center(
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          cursorColor: const Color(0xFFFF5700),
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            filled: false,
            fillColor: Colors.transparent,
            hintText: hintText,
            hintStyle: TextStyle(
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF94A3B8),
              fontSize: 14.5,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              icon,
              color: isFocused ? const Color(0xFFFF5700) : secondaryColor,
              size: 20,
            ),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          ),
        ),
      ),
    );
  }

  /// Trust Feature Column (Icon circle + Title + Subtitle)
  Widget _buildTrustFeature({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color secondaryColor,
  }) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE65100),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: secondaryColor,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
