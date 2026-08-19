import 'package:flutter/material.dart';

/// Custom Clipper creating an organic wave-curved bottom edge for the
/// Auth screen top hero food banner, matching the screenshot 1:1.
class HeroCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    // Start at top-left, line down to left curve start
    path.lineTo(0, h * 0.78);

    // First crest and valley to center
    path.cubicTo(
      w * 0.22, h * 0.62,
      w * 0.35, h * 1.02,
      w * 0.50, h * 0.82,
    );

    // Second valley and crest to right edge
    path.cubicTo(
      w * 0.65, h * 0.62,
      w * 0.78, h * 1.02,
      w, h * 0.78,
    );

    // Line to top-right corner and close path
    path.lineTo(w, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
