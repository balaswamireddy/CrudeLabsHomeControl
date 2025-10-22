import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

// Raindrop class
class Raindrop {
  final double startX;
  final double startY;
  final double speed;
  final double size;
  final double opacity;
  final double angle;

  Raindrop({
    required this.startX,
    required this.startY,
    required this.speed,
    required this.size,
    required this.opacity,
    required this.angle,
  });
}

// Lightning class for thunderstorms
class Lightning {
  final List<Offset> points;
  final double opacity;
  final double width;
  final double flickerPhase;

  Lightning({
    required this.points,
    required this.opacity,
    required this.width,
    required this.flickerPhase,
  });
}

// Rainy animated background widget
class RainyAnimatedBackground extends StatefulWidget {
  final Widget child;
  final bool isThunderstorm; // true for thunderstorm, false for regular rain

  const RainyAnimatedBackground({
    Key? key,
    required this.child,
    this.isThunderstorm = false,
  }) : super(key: key);

  @override
  State<RainyAnimatedBackground> createState() =>
      _RainyAnimatedBackgroundState();
}

class _RainyAnimatedBackgroundState extends State<RainyAnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _rainController;
  late AnimationController _cloudController;
  late AnimationController _lightningController;

  final List<Raindrop> _raindrops = [];
  final List<Cloud> _clouds = [];
  final List<Lightning> _lightnings = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Rain animation controller
    _rainController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    // Cloud movement controller
    _cloudController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat();

    // Lightning controller for thunderstorms
    _lightningController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    if (widget.isThunderstorm) {
      _startLightningCycle();
    }

    _generateRaindrops();
    _generateClouds();
  }

  void _generateRaindrops() {
    _raindrops.clear();
    final dropCount = widget.isThunderstorm ? 150 : 100;

    for (int i = 0; i < dropCount; i++) {
      _raindrops.add(
        Raindrop(
          startX: _random.nextDouble() * 1.3 - 0.15,
          startY: -_random.nextDouble() * 0.3,
          speed: _random.nextDouble() * 0.8 + 0.5,
          size: _random.nextDouble() * 2 + 1,
          opacity: _random.nextDouble() * 0.5 + 0.3,
          angle: _random.nextDouble() * 0.3 - 0.15, // Slight angle variation
        ),
      );
    }
  }

  void _generateClouds() {
    _clouds.clear();
    final cloudCount = widget.isThunderstorm ? 12 : 8;

    for (int i = 0; i < cloudCount; i++) {
      final x = _random.nextDouble() * 1.4 - 0.2;
      _clouds.add(
        Cloud(
          startX: x,
          x: x,
          y: _random.nextDouble() * 0.5 + 0.05,
          size: _random.nextDouble() * 80 + 50,
          speed: _random.nextDouble() * 0.15 + 0.05,
          opacity: widget.isThunderstorm
              ? _random.nextDouble() * 0.8 +
                    0.4 // Darker for thunderstorms
              : _random.nextDouble() * 0.6 + 0.3,
        ),
      );
    }
  }

  void _startLightningCycle() {
    if (!widget.isThunderstorm) return;

    // Random lightning every 3-8 seconds
    final delay = Duration(seconds: _random.nextInt(5) + 3);

    Timer(delay, () {
      if (mounted) {
        _generateLightning();
        _lightningController.forward(from: 0.0).then((_) {
          if (mounted) {
            _startLightningCycle(); // Schedule next lightning
          }
        });
      }
    });
  }

  void _generateLightning() {
    _lightnings.clear();

    // Generate 1-2 lightning bolts
    final lightningCount = _random.nextInt(2) + 1;

    for (int i = 0; i < lightningCount; i++) {
      final points = <Offset>[];
      final startX = _random.nextDouble() * 0.8 + 0.1;
      final segments = _random.nextInt(8) + 5;

      double currentX = startX;
      double currentY = 0.0;

      for (int j = 0; j < segments; j++) {
        points.add(Offset(currentX, currentY));

        // Add some randomness to create jagged lightning
        currentX += (_random.nextDouble() - 0.5) * 0.1;
        currentY += 0.8 / segments + _random.nextDouble() * 0.05;

        // Add branches occasionally
        if (_random.nextDouble() < 0.3 && j > 2) {
          final branchPoints = <Offset>[];
          double branchX = currentX;
          double branchY = currentY;

          for (int k = 0; k < 3; k++) {
            branchPoints.add(Offset(branchX, branchY));
            branchX += (_random.nextDouble() - 0.5) * 0.15;
            branchY += 0.1 + _random.nextDouble() * 0.05;
          }

          _lightnings.add(
            Lightning(
              points: branchPoints,
              opacity: _random.nextDouble() * 0.6 + 0.4,
              width: _random.nextDouble() * 2 + 1,
              flickerPhase: _random.nextDouble() * 2 * pi,
            ),
          );
        }
      }

      _lightnings.add(
        Lightning(
          points: points,
          opacity: _random.nextDouble() * 0.8 + 0.6,
          width: _random.nextDouble() * 3 + 2,
          flickerPhase: _random.nextDouble() * 2 * pi,
        ),
      );
    }
  }

  @override
  void dispose() {
    _rainController.dispose();
    _cloudController.dispose();
    _lightningController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: widget.isThunderstorm
                  ? [
                      const Color(0xFF1A1A1A), // Very dark for thunderstorm
                      const Color(0xFF2D2D2D),
                      const Color(0xFF404040),
                      const Color(0xFF555555),
                    ]
                  : [
                      const Color(0xFF607D8B), // Gray-blue for rain
                      const Color(0xFF78909C),
                      const Color(0xFF90A4AE),
                      const Color(0xFFB0BEC5),
                    ],
            ),
          ),
        ),

        // Animated clouds
        AnimatedBuilder(
          animation: _cloudController,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: RainyCloudPainter(
                _clouds,
                _cloudController.value,
                widget.isThunderstorm,
              ),
            );
          },
        ),

        // Lightning (for thunderstorms)
        if (widget.isThunderstorm)
          AnimatedBuilder(
            animation: _lightningController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: LightningPainter(
                  _lightnings,
                  _lightningController.value,
                ),
              );
            },
          ),

        // Animated rain
        AnimatedBuilder(
          animation: _rainController,
          builder: (context, child) {
            return CustomPaint(
              size: Size.infinite,
              painter: RainPainter(_raindrops, _rainController.value),
            );
          },
        ),

        // Child widget
        widget.child,
      ],
    );
  }
}

