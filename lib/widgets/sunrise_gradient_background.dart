import 'dart:math';
import 'package:flutter/material.dart';

// Sunrise/Sunset gradient background widget
class SunriseGradientBackground extends StatefulWidget {
  final Widget child;
  final bool isSunset; // true for sunset, false for sunrise

  const SunriseGradientBackground({
    Key? key,
    required this.child,
    this.isSunset = false,
  }) : super(key: key);

  @override
  State<SunriseGradientBackground> createState() =>
      _SunriseGradientBackgroundState();
}

class _SunriseGradientBackgroundState extends State<SunriseGradientBackground>
    with TickerProviderStateMixin {
  late AnimationController _sunController;
  late AnimationController _cloudController;
  late AnimationController _shimmerController;
  final List<Cloud> _clouds = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Sun position animation (subtle movement)
    _sunController = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat(reverse: true);

    // Cloud drift animation
    _cloudController = AnimationController(
      duration: const Duration(seconds: 40),
      vsync: this,
    )..repeat();

    // Shimmer effect on sun rays
    _shimmerController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();

    _generateClouds();
  }

  void _generateClouds() {
    _clouds.clear();
    for (int i = 0; i < 6; i++) {
      final x = _random.nextDouble() * 1.3 - 0.15;
      _clouds.add(
        Cloud(
          startX: x,
          x: x,
          y: _random.nextDouble() * 0.4 + 0.1,
          size: _random.nextDouble() * 60 + 30,
          speed: _random.nextDouble() * 0.2 + 0.05,
          opacity: _random.nextDouble() * 0.3 + 0.1,
        ),
      );
    }
  }

  @override
  void dispose() {
    _sunController.dispose();
    _cloudController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.isSunset
                  ? [
                      // Sunset colors
                      const Color(0xFF1A1A2E), // Dark blue at top
                      const Color(0xFF4A4A8A), // Purple
                      const Color(0xFF8B5A8C), // Warm purple
                      const Color(0xFFFF6B6B), // Coral
                      const Color(0xFFFFCC5C), // Warm yellow
                      const Color(0xFFFFF3A0), // Light yellow at bottom
                    ]
                  : [
                      // Sunrise colors
                      const Color(0xFF0F0F23), // Dark night blue at top
                      const Color(0xFF2C2C6C), // Deep blue
                      const Color(0xFF6B73C1), // Soft blue
                      const Color(0xFFFF8E88), // Soft pink
                      const Color(0xFFFFB74D), // Warm orange
                      const Color(0xFFFFF9C4), // Light cream at bottom
                    ],
              stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
            ),
          ),
        ),

        // Animated sun
        AnimatedBuilder(
          animation: Listenable.merge([_sunController, _shimmerController]),
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: SunPainter(
                _sunController.value,
                _shimmerController.value,
                widget.isSunset,
              ),
            );
          },
        ),

        // Animated clouds
        AnimatedBuilder(
          animation: _cloudController,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: SunriseCloudPainter(
                _clouds,
                _cloudController.value,
                widget.isSunset,
              ),
            );
          },
        ),

        // Child widget
        widget.child,
      ],
    );
  }
}

class SunPainter extends CustomPainter {
  final double animationValue;
  final double shimmerValue;
  final bool isSunset;

  SunPainter(this.animationValue, this.shimmerValue, this.isSunset);

