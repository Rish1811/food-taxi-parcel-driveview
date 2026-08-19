import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The "Share ticket" call-to-action: a pulsing 3D-styled pill button with
/// tiny warm-colored embers drifting around it.
class FireParticleShareButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;

  const FireParticleShareButton({
    super.key,
    required this.onPressed,
    this.label = 'Share ticket',
  });

  @override
  State<FireParticleShareButton> createState() =>
      _FireParticleShareButtonState();
}

class _FireParticleShareButtonState extends State<FireParticleShareButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Ember> _embers;
  bool _pressed = false;

  static const List<Color> _emberColors = [
    Color(0xFFFFD54F),
    Color(0xFFFFA726),
    Color(0xFFFF7043),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final rnd = math.Random(7);
    _embers = List.generate(10, (i) {
      return _Ember(
        baseAngle: (2 * math.pi / 10) * i,
        orbitRadiusX: 95 + rnd.nextDouble() * 25,
        orbitRadiusY: 34 + rnd.nextDouble() * 10,
        speed: 0.5 + rnd.nextDouble() * 0.5,
        size: 2.0 + rnd.nextDouble() * 2.5,
        phase: rnd.nextDouble() * 2 * math.pi,
        color: _emberColors[i % _emberColors.length],
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 260,
      height: 110,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final pulse = 1.0 + 0.03 * math.sin(_controller.value * 2 * math.pi);
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                size: const Size(260, 110),
                painter: _EmberFieldPainter(
                  t: _controller.value,
                  embers: _embers,
                ),
              ),
              Transform.scale(
                scale: pulse * (_pressed ? 0.95 : 1.0),
                child: GestureDetector(
                  onTapDown: (_) => setState(() => _pressed = true),
                  onTapCancel: () => setState(() => _pressed = false),
                  onTapUp: (_) {
                    setState(() => _pressed = false);
                    widget.onPressed();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(theme.primaryColor, Colors.white, 0.22)!,
                          theme.primaryColor,
                          Color.lerp(theme.primaryColor, Colors.black, 0.25)!,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withOpacity(0.55),
                          blurRadius: 18,
                          spreadRadius: 1,
                          offset: const Offset(0, 6),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.upload, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Ember {
  final double baseAngle;
  final double orbitRadiusX;
  final double orbitRadiusY;
  final double speed;
  final double size;
  final double phase;
  final Color color;

  const _Ember({
    required this.baseAngle,
    required this.orbitRadiusX,
    required this.orbitRadiusY,
    required this.speed,
    required this.size,
    required this.phase,
    required this.color,
  });
}

class _EmberFieldPainter extends CustomPainter {
  final double t;
  final List<_Ember> embers;

  _EmberFieldPainter({required this.t, required this.embers});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final e in embers) {
      final angle = e.baseAngle + t * 2 * math.pi * e.speed;
      final wobble = math.sin(t * 2 * math.pi * 2 + e.phase);
      final dx = center.dx + math.cos(angle) * (e.orbitRadiusX + wobble * 4);
      final dy = center.dy + math.sin(angle) * (e.orbitRadiusY + wobble * 3);
      final opacity =
          (0.35 + 0.65 * ((math.sin(t * 2 * math.pi * 1.3 + e.phase) + 1) / 2))
              .clamp(0.0, 1.0);

      final glowPaint = Paint()
        ..color = e.color.withOpacity(opacity * 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawCircle(Offset(dx, dy), e.size, glowPaint);

      final corePaint = Paint()
        ..color = Colors.white.withOpacity(opacity * 0.8);
      canvas.drawCircle(Offset(dx, dy), e.size * 0.4, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberFieldPainter oldDelegate) =>
      oldDelegate.t != t;
}
