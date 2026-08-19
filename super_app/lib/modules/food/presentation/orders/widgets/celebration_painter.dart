import 'dart:math';
import 'package:flutter/material.dart';

enum ParticleType { confetti, sparkle, food }

class Particle {
  double x, y;
  double vx, vy;
  final Color color;
  final double size;
  final ParticleType type;
  final String? text; // For food emojis
  double rotation;
  double rotationSpeed;
  double life; // 1.0 to 0.0

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    required this.type,
    this.text,
    required this.rotation,
    required this.rotationSpeed,
    this.life = 1.0,
  });
}

class CelebrationPainter extends CustomPainter {
  final List<Particle> particles;
  final double progress; // 0.0 to 1.0, drives the fade out and general timeline

  CelebrationPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty || progress >= 1.0) return;

    final paint = Paint()..style = PaintingStyle.fill;
    // We'll fade everything out as progress nears 1.0
    final globalAlpha = progress > 0.8 ? (1.0 - progress) / 0.2 : 1.0;

    for (final p in particles) {
      if (p.life <= 0) continue;

      final pAlpha = (p.life * globalAlpha).clamp(0.0, 1.0);
      paint.color = p.color.withValues(alpha: pAlpha);

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      if (p.type == ParticleType.confetti) {
        // Draw a small rectangle
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6),
          paint,
        );
      } else if (p.type == ParticleType.sparkle) {
        // Draw a circle or star (we'll just draw a circle with a tiny glow)
        paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
        canvas.drawCircle(Offset.zero, p.size, paint);
        paint.maskFilter = null; // reset
        canvas.drawCircle(Offset.zero, p.size * 0.5, paint..color = Colors.white.withValues(alpha: pAlpha));
      } else if (p.type == ParticleType.food && p.text != null) {
        // Draw text
        final textSpan = TextSpan(
          text: p.text,
          style: TextStyle(fontSize: p.size, color: Colors.white.withValues(alpha: pAlpha)),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(-textPainter.width / 2, -textPainter.height / 2),
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CelebrationPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.particles.length != particles.length;
  }
}

class CelebrationEffect extends StatefulWidget {
  final Widget child;
  const CelebrationEffect({super.key, required this.child});

  @override
  State<CelebrationEffect> createState() => _CelebrationEffectState();
}

class _CelebrationEffectState extends State<CelebrationEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _rnd = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initParticles();
      _controller.forward();
      _controller.addListener(_updateParticles);
    });
  }

  void _initParticles() {
    final size = MediaQuery.of(context).size;
    final colors = [
      const Color(0xFFFF7A00),
      const Color(0xFFFFB039),
      const Color(0xFFFFD56F),
      Colors.white,
    ];
    final foods = ['🍕', '🍔', '🍟', '🥤'];

    _particles.clear();

    // Create explosions from left and right
    for (var side = 0; side < 2; side++) {
      final startX = side == 0 ? size.width * 0.1 : size.width * 0.9;
      final startY = size.height * 0.3; // top 30% of screen

      // Confetti & Sparkles
      for (var i = 0; i < 40; i++) {
        final angle = side == 0
            ? -pi / 2 + (_rnd.nextDouble() * pi / 2) // Shoot up-right
            : -pi + (_rnd.nextDouble() * pi / 2); // Shoot up-left

        final speed = 150 + _rnd.nextDouble() * 300;
        final type = _rnd.nextDouble() > 0.8 ? ParticleType.sparkle : ParticleType.confetti;

        _particles.add(Particle(
          x: startX,
          y: startY,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: colors[_rnd.nextInt(colors.length)],
          size: 4 + _rnd.nextDouble() * 6,
          type: type,
          rotation: _rnd.nextDouble() * pi,
          rotationSpeed: (_rnd.nextDouble() - 0.5) * 4,
          life: 0.8 + _rnd.nextDouble() * 0.2, // some vary life slightly
        ));
      }

      // Food
      for (var i = 0; i < 3; i++) {
        final angle = side == 0
            ? -pi / 2 + (_rnd.nextDouble() * pi / 3)
            : -pi * 5/6 + (_rnd.nextDouble() * pi / 3);
        final speed = 100 + _rnd.nextDouble() * 150;
        _particles.add(Particle(
          x: startX,
          y: startY,
          vx: cos(angle) * speed,
          vy: sin(angle) * speed,
          color: Colors.white,
          size: 24 + _rnd.nextDouble() * 12,
          type: ParticleType.food,
          text: foods[_rnd.nextInt(foods.length)],
          rotation: _rnd.nextDouble() * pi / 4,
          rotationSpeed: (_rnd.nextDouble() - 0.5),
        ));
      }
    }
  }

  void _updateParticles() {
    final dt = 0.016; // Approx 60 FPS delta
    final gravity = 400.0;
    
    for (var p in _particles) {
      if (p.life <= 0) continue;

      p.x += p.vx * dt;
      p.y += p.vy * dt;
      
      if (p.type != ParticleType.food) {
         p.vy += gravity * dt; // Gravity
         // Drag
         p.vx *= 0.98;
      } else {
         // Food floats up slightly then fades
         p.vy += gravity * 0.2 * dt; 
         p.vx *= 0.95;
      }

      p.rotation += p.rotationSpeed * dt;
      p.life -= 0.005; // slowly decay life
    }
    setState(() {}); // trigger repaint
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_controller.isCompleted)
          IgnorePointer(
            child: CustomPaint(
              painter: CelebrationPainter(
                particles: _particles,
                progress: _controller.value,
              ),
              size: Size.infinite,
            ),
          ),
      ],
    );
  }
}
