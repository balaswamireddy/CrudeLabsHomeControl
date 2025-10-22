import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class SnowflakeParticle {
  late double x;
  late double y;
  late double size;
  late double speed;
  late double wind;
  late double rotation;
  late double rotationSpeed;
  late double opacity;
  late int type; // 0: simple circle, 1: star shape, 2: complex crystal

  SnowflakeParticle({
    required double screenWidth,
    required double screenHeight,
    bool fromTop = true,
  }) {
    final random = Random();

    x = random.nextDouble() * screenWidth;
    y = fromTop ? -20 : random.nextDouble() * screenHeight;
    size = 2 + random.nextDouble() * 6; // Size between 2-8
    speed = 0.5 + random.nextDouble() * 2; // Speed between 0.5-2.5
    wind = (random.nextDouble() - 0.5) * 0.5; // Side drift
    rotation = random.nextDouble() * 2 * pi;
    rotationSpeed = (random.nextDouble() - 0.5) * 0.02;
    opacity = 0.3 + random.nextDouble() * 0.7; // Opacity between 0.3-1.0
    type = random.nextInt(3);
  }

  void update(double screenWidth, double screenHeight) {
    y += speed;
    x += wind;
    rotation += rotationSpeed;

    // Add some floating motion
    x += sin(y * 0.01) * 0.3;

    // Reset particle when it goes off screen
    if (y > screenHeight + 20) {
      y = -20;
      x = Random().nextDouble() * screenWidth;
    }

    if (x > screenWidth + 10) {
      x = -10;
    } else if (x < -10) {
      x = screenWidth + 10;
    }
  }
}

class SnowAnimationWidget extends StatefulWidget {
  final Widget child;
  final bool isSnowing;
  final int particleCount;

  const SnowAnimationWidget({
    Key? key,
    required this.child,
    this.isSnowing = true,
    this.particleCount = 50,
  }) : super(key: key);

  @override
  State<SnowAnimationWidget> createState() => _SnowAnimationWidgetState();
}

class _SnowAnimationWidgetState extends State<SnowAnimationWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  Timer? _updateTimer;
  List<SnowflakeParticle> _snowflakes = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
  }

  void _initializeSnowflakes(Size size) {
    if (_initialized) return;
    _snowflakes = List.generate(
      widget.particleCount,
      (index) => SnowflakeParticle(
        screenWidth: size.width,
        screenHeight: size.height,
        fromTop: false, // Start randomly positioned for initial load
      ),
    );
    _initialized = true;
  }

  void _startAnimation(Size size) {
    _animationController.repeat();

    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted || !widget.isSnowing) return;

      setState(() {
        for (final snowflake in _snowflakes) {
          snowflake.update(size.width, size.height);
        }
      });
    });
  }

  void _stopAnimation() {
    _animationController.stop();
    _updateTimer?.cancel();
  }

  @override
  void didUpdateWidget(SnowAnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isSnowing != oldWidget.isSnowing) {
      if (!widget.isSnowing) {
        _stopAnimation();
        _snowflakes.clear();
        _initialized = false;
      }
    }

    if (widget.particleCount != oldWidget.particleCount && widget.isSnowing) {
      _snowflakes.clear();
      _initialized = false;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // Initialize snowflakes if needed
        if (!_initialized &&
            widget.isSnowing &&
            size.width > 0 &&
            size.height > 0) {
          _initializeSnowflakes(size);
          _startAnimation(size);
        }

        return Stack(
          children: [
            // Background gradient for snowy atmosphere
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE3F2FD), // Light blue
                    Color(0xFFF5F5F5), // Light gray
                    Color(0xFFFFFFFF), // White
                  ],
                ),
              ),
            ),

            // Main content
            widget.child,

            // Snow particles
            if (widget.isSnowing && _initialized)
              CustomPaint(
                painter: SnowPainter(snowflakes: _snowflakes),
                size: Size.infinite,
              ),
          ],
        );
      },
    );
  }
}

class SnowPainter extends CustomPainter {
  final List<SnowflakeParticle> snowflakes;

  SnowPainter({required this.snowflakes});

  @override
  void paint(Canvas canvas, Size size) {
    for (final snowflake in snowflakes) {
      _drawSnowflake(canvas, snowflake);
    }
  }

  void _drawSnowflake(Canvas canvas, SnowflakeParticle snowflake) {
    canvas.save();
    canvas.translate(snowflake.x, snowflake.y);
    canvas.rotate(snowflake.rotation);

    final paint = Paint()
      ..color = Colors.white.withOpacity(snowflake.opacity)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white.withOpacity(snowflake.opacity * 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    switch (snowflake.type) {
      case 0: // Simple circle
        canvas.drawCircle(Offset.zero, snowflake.size / 2, paint);
        break;

      case 1: // Star shape
        _drawStar(canvas, snowflake.size, paint, strokePaint);
        break;

      case 2: // Complex crystal
        _drawCrystal(canvas, snowflake.size, strokePaint);
        break;
    }

    canvas.restore();
  }

  void _drawStar(
    Canvas canvas,
    double size,
    Paint fillPaint,
    Paint strokePaint,
  ) {
    final path = Path();
    final radius = size / 2;
    final innerRadius = radius * 0.4;

    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * pi / 180;

      final outerX = cos(angle) * radius;
      final outerY = sin(angle) * radius;
      final innerX = cos(angle + pi / 6) * innerRadius;
      final innerY = sin(angle + pi / 6) * innerRadius;

      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  void _drawCrystal(Canvas canvas, double size, Paint strokePaint) {
    final radius = size / 2;

    // Draw main cross
    canvas.drawLine(Offset(-radius, 0), Offset(radius, 0), strokePaint);
    canvas.drawLine(Offset(0, -radius), Offset(0, radius), strokePaint);

    // Draw diagonal lines
    final diagonalRadius = radius * 0.7;
    canvas.drawLine(
      Offset(-diagonalRadius, -diagonalRadius),
      Offset(diagonalRadius, diagonalRadius),
      strokePaint,
    );
    canvas.drawLine(
      Offset(-diagonalRadius, diagonalRadius),
      Offset(diagonalRadius, -diagonalRadius),
      strokePaint,
    );

    // Add small branches
    final branchSize = radius * 0.3;
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * pi / 180;
      final mainX = cos(angle) * radius;
      final mainY = sin(angle) * radius;

      final branchAngle1 = angle + pi / 4;
      final branchAngle2 = angle - pi / 4;

      final branch1X = mainX + cos(branchAngle1) * branchSize;
      final branch1Y = mainY + sin(branchAngle1) * branchSize;
      final branch2X = mainX + cos(branchAngle2) * branchSize;
      final branch2Y = mainY + sin(branchAngle2) * branchSize;

      canvas.drawLine(
        Offset(mainX, mainY),
        Offset(branch1X, branch1Y),
        strokePaint,
      );
      canvas.drawLine(
        Offset(mainX, mainY),
        Offset(branch2X, branch2Y),
        strokePaint,
      );
    }
  }

  @override
  bool shouldRepaint(SnowPainter oldDelegate) {
    return oldDelegate.snowflakes != snowflakes;
  }
}
