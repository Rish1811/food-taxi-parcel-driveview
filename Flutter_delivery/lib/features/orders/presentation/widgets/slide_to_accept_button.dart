import 'package:flutter/material.dart';
import 'package:food_user_application/core/services/haptic_service.dart';

class SlideToAcceptButton extends StatelessWidget {
  final VoidCallback onAccept;
  final bool isLoading;
  final String text;

  const SlideToAcceptButton({
    super.key,
    required this.onAccept,
    this.isLoading = false,
    this.text = 'ACCEPT ORDER',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () {
                HapticService.light();
                onAccept();
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE85B17),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE85B17).withOpacity(0.6),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                text.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }
}
