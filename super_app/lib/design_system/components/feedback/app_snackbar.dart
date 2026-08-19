import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:superapp_user/design_system/tokens/app_colors.dart';
import 'package:superapp_user/design_system/components/feedback/top_toast.dart';

enum AppSnackbarType { success, error, warning, info }

/// AppSnackbar handles notifications app-wide.
/// - If NO user action is required (action == null), it displays a sleek Top Toast
///   below the status bar that auto-dismisses after 2 seconds with slide & fade animations.
/// - If a user action IS required (action != null), it renders a bottom floating SnackBar.
class AppSnackbar {
  AppSnackbar._();

  static const _warning = Color(0xFFFFA726);

  static void show(
    BuildContext context,
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    if (action == null) {
      // Use Top Toast for non-actionable notifications
      final topToastType = switch (type) {
        AppSnackbarType.success => TopToastType.success,
        AppSnackbarType.error => TopToastType.error,
        AppSnackbarType.warning => TopToastType.warning,
        AppSnackbarType.info => TopToastType.info,
      };

      TopToast.show(
        context,
        message,
        type: topToastType,
        duration: duration,
      );
    } else {
      // Use bottom SnackBar ONLY when an interactive SnackBarAction is required
      final (color, icon) = switch (type) {
        AppSnackbarType.success => (
            AppColors.success,
            Icons.check_circle_rounded,
          ),
        AppSnackbarType.error => (AppColors.error, Icons.error_rounded),
        AppSnackbarType.warning => (_warning, Icons.warning_rounded),
        AppSnackbarType.info => (AppColors.primary, Icons.info_rounded),
      };

      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          elevation: 6,
          duration: duration,
          margin: EdgeInsets.fromLTRB(
            16,
            0,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          action: action,
        ),
      );
    }
  }

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) =>
      show(
        context,
        message,
        type: AppSnackbarType.success,
        duration: duration,
        action: action,
      );

  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) =>
      show(
        context,
        message,
        type: AppSnackbarType.error,
        duration: duration,
        action: action,
      );

  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) =>
      show(
        context,
        message,
        type: AppSnackbarType.warning,
        duration: duration,
        action: action,
      );

  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) =>
      show(
        context,
        message,
        type: AppSnackbarType.info,
        duration: duration,
        action: action,
      );
}
