import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/core/utils/haptics.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/feedback/app_snackbar.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';

/// Final onboarding step, shown only for accounts the backend flagged as new.
///
/// The backend requires exactly one thing to make an account usable: a name
/// (`PATCH /food/user/profile`, 2–200 chars). Email is accepted but optional,
/// so it's offered rather than demanded — no field here exists that the API
/// doesn't actually consume.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  final String redirectTo;

  const ProfileSetupScreen({super.key, required this.redirectTo});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();

  bool _isSaving = false;
  String? _nameError;
  String? _emailError;

  static const _orange = Color(0xFFFF5700);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _nameFocus.requestFocus());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  bool _validate() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();

    setState(() {
      _nameError = name.length < 2 ? 'Please enter your name' : null;
      _emailError = (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email))
          ? 'Please enter a valid email'
          : null;
    });

    return _nameError == null && _emailError == null;
  }

  Future<void> _save() async {
    Haptics.light();
    if (!_validate()) {
      Haptics.error();
      return;
    }

    setState(() => _isSaving = true);
    final notifier = ref.read(authViewModelProvider.notifier);
    final email = _emailController.text.trim();

    final ok = await notifier.updateProfile(
      name: _nameController.text.trim(),
      email: email.isEmpty ? null : email,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!ok) {
      Haptics.error();
      AppSnackbar.error(context, notifier.lastError ?? 'Could not save your details.');
      return;
    }

    Haptics.success();
    context.go(widget.redirectTo);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final secondary = isDark ? AppColors.textSecondaryDark : const Color(0xFF757575);
    final bg = isDark ? AppColors.backgroundDark : const Color(0xFFFAF9F6);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step 3 of 3 — phone, OTP, then this.
              Row(
                children: List.generate(3, (i) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i == 2 ? 0 : 6),
                      decoration: BoxDecoration(
                        color: _orange,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 28),

              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _orange.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_rounded, color: _orange, size: 32),
              ),
              const SizedBox(height: 20),

              Text(
                'Almost there!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                'Tell us what to call you so we can personalise your orders.',
                style: TextStyle(fontSize: 14, color: secondary, height: 1.35),
              ),
              const SizedBox(height: 28),

              _field(
                controller: _nameController,
                focusNode: _nameFocus,
                label: 'Full Name',
                hint: 'e.g. Tanu Chouhan',
                icon: Icons.person_outline_rounded,
                error: _nameError,
                isDark: isDark,
                textColor: textColor,
                secondary: secondary,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _emailFocus.requestFocus(),
                formatters: [LengthLimitingTextInputFormatter(200)],
              ),
              const SizedBox(height: 16),

              _field(
                controller: _emailController,
                focusNode: _emailFocus,
                label: 'Email',
                hint: 'Optional — for order receipts',
                icon: Icons.mail_outline_rounded,
                error: _emailError,
                isDark: isDark,
                textColor: textColor,
                secondary: secondary,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                formatters: [LengthLimitingTextInputFormatter(200)],
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    disabledBackgroundColor: _orange.withValues(alpha: 0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
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

  Widget _field({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required IconData icon,
    required String? error,
    required bool isDark,
    required Color textColor,
    required Color secondary,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    List<TextInputFormatter>? formatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textColor)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: error != null
                  ? const Color(0xFFE53935)
                  : (isDark ? AppColors.borderDark : const Color(0xFFE5E7EB)),
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onSubmitted: onSubmitted,
            inputFormatters: formatters,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: textColor),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(fontSize: 14, color: secondary, fontWeight: FontWeight.w400),
              prefixIcon: Icon(icon, color: _orange, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(error, style: const TextStyle(fontSize: 12, color: Color(0xFFE53935))),
          ),
      ],
    );
  }
}
