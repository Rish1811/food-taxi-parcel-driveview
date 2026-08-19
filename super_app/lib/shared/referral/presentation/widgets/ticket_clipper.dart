import 'package:flutter/material.dart';

/// Helper function that draws a rectangular ticket with scalloped,
/// bitten-out notches in all four corners.
Path ticketOutlinePath(Size size, double notch) {
  final path = Path();

  // Top-Left corner start
  path.moveTo(notch, 0);

  // Top edge
  path.lineTo(size.width - notch, 0);

  // Top-Right corner notch
  path.arcToPoint(
    Offset(size.width, notch),
    radius: Radius.circular(notch),
    clockwise: false,
  );

  // Right edge
  path.lineTo(size.width, size.height - notch);

  // Bottom-Right corner notch
  path.arcToPoint(
    Offset(size.width - notch, size.height),
    radius: Radius.circular(notch),
    clockwise: false,
  );

  // Bottom edge
  path.lineTo(notch, size.height);

  // Bottom-Left corner notch
  path.arcToPoint(
    Offset(0, size.height - notch),
    radius: Radius.circular(notch),
    clockwise: false,
  );

  // Left edge
  path.lineTo(0, notch);

  // Top-Left corner notch
  path.arcToPoint(
    Offset(notch, 0),
    radius: Radius.circular(notch),
    clockwise: false,
  );

  path.close();
  return path;
}

class TicketCardClipper extends CustomClipper<Path> {
  final double notch;

  const TicketCardClipper({this.notch = 14.0});

  @override
  Path getClip(Size size) {
    return ticketOutlinePath(size, notch);
  }

  @override
  bool shouldReclip(covariant TicketCardClipper oldClipper) {
    return oldClipper.notch != notch;
  }
}
