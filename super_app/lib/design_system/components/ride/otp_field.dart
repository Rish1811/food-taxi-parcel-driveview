import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class OtpField extends StatelessWidget {
  final TextEditingController controller;
  final int length;
  final void Function(String) onChanged;
  final void Function(String) onCompleted;

  const OtpField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onCompleted,
    this.length = 4,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxBgColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return PinCodeTextField(
      appContext: context,
      length: length,
      controller: controller,
      keyboardType: TextInputType.number,
      animationType: AnimationType.fade,
      backgroundColor: Colors.transparent,
      onChanged: onChanged,
      onCompleted: onCompleted,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      textStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textColor,
      ),
      pinTheme: PinTheme(
        shape: PinCodeFieldShape.box,
        borderRadius: BorderRadius.circular(12),
        fieldHeight: 50,
        fieldWidth: 50,
        borderWidth: 1.2,
        activeColor: const Color(0xFFFF5200),
        selectedColor: const Color(0xFFFF5200),
        inactiveColor: borderColor,
        activeFillColor: boxBgColor,
        selectedFillColor: boxBgColor,
        inactiveFillColor: boxBgColor,
      ),
      enableActiveFill: true,
      animationDuration: const Duration(milliseconds: 150),
    );
  }
}
