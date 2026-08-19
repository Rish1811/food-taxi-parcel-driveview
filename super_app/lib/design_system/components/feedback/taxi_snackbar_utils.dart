import 'package:flutter/material.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';

class SnackbarUtils {
  SnackbarUtils._();

  static void success(BuildContext context, String message) => _show(
        context,
        message,
        icon: Icons.check_circle_rounded,
        color: TaxiColors.success,
      );

  static void error(BuildContext context, String message) => _show(
        context,
        message,
        icon: Icons.error_rounded,
        color: TaxiColors.error,
      );

  static void info(BuildContext context, String message) => _show(
        context,
        message,
        icon: Icons.info_rounded,
        color: TaxiColors.info,
      );

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    required Color color,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
