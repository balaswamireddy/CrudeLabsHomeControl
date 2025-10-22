import 'dart:math';
import 'package:flutter/material.dart';

// Star class for twinkling stars
class Star {
  final double x;
  final double y;
  final double size;
  final double twinklePhase;
  final double twinkleOffset;
  final double brightness;

  Star({
    required this.x,
    required this.y,
    required this.size,
    required this.twinklePhase,
    required this.twinkleOffset,
    required this.brightness,
  });
}

// Cloud class for drifting clouds
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

// FallingStar class for premium falling stars in dark mode
class FallingStar {
  final double startX;
  final double startY;
  final double endX;
  final double endY;
  final double size;
  final double speed;
  final double tailLength;
  final double brightness;
  final double glowIntensity;
  final double phase;

  FallingStar({
    required this.startX,
    required this.startY,
    required this.endX,
    required this.endY,
    required this.size,
    required this.speed,
    required this.tailLength,
    required this.brightness,
    required this.glowIntensity,
    required this.phase,
  });
}

// Bird class for flying birds in light mode
class Bird {
  final double startX;
  final double startY;
  final double speed;
  final double size;
  final double flightPathHeight;
  final double flightPathFreq;
  final double wingSpeed;
  final double phase;

  Bird({
    required this.startX,
    required this.startY,
    required this.speed,
    required this.size,
    required this.flightPathHeight,
    required this.flightPathFreq,
    required this.wingSpeed,
    required this.phase,
  });
}

class AnimatedSkyBackground extends StatefulWidget {
  final Widget child;
  final bool isDarkMode;

  const AnimatedSkyBackground({
    Key? key,
    required this.child,
    required this.isDarkMode,
  }) : super(key: key);

  @override
  State<AnimatedSkyBackground> createState() => _AnimatedSkyBackgroundState();
}

