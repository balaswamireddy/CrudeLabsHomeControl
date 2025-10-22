import 'package:flutter/material.dart';

class AnimatedSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final double width;
  final double height;

  const AnimatedSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.width = 60.0,
    this.height = 35.0,
  });

  @override
  State<AnimatedSwitch> createState() => _AnimatedSwitchState();
}

class _AnimatedSwitchState extends State<AnimatedSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _setupAnimations();

    if (widget.value) {
      _controller.value = 1.0;
    }
  }

  void _setupAnimations() {
    final activeColor =
        widget.activeColor ?? Theme.of(context).colorScheme.primary;
    final inactiveColor =
        widget.inactiveColor ?? Theme.of(context).colorScheme.surfaceVariant;

    _colorAnimation = ColorTween(
      begin: inactiveColor,
      end: activeColor,
    ).animate(_animation);
  }

  @override
  void didUpdateWidget(AnimatedSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (widget.onChanged != null) {
          widget.onChanged!(!widget.value);
        }
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Container(
            width: widget.width,
            height: widget.height,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.height),
              color: _colorAnimation.value?.withOpacity(0.5),
              boxShadow: [
                BoxShadow(
                  color:
                      _colorAnimation.value?.withOpacity(0.3) ??
                      Colors.transparent,
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: _animation.value * (widget.width - widget.height + 4),
                  child: Container(
                    width: widget.height - 8,
                    height: widget.height - 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        widget.value
                            ? Icons.lightbulb
                            : Icons.lightbulb_outline,
                        size: widget.height * 0.5,
                        color: _colorAnimation.value,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
