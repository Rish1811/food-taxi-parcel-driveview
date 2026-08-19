import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'referral_ticket_card.dart';

/// Wraps [child] with a bright sweep of light that continuously travels
/// around the ticket's own scalloped outline, like a rotating progress
/// ring traced along the card's edge instead of a plain circle.
class RotatingTicketBorder extends StatefulWidget {
  final Widget child;
  final double width;
  final double height;
  final double notch;
  final Color glowColor;

  const RotatingTicketBorder({
    super.key,
    required this.child,
    required this.width,
    required this.height,
    required this.notch,
    this.glowColor = const Color(0xFFFFD54F),
  });

  @override
  State<RotatingTicketBorder> createState() => _RotatingTicketBorderState();
}

class _RotatingTicketBorderState extends State<RotatingTicketBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      // Clip.none so the blurred glow can bleed slightly past the ticket
      // edge instead of being cut off flush with it.
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              // Explicit size is required — CustomPaint has no intrinsic
              // size of its own inside a Stack and would otherwise paint
              // into a zero-sized canvas.
              size: Size(widget.width, widget.height),
              painter: _RotatingBorderPainter(
                progress: _controller.value,
                notch: widget.notch,
                glowColor: widget.glowColor,
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _RotatingBorderPainter extends CustomPainter {
  final double progress;
  final double notch;
  final Color glowColor;

  _RotatingBorderPainter({
    required this.progress,
    required this.notch,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = ticketOutlinePath(size, notch);

    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = glowColor.withOpacity(0.18);
    canvas.drawPath(path, basePaint);

    final rect = Offset.zero & size;
    final sweep = SweepGradient(
      transform: GradientRotation(progress * 2 * math.pi),
      colors: [
        Colors.transparent,
        glowColor.withOpacity(0.5),
        glowColor.withOpacity(0.95),
        Colors.white,
        glowColor.withOpacity(0.95),
        glowColor.withOpacity(0.5),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 0.68, 0.75, 0.82, 0.95, 1.0],
    );

    final glowPaint = Paint()
      ..shader = sweep.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);

    final corePaint = Paint()
      ..shader = sweep.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant _RotatingBorderPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
