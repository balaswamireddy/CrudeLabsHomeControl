import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

class LightningEffectsWidget extends StatefulWidget {
  final Widget child;
  final bool isThunderstorm;

  const LightningEffectsWidget({
    Key? key,
    required this.child,
    this.isThunderstorm = true,
  }) : super(key: key);

  @override
  State<LightningEffectsWidget> createState() => _LightningEffectsWidgetState();
}

class _LightningEffectsWidgetState extends State<LightningEffectsWidget>
    with TickerProviderStateMixin {
  late AnimationController _lightningController;
  late AnimationController _flashController;
  late AnimationController _backgroundController;

  late Animation<double> _lightningOpacity;
  late Animation<double> _flashOpacity;
  late Animation<double> _backgroundFlash;

  Timer? _lightningTimer;
  bool _isLightningActive = false;
  final Random _random = Random();

  // Lightning bolt paths for different effects
  final List<List<Offset>> _lightningPaths = [];

  @override
  void initState() {
    super.initState();

    _lightningController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _lightningOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _lightningController, curve: Curves.easeInOut),
    );

    _flashOpacity = Tween<double>(begin: 0.0, end: 0.8).animate(
      CurvedAnimation(parent: _flashController, curve: Curves.easeInOut),
    );

    _backgroundFlash = Tween<double>(begin: 0.0, end: 0.3).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.easeInOut),
    );

    if (widget.isThunderstorm) {
      _startLightningShow();
    }

    _generateLightningPaths();
  }

  void _generateLightningPaths() {
    _lightningPaths.clear();

    // Generate multiple lightning bolt paths
    for (int i = 0; i < 3; i++) {
      _lightningPaths.add(_generateLightningBolt());
    }
  }

  List<Offset> _generateLightningBolt() {
    final List<Offset> path = [];

    // Use reasonable default dimensions if context isn't available
    final width = 400.0;
    final height = 800.0;

    // Start from top of screen
    double x = width * (0.2 + _random.nextDouble() * 0.6);
    double y = 0;

    path.add(Offset(x, y));

    // Generate zigzag path downward
    while (y < height * 0.8) {
      // Add some randomness to create realistic lightning
      x += (_random.nextDouble() - 0.5) * 100;
      y += 50 + _random.nextDouble() * 100;

      // Keep within screen bounds
      x = x.clamp(20, width - 20);

      path.add(Offset(x, y));
    }

    return path;
  }

  void _startLightningShow() {
    _lightningTimer?.cancel();
    _lightningTimer = Timer.periodic(
      Duration(seconds: 3 + _random.nextInt(7)), // Random interval 3-10 seconds
      (timer) => _triggerLightning(),
    );
  }

  void _triggerLightning() {
    if (!mounted || !widget.isThunderstorm) return;

    setState(() {
      _isLightningActive = true;
      _generateLightningPaths(); // Generate new paths for variety
    });

    // Lightning flash sequence
    _lightningController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          _lightningController.reverse();
        }
      });
    });

    // Screen flash effect
    _flashController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _flashController.reverse();
        }
      });
    });

    // Background illumination
    _backgroundController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) {
          _backgroundController.reverse().then((_) {
            setState(() {
              _isLightningActive = false;
            });
          });
        }
      });
    });

    // Sometimes trigger multiple flashes
    if (_random.nextBool()) {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted && widget.isThunderstorm) {
          _triggerQuickFlash();
        }
      });
    }
  }

  void _triggerQuickFlash() {
    _flashController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) {
          _flashController.reverse();
        }
      });
    });
  }

  @override
  void didUpdateWidget(LightningEffectsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isThunderstorm != oldWidget.isThunderstorm) {
      if (widget.isThunderstorm) {
        _startLightningShow();
      } else {
        _lightningTimer?.cancel();
        _lightningController.reset();
        _flashController.reset();
        _backgroundController.reset();
        setState(() {
          _isLightningActive = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _lightningTimer?.cancel();
    _lightningController.dispose();
    _flashController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background flash effect
        AnimatedBuilder(
          animation: _backgroundFlash,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_backgroundFlash.value),
              ),
            );
          },
        ),

        // Main content
        widget.child,

        // Lightning bolts
        if (_isLightningActive)
          AnimatedBuilder(
            animation: _lightningOpacity,
            builder: (context, child) {
              return CustomPaint(
                painter: LightningPainter(
                  paths: _lightningPaths,
                  opacity: _lightningOpacity.value,
                ),
                size: Size.infinite,
              );
            },
          ),

        // Screen flash overlay
        AnimatedBuilder(
          animation: _flashOpacity,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(_flashOpacity.value),
              ),
            );
          },
        ),
      ],
    );
  }
}

class LightningPainter extends CustomPainter {
  final List<List<Offset>> paths;
  final double opacity;

  LightningPainter({required this.paths, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;

    for (final path in paths) {
      _drawLightningBolt(canvas, path);
    }
  }

  void _drawLightningBolt(Canvas canvas, List<Offset> points) {
    if (points.length < 2) return;

    // Main lightning bolt (bright white)
    final mainPaint = Paint()
      ..color = Colors.white.withOpacity(opacity)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

    // Glow effect (outer)
    final glowPaint = Paint()
      ..color = Colors.blue.withOpacity(opacity * 0.5)
      ..strokeWidth = 12.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);

    // Inner glow (electric blue)
    final innerGlowPaint = Paint()
      ..color = Colors.lightBlueAccent.withOpacity(opacity * 0.7)
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Draw layers from outer to inner for proper glow effect
    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, innerGlowPaint);
    canvas.drawPath(path, mainPaint);

    // Add branch effects
    _drawLightningBranches(canvas, points);
  }

  void _drawLightningBranches(Canvas canvas, List<Offset> mainPath) {
    final branchPaint = Paint()
      ..color = Colors.white.withOpacity(opacity * 0.6)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    final random = Random();

    // Add some branches at random points
    for (int i = 1; i < mainPath.length - 1; i++) {
      if (random.nextDouble() < 0.3) {
        // 30% chance of branch
        final point = mainPath[i];
        final branchEnd = Offset(
          point.dx + (random.nextDouble() - 0.5) * 60,
          point.dy + random.nextDouble() * 40,
        );

        canvas.drawLine(point, branchEnd, branchPaint);
      }
    }
  }

  @override
  bool shouldRepaint(LightningPainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.paths != paths;
  }
}
