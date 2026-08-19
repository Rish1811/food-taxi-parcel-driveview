import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'package:superapp_user/shared/referral/presentation/widgets/ticket_clipper.dart';

class RotatingTicketBorder extends StatefulWidget {
  final double width;
  final double height;
  final double notch;
  final Widget child;

  const RotatingTicketBorder({
    super.key,
    required this.width,
    required this.height,
    this.notch = 14.0,
    required this.child,
  });

  @override
  State<RotatingTicketBorder> createState() => _RotatingTicketBorderState();
}

class _RotatingTicketBorderState extends State<RotatingTicketBorder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: _RotatingTicketBorderPainter(
            progress: _controller.value,
            notch: widget.notch,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _RotatingTicketBorderPainter extends CustomPainter {
  final double progress;
  final double notch;

  _RotatingTicketBorderPainter({
    required this.progress,
    required this.notch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = ticketOutlinePath(size, notch);

    final sweepGradient = SweepGradient(
      transform: GradientRotation(progress * 2 * math.pi),
      colors: const [
        Colors.transparent,
        Color(0xFFFF7A00),
        Colors.white,
        Color(0xFFFF7A00),
        Colors.transparent,
      ],
      stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
    );

    final paintShader = sweepGradient.createShader(rect);

    // 1. Outer Blur Glow
    final blurPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..shader = paintShader
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // 2. Inner Crisp Core
    final corePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..shader = paintShader;

    canvas.drawPath(path, blurPaint);
    canvas.drawPath(path, corePaint);
  }

  @override
  bool shouldRepaint(covariant _RotatingTicketBorderPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.notch != notch;
  }
}