class _AnimatedSkyBackgroundState extends State<AnimatedSkyBackground>
    with TickerProviderStateMixin {
  late AnimationController _starController;
  late AnimationController _cloudController;
  late AnimationController _twinkleController;
  late AnimationController _fallingStarController;
  late AnimationController _birdController;

  final List<Star> _stars = [];
  final List<Cloud> _clouds = [];
  final List<FallingStar> _fallingStars = [];
  final List<Bird> _birds = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Star animation controller for movement
    _starController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Cloud animation controller for movement
    _cloudController = AnimationController(
      duration: const Duration(seconds: 30),
      vsync: this,
    )..repeat();

    // Twinkle animation controller for star twinkling
    _twinkleController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    // Falling star animation controller with seamless transitions
    _fallingStarController = AnimationController(
      duration: const Duration(seconds: 5), // Total cycle: 3s falling + 2s gap
      vsync: this,
    );

    // Generate new path every cycle
    _fallingStarController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _generateFallingStars(); // Generate completely new random path
      }
    });

    _fallingStarController.repeat(); // Continuous seamless animation

    // Bird animation controller
    _birdController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _generateStars();
    _generateClouds();
    _generateFallingStars();
    _generateBirds();
  }

  void _generateStars() {
    _stars.clear();
    for (int i = 0; i < 300; i++) {
      // Increased from 200 to 500
      _stars.add(
        Star(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          size:
              _random.nextDouble() * 1.9 +
              1.2, // Slightly bigger: 0.4-1.4 (was 0.3-1.1)
          twinklePhase: _random.nextDouble() * 2 * pi,
          twinkleOffset: _random.nextDouble() * 2 * pi,
          brightness:
              _random.nextDouble() * 0.4 + 0.8, // High brightness 0.8-1.2
        ),
      );
    }
  }

  void _generateClouds() {
    _clouds.clear();
    for (int i = 0; i < 8; i++) {
      final x = _random.nextDouble() * 1.5 - 0.25;
      _clouds.add(
        Cloud(
          startX: x,
          x: x, // Start some clouds off-screen
          y: _random.nextDouble() * 0.6 + 0.1,
          size: _random.nextDouble() * 80 + 40,
          speed: _random.nextDouble() * 0.3 + 0.1,
          opacity: _random.nextDouble() * 0.4 + 0.1,
        ),
      );
    }
  }

  void _generateFallingStars() {
    _fallingStars.clear();
    // Generate completely random falling star path each time
    final randomStartX = _random.nextDouble() * 1.4 - 0.2; // Wider range
    final randomEndX = _random.nextDouble() * 1.4 - 0.2; // Wider range
    final randomSize = _random.nextDouble() * 2.0 + 1.5;
    final randomSpeed = _random.nextDouble() * 0.2 + 0.1;

    _fallingStars.add(
      FallingStar(
        startX: randomStartX,
        startY: -0.15,
        endX: randomEndX,
        endY: 1.15,
        size: randomSize,
        speed: randomSpeed,
        tailLength: _random.nextDouble() * 0.15 + 0.1,
        brightness: _random.nextDouble() * 0.3 + 0.7,
        glowIntensity: _random.nextDouble() * 0.4 + 0.6,
        phase: 0.0,
      ),
    );
    print(
      'Generated new falling star: startX=$randomStartX, endX=$randomEndX',
    ); // Debug
  }

  void _generateBirds() {
    _birds.clear();
    for (int i = 0; i < 6; i++) {
      _birds.add(
        Bird(
          startX: -0.1,
          startY: _random.nextDouble() * 0.6 + 0.2,
          speed: _random.nextDouble() * 0.15 + 0.1,
          size: _random.nextDouble() * 0.8 + 0.5,
          flightPathHeight: _random.nextDouble() * 0.08 + 0.02,
          flightPathFreq: _random.nextDouble() * 3 + 2,
          wingSpeed: _random.nextDouble() * 8 + 6,
          phase: _random.nextDouble() * 2 * pi,
        ),
      );
    }
  }

  @override
  void dispose() {
    _starController.dispose();
    _cloudController.dispose();
    _twinkleController.dispose();
    _fallingStarController.dispose();
    _birdController.dispose();
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
              colors: widget.isDarkMode
                  ? [
                      const Color(0xFF0F0F23),
                      const Color(0xFF1A1A2E),
                      const Color(0xFF16213E),
                    ]
                  : [
                      const Color(0xFF87CEEB),
                      const Color(0xFFB0E0E6),
                      const Color(0xFFF0F8FF),
                    ],
            ),
          ),
        ),

        // Animated elements
        if (widget.isDarkMode) ...[
          // Stars for dark mode
          AnimatedBuilder(
            animation: _twinkleController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: StarPainter(_stars, _twinkleController.value),
              );
            },
          ),
          // Falling stars for dark mode
          AnimatedBuilder(
            animation: _fallingStarController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: FallingStarPainter(
                  _fallingStars,
                  _fallingStarController.value,
                ),
              );
            },
          ),
        ] else ...[
          // Clouds for light mode
          AnimatedBuilder(
            animation: _cloudController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: CloudBackgroundPainter(
                  _clouds,
                  _cloudController.value,
                ),
              );
            },
          ),
          // Birds for light mode
          AnimatedBuilder(
            animation: _birdController,
            builder: (context, child) {
              return CustomPaint(
                size: Size.infinite,
                painter: BirdPainter(_birds, _birdController.value),
              );
            },
          ),
        ],

        // Child widget
        widget.child,
      ],
    );
  }
}

class StarPainter extends CustomPainter {
  final List<Star> stars;
  final double animationValue;

  StarPainter(this.stars, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final x = star.x * size.width;
      final y = star.y * size.height;

      // Calculate twinkling effect
      final twinkle =
          sin(animationValue * 2 * pi + star.twinkleOffset) * 0.5 + 0.5;
      final currentBrightness = (star.brightness + twinkle * 0.3).clamp(
        0.0,
        1.0,
      );
      final currentGlow = (star.brightness + twinkle * 0.2).clamp(0.0, 1.0);

      // Draw very subtle 4-spike star shape (tiny and natural)
      final starPath = Path();
      final spikeSize =
          star.size * (1 + twinkle * 0.1); // Minimal size variation

      // Very subtle spikes (barely visible)
      final longSpikeLength = spikeSize * 0.8; // Much smaller spikes
      final shortSpikeLength = spikeSize * 0.6;

      // Create natural subtle 4-spike star shape
      starPath.moveTo(x, y - longSpikeLength); // Top spike
      starPath.lineTo(x + spikeSize * 0.1, y - spikeSize * 0.1);
      starPath.lineTo(x + shortSpikeLength, y); // Right spike
      starPath.lineTo(x + spikeSize * 0.1, y + spikeSize * 0.1);
      starPath.lineTo(x, y + longSpikeLength); // Bottom spike
      starPath.lineTo(x - spikeSize * 0.1, y + spikeSize * 0.1);
      starPath.lineTo(x - shortSpikeLength, y); // Left spike
      starPath.lineTo(x - spikeSize * 0.1, y - spikeSize * 0.1);
      starPath.close();

      // High visibility glow for tiny stars
      final outerGlowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(currentGlow * 0.6); // Much brighter

      canvas.drawPath(starPath, outerGlowPaint);

      // Bright core for visibility
      final corePaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(currentBrightness)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 0.2);

