import 'package:flutter/material.dart';
import 'dart:math' as math;

enum ArrowPosition {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  top,
  bottom,
  left,
  right,
}

class ArrowTutorialWidget extends StatefulWidget {
  final GlobalKey targetKey;
  final String message;
  final ArrowPosition position;
  final VoidCallback onDismiss;
  final Color color;
  final Duration duration;

  const ArrowTutorialWidget({
    super.key,
    required this.targetKey,
    required this.message,
    required this.position,
    required this.onDismiss,
    this.color = Colors.blue,
    this.duration = const Duration(seconds: 5),
  });

  @override
  State<ArrowTutorialWidget> createState() => _ArrowTutorialWidgetState();
}

class _ArrowTutorialWidgetState extends State<ArrowTutorialWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_animationController, _pulseController]),
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                // Semi-transparent background that can be tapped to dismiss
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black.withOpacity(0.1),
                  ),
                ),
                // Arrow and message
                _buildArrowAndMessage(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildArrowAndMessage() {
    final targetRenderBox =
        widget.targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (targetRenderBox == null) return const SizedBox();

    final targetPosition = targetRenderBox.localToGlobal(Offset.zero);
    final targetSize = targetRenderBox.size;
    final targetCenter = Offset(
      targetPosition.dx + targetSize.width / 2,
      targetPosition.dy + targetSize.height / 2,
    );

    // Calculate message position based on arrow position
    late Offset messagePosition;
    late Offset arrowStart;
    late Offset arrowEnd;

    switch (widget.position) {
      case ArrowPosition.topLeft:
        messagePosition = Offset(
          targetPosition.dx - 180,
          targetPosition.dy - 100,
        );
        arrowStart = Offset(messagePosition.dx + 160, messagePosition.dy + 60);
        arrowEnd = Offset(targetPosition.dx + 10, targetPosition.dy + 10);
        break;
      case ArrowPosition.topRight:
        messagePosition = Offset(
          targetPosition.dx + targetSize.width + 20,
          targetPosition.dy - 100,
        );
        arrowStart = Offset(messagePosition.dx, messagePosition.dy + 60);
        arrowEnd = Offset(
          targetPosition.dx + targetSize.width - 10,
          targetPosition.dy + 10,
        );
        break;
      case ArrowPosition.bottomLeft:
        messagePosition = Offset(
          targetPosition.dx - 180,
          targetPosition.dy + targetSize.height + 20,
        );
        arrowStart = Offset(messagePosition.dx + 160, messagePosition.dy + 20);
        arrowEnd = Offset(
          targetPosition.dx + 10,
          targetPosition.dy + targetSize.height - 10,
        );
        break;
      case ArrowPosition.bottomRight:
        messagePosition = Offset(
          targetPosition.dx + targetSize.width + 20,
          targetPosition.dy + targetSize.height + 20,
        );
        arrowStart = Offset(messagePosition.dx, messagePosition.dy + 20);
        arrowEnd = Offset(
          targetPosition.dx + targetSize.width - 10,
          targetPosition.dy + targetSize.height - 10,
        );
        break;
      case ArrowPosition.top:
        messagePosition = Offset(
          targetCenter.dx - 100,
          targetPosition.dy - 120,
        );
        arrowStart = Offset(messagePosition.dx + 100, messagePosition.dy + 80);
        arrowEnd = Offset(targetCenter.dx, targetPosition.dy);
        break;
      case ArrowPosition.bottom:
        messagePosition = Offset(
          targetCenter.dx - 100,
          targetPosition.dy + targetSize.height + 40,
        );
        arrowStart = Offset(messagePosition.dx + 100, messagePosition.dy);
        arrowEnd = Offset(
          targetCenter.dx,
          targetPosition.dy + targetSize.height,
        );
        break;
      case ArrowPosition.left:
        messagePosition = Offset(targetPosition.dx - 220, targetCenter.dy - 40);
        arrowStart = Offset(messagePosition.dx + 200, messagePosition.dy + 40);
        arrowEnd = Offset(targetPosition.dx, targetCenter.dy);
        break;
      case ArrowPosition.right:
        messagePosition = Offset(
          targetPosition.dx + targetSize.width + 20,
          targetCenter.dy - 40,
        );
        arrowStart = Offset(messagePosition.dx, messagePosition.dy + 40);
        arrowEnd = Offset(
          targetPosition.dx + targetSize.width,
          targetCenter.dy,
        );
        break;
    }

    // Ensure message stays within screen bounds
    final screenSize = MediaQuery.of(context).size;
    messagePosition = Offset(
      messagePosition.dx.clamp(20.0, screenSize.width - 220),
      messagePosition.dy.clamp(20.0, screenSize.height - 120),
    );

    return Stack(
      children: [
        // Target highlight
        Positioned(
          left: targetPosition.dx - 10,
          top: targetPosition.dy - 10,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            child: Container(
              width: targetSize.width + 20,
              height: targetSize.height + 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.color.withOpacity(0.8),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: child,
              );
            },
          ),
        ),

        // Arrow
        CustomPaint(
          painter: ArrowPainter(
            start: arrowStart,
            end: arrowEnd,
            color: widget.color,
          ),
          child: Container(),
        ),

        // Message bubble
        Positioned(
          left: messagePosition.dx,
          top: messagePosition.dy,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                padding: const EdgeInsets.all(16),
                constraints: const BoxConstraints(maxWidth: 200),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        GestureDetector(
                          onTap: widget.onDismiss,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Got it!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ArrowPainter extends CustomPainter {
  final Offset start;
  final Offset end;
  final Color color;

  ArrowPainter({required this.start, required this.end, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw the arrow line
    canvas.drawLine(start, end, paint);

    // Calculate arrow head
    final arrowDirection = (end - start).direction;
    final arrowHead1 = Offset(
      end.dx - 15 * math.cos(arrowDirection - 0.5),
      end.dy - 15 * math.sin(arrowDirection - 0.5),
    );
    final arrowHead2 = Offset(
      end.dx - 15 * math.cos(arrowDirection + 0.5),
      end.dy - 15 * math.sin(arrowDirection + 0.5),
    );

    // Draw arrow head
    canvas.drawLine(end, arrowHead1, paint);
    canvas.drawLine(end, arrowHead2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
