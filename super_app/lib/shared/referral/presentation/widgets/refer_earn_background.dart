import 'package:flutter/material.dart';

class ReferEarnBackground extends StatelessWidget {
  final Widget child;

  static const Color solid = Color(0xFF0B2418);

  const ReferEarnBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B2418), Color(0xFF04120C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}