  @override
  void paint(Canvas canvas, Size size) {
    // Sun position (slightly moving)
    final sunY =
        size.height * (isSunset ? 0.7 : 0.75) +
        sin(animationValue * 2 * pi) * 8;
    final sunX = size.width * 0.5 + cos(animationValue * 2 * pi) * 15;

    final sunCenter = Offset(sunX, sunY);
    final sunRadius = size.width * 0.08;

    // Sun rays (shimmer effect)
    final rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 16; i++) {
      final angle = (i * pi / 8) + shimmerValue * pi * 2;
      final rayOpacity = (sin(shimmerValue * 4 * pi + i) * 0.3 + 0.7).clamp(
        0.0,
        1.0,
      );

      rayPaint.color = isSunset
          ? Color.lerp(Colors.orange, Colors.red, 0.3)!.withOpacity(rayOpacity)
          : Colors.yellow.withOpacity(rayOpacity);

      final rayStart =
          sunCenter +
          Offset(cos(angle) * (sunRadius + 10), sin(angle) * (sunRadius + 10));
      final rayEnd =
          sunCenter +
          Offset(cos(angle) * (sunRadius + 25), sin(angle) * (sunRadius + 25));

      canvas.drawLine(rayStart, rayEnd, rayPaint);
    }

    // Sun glow layers
    final glowPaint = Paint()..style = PaintingStyle.fill;

    // Outer glow
    glowPaint.color = isSunset
        ? Colors.orange.withOpacity(0.1)
        : Colors.yellow.withOpacity(0.15);
    canvas.drawCircle(sunCenter, sunRadius * 2.5, glowPaint);

    // Middle glow
    glowPaint.color = isSunset
        ? Colors.orange.withOpacity(0.3)
        : Colors.yellow.withOpacity(0.4);
    canvas.drawCircle(sunCenter, sunRadius * 1.8, glowPaint);

    // Inner glow
    glowPaint.color = isSunset
        ? const Color(0xFFFF6B35).withOpacity(0.6)
        : Colors.yellow.withOpacity(0.7);
    canvas.drawCircle(sunCenter, sunRadius * 1.3, glowPaint);

    // Main sun
    final sunPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = RadialGradient(
        colors: isSunset
            ? [Colors.white, const Color(0xFFFFD700), const Color(0xFFFF6B35)]
            : [Colors.white, const Color(0xFFFFEB3B), const Color(0xFFFFD700)],
      ).createShader(Rect.fromCircle(center: sunCenter, radius: sunRadius));

    canvas.drawCircle(sunCenter, sunRadius, sunPaint);

    // Sun highlights
    final highlightPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white.withOpacity(0.3);

    canvas.drawCircle(
      sunCenter + Offset(-sunRadius * 0.3, -sunRadius * 0.3),
      sunRadius * 0.2,
      highlightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SunriseCloudPainter extends CustomPainter {
  final List<Cloud> clouds;
  final double animationValue;
  final bool isSunset;

  SunriseCloudPainter(this.clouds, this.animationValue, this.isSunset);

  @override
  void paint(Canvas canvas, Size size) {
    for (final cloud in clouds) {
      // Calculate cloud position with wrapping
      final x = (cloud.x + animationValue * cloud.speed) % 1.4 - 0.2;
      final y = cloud.y;

      final center = Offset(x * size.width, y * size.height);
      final radius = cloud.size;

      // Cloud color based on time
      final baseColor = isSunset
          ? const Color(0xFFFF8A65) // Warm orange tint for sunset
          : const Color(0xFFBBDEFB); // Soft blue tint for sunrise

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Color.lerp(
          Colors.white,
          baseColor,
          0.3,
        )!.withOpacity(cloud.opacity);

      // Draw cloud as multiple overlapping circles
      canvas.drawCircle(center, radius, paint);
      canvas.drawCircle(
        center.translate(-radius * 0.6, radius * 0.1),
        radius * 0.7,
        paint,
      );
      canvas.drawCircle(
        center.translate(radius * 0.6, radius * 0.1),
        radius * 0.7,
        paint,
      );
      canvas.drawCircle(
        center.translate(-radius * 0.3, -radius * 0.4),
        radius * 0.5,
        paint,
      );
      canvas.drawCircle(
        center.translate(radius * 0.3, -radius * 0.4),
        radius * 0.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Cloud class (reusing from animated_sky_background)
class Cloud {
  final double startX;
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  Cloud({
    required this.startX,
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}