class RainPainter extends CustomPainter {
  final List<Raindrop> raindrops;
  final double animationValue;

  RainPainter(this.raindrops, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final rainPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final drop in raindrops) {
      // Calculate raindrop position
      final progress = (animationValue + drop.speed) % 1.0;
      final x = (drop.startX + sin(drop.angle) * progress * 0.1) * size.width;
      final y = (drop.startY + progress * 1.3) * size.height;

      // Skip if off screen
      if (y > size.height + 10) continue;

      // Set raindrop properties
      rainPaint.strokeWidth = drop.size;
      rainPaint.color = Colors.lightBlue.withOpacity(drop.opacity);

      // Draw raindrop as a line
      final dropLength = drop.size * 8;
      final startPoint = Offset(x, y);
      final endPoint = Offset(
        x + sin(drop.angle) * dropLength * 0.3,
        y + dropLength,
      );

      canvas.drawLine(startPoint, endPoint, rainPaint);

      // Add small splash effect when near bottom
      if (y > size.height * 0.8) {
        final splashPaint = Paint()
          ..style = PaintingStyle.fill
          ..color = Colors.lightBlue.withOpacity(drop.opacity * 0.3);

        canvas.drawCircle(Offset(x, y), drop.size * 0.5, splashPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class RainyCloudPainter extends CustomPainter {
  final List<Cloud> clouds;
  final double animationValue;
  final bool isThunderstorm;

  RainyCloudPainter(this.clouds, this.animationValue, this.isThunderstorm);

  @override
  void paint(Canvas canvas, Size size) {
    for (final cloud in clouds) {
      final x = (cloud.x + animationValue * cloud.speed) % 1.5 - 0.25;
      final y = cloud.y;

      final center = Offset(x * size.width, y * size.height);
      final radius = cloud.size;

      // Cloud color based on weather
      final cloudColor = isThunderstorm
          ? const Color(0xFF424242) // Dark gray for thunderstorm
          : const Color(0xFF78909C); // Blue-gray for rain

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = cloudColor.withOpacity(cloud.opacity);

      // Draw darker, more dramatic clouds
      canvas.drawCircle(center, radius, paint);
      canvas.drawCircle(
        center.translate(-radius * 0.5, radius * 0.2),
        radius * 0.8,
        paint,
      );
      canvas.drawCircle(
        center.translate(radius * 0.5, radius * 0.2),
        radius * 0.8,
        paint,
      );
      canvas.drawCircle(
        center.translate(-radius * 0.2, -radius * 0.3),
        radius * 0.6,
        paint,
      );
      canvas.drawCircle(
        center.translate(radius * 0.2, -radius * 0.3),
        radius * 0.6,
        paint,
      );

      // Add extra volume for thunderstorm clouds
      if (isThunderstorm) {
        canvas.drawCircle(
          center.translate(0, -radius * 0.6),
          radius * 0.7,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LightningPainter extends CustomPainter {
  final List<Lightning> lightnings;
  final double animationValue;

  LightningPainter(this.lightnings, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    if (animationValue < 0.1 || animationValue > 0.4)
      return; // Only show during flash

    final lightningPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final lightning in lightnings) {
      // Flickering effect
      final flicker =
          sin(animationValue * 20 * pi + lightning.flickerPhase) * 0.3 + 0.7;
      final currentOpacity = (lightning.opacity * flicker).clamp(0.0, 1.0);

      lightningPaint.strokeWidth = lightning.width;
      lightningPaint.color = Colors.white.withOpacity(currentOpacity);

      // Draw lightning bolt
      if (lightning.points.length > 1) {
        final path = Path();
        path.moveTo(
          lightning.points[0].dx * size.width,
          lightning.points[0].dy * size.height,
        );

        for (int i = 1; i < lightning.points.length; i++) {
          path.lineTo(
            lightning.points[i].dx * size.width,
            lightning.points[i].dy * size.height,
          );
        }

        canvas.drawPath(path, lightningPaint);

        // Add glow effect
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = lightning.width * 3
          ..strokeCap = StrokeCap.round
          ..color = Colors.blue.withOpacity(currentOpacity * 0.3);

        canvas.drawPath(path, glowPaint);
      }
    }

    // Screen flash effect during peak lightning
    if (animationValue > 0.15 && animationValue < 0.25) {
      final flashOpacity = (0.3 * sin((animationValue - 0.15) * pi / 0.1))
          .clamp(0.0, 0.3);
      final flashPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(flashOpacity);

      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), flashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Cloud class (reusing from other backgrounds)
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