      canvas.drawCircle(Offset(x, y), spikeSize * 0.4, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CloudBackgroundPainter extends CustomPainter {
  final List<Cloud> clouds;
  final double animationValue;

  CloudBackgroundPainter(this.clouds, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (final cloud in clouds) {
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(cloud.opacity);

      // Calculate cloud position with wrapping
      final x = (cloud.x + animationValue * cloud.speed) % 1.3 - 0.3;
      final y = cloud.y;

      final center = Offset(x * size.width, y * size.height);

      // Draw cloud as multiple overlapping circles
      final radius = cloud.size;

      // Main cloud body
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
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class FallingStarPainter extends CustomPainter {
  final List<FallingStar> fallingStars;
  final double animationValue;

  FallingStarPainter(this.fallingStars, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in fallingStars) {
      // Seamless 5-second cycle: 3 seconds falling (0.0-0.6) + 2 seconds gap (0.6-1.0)
      final progress = animationValue % 1.0;
      final fallingProgress = (progress * 5 / 3).clamp(
        0.0,
        1.0,
      ); // Map first 3/5 of cycle to full fall

      // Only show falling star during the falling phase (first 60% of cycle)
      if (progress > 0.6) continue; // Hide during gap period

      // Calculate current position using the mapped falling progress
      final currentX =
          star.startX + (star.endX - star.startX) * fallingProgress;
      final currentY =
          star.startY + (star.endY - star.startY) * fallingProgress;

      // Skip if truly off screen
      if (currentY > 1.2 || currentY < -0.2) continue;

      final x = currentX * size.width;
      final y = currentY * size.height;

      // Calculate tail points with logarithmic decrease
      final tailPoints = <Offset>[];
      final numberOfSegments = 12;

      for (int i = 0; i < numberOfSegments; i++) {
        final segmentProgress = i / numberOfSegments;
        final tailProgress =
            fallingProgress - (star.tailLength * segmentProgress);

        if (tailProgress < 0) continue;

        final tailX = star.startX + (star.endX - star.startX) * tailProgress;
        final tailY = star.startY + (star.endY - star.startY) * tailProgress;

        tailPoints.add(Offset(tailX * size.width, tailY * size.height));
      }

      // Draw luminous tail with logarithmic fade
      for (int i = 0; i < tailPoints.length - 1; i++) {
        final segmentRatio = i / tailPoints.length;

        // Logarithmic opacity decrease for premium look
        final opacity =
            star.brightness *
            (1 - log(1 + segmentRatio * 9) / log(10)) *
            star.glowIntensity;

        // Logarithmic width decrease
        final width =
            star.size * (1 - log(1 + segmentRatio * 4) / log(5)) + 0.5;

        // Create gradient paint for luminous effect with safe width
        final safeWidth = width.clamp(0.1, 10.0); // Ensure valid stroke width
        final paint = Paint()
          ..strokeWidth = safeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        // Premium white luminous color with slight blue tint
        final color = Color.lerp(
          Colors.white.withOpacity(opacity.clamp(0.0, 1.0)),
          const Color(0xFFE6F3FF).withOpacity((opacity * 0.8).clamp(0.0, 1.0)),
          segmentRatio * 0.3,
        )!;

        paint.color = color;

        // Draw tail segment
        if (i < tailPoints.length - 1) {
          canvas.drawLine(tailPoints[i], tailPoints[i + 1], paint);
        }

        // Add glow effect for premium look
        if (segmentRatio < 0.3) {
          // Only glow near the star
          final safeGlowWidth = (safeWidth * 2.5).clamp(0.1, 15.0);
          final glowPaint = Paint()
            ..strokeWidth = safeGlowWidth
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withOpacity((opacity * 0.2).clamp(0.0, 1.0));

          if (i < tailPoints.length - 1) {
            canvas.drawLine(tailPoints[i], tailPoints[i + 1], glowPaint);
          }
        }
      }

      // Calculate twinkling effect for simple glow
      final twinklePhase = (animationValue * 6 + star.phase) % (2 * pi);
      final twinkle = (sin(twinklePhase) * 0.5 + 0.5);
      final currentBrightness = star.brightness * (0.8 + twinkle * 0.4);
      final currentGlow = star.glowIntensity * (0.9 + twinkle * 0.3);

      // Draw simple circular falling star head (not spike)
      final starSize = star.size * (1 + twinkle * 0.2);

      // Draw luminous glow layers for the star head
      final outerGlowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = const Color(0xFFE6F3FF).withOpacity(currentGlow * 0.3);

      canvas.drawCircle(Offset(x, y), starSize * 2.0, outerGlowPaint);

      // Inner glow
      final innerGlowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(currentGlow * 0.5);

      canvas.drawCircle(Offset(x, y), starSize * 1.3, innerGlowPaint);

      // Main star head (simple circle)
      final starPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = Colors.white.withOpacity(currentBrightness.clamp(0.0, 1.0));

      canvas.drawCircle(Offset(x, y), starSize, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class BirdPainter extends CustomPainter {
  final List<Bird> birds;
  final double animationValue;

  BirdPainter(this.birds, this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    for (final bird in birds) {
      final progress = (animationValue + bird.speed + bird.phase) % 1.0;

      // Calculate bird position with natural curved flight path
      final baseX = bird.startX + progress * 1.2; // Fly across screen
      final flightCurve =
          sin(progress * pi * bird.flightPathFreq) * bird.flightPathHeight;
      final currentX = baseX;
      final currentY = bird.startY + flightCurve;

      // Skip if bird is off screen
      if (currentX > 1.1 || currentX < -0.1) continue;

      final x = currentX * size.width;
      final y = currentY * size.height;

      // Calculate wing flapping
      final wingPhase =
          (animationValue * bird.wingSpeed + bird.phase) % (2 * pi);
      final wingFlap = sin(wingPhase);

      canvas.save();
      canvas.translate(x, y);

      // Calculate bird direction (slightly angled based on flight curve)
      final direction = progress < 0.5 ? 1.0 : 1.0; // Always flying right
      final angle = atan2(flightCurve * 0.5, 0.1) * direction;
      canvas.rotate(angle);

      // Scale the bird
      canvas.scale(bird.size);

      // Draw bird body (small oval)
      final bodyPaint = Paint()
        ..color = Colors.black87.withOpacity(0.7)
        ..style = PaintingStyle.fill;

      canvas.drawOval(const Rect.fromLTWH(-3, -1, 6, 2), bodyPaint);

      // Draw wings (V-shape that flaps)
      final wingPaint = Paint()
        ..color = Colors.black87.withOpacity(0.6)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      // Left wing
      final leftWingTip = Offset(-4, -2 + wingFlap * 1.5);
      canvas.drawLine(const Offset(0, 0), leftWingTip, wingPaint);

      // Right wing
      final rightWingTip = Offset(4, -2 + wingFlap * 1.5);
      canvas.drawLine(const Offset(0, 0), rightWingTip, wingPaint);

      // Draw wing curves for more natural look
      final leftWingCurve = Path();
      leftWingCurve.moveTo(0, 0);
      leftWingCurve.quadraticBezierTo(
        -2,
        -1 + wingFlap * 0.8,
        leftWingTip.dx,
        leftWingTip.dy,
      );
      canvas.drawPath(leftWingCurve, wingPaint);

      final rightWingCurve = Path();
      rightWingCurve.moveTo(0, 0);
      rightWingCurve.quadraticBezierTo(
        2,
        -1 + wingFlap * 0.8,
        rightWingTip.dx,
        rightWingTip.dy,
      );
      canvas.drawPath(rightWingCurve, wingPaint);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
