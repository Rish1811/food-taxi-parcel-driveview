import 'package:flutter/material.dart';

/// The dark green vignette backdrop used across the Refer & Earn flow —
/// a deep green glow fading out to near-black at the edges.
class ReferEarnBackground extends StatelessWidget {
  final Widget child;

  const ReferEarnBackground({super.key, required this.child});

  static const Color solid = Color(0xFF07120A);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -0.35),
          radius: 1.3,
          colors: [
            Color(0xFF1D4626),
            Color(0xFF0B2313),
            Color(0xFF060F08),
            Color(0xFF000000),
          ],
          stops: [0.0, 0.45, 0.75, 1.0],
        ),
      ),
      child: child,
    );
  }
}
