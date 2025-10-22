import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../models/switch_type.dart';

class AnimatedSwitchIcon extends StatefulWidget {
  final SwitchType type;
  final bool isOn;
  final double size;

  const AnimatedSwitchIcon({
    Key? key,
    required this.type,
    required this.isOn,
    this.size = 24.0,
  }) : super(key: key);

  @override
  State<AnimatedSwitchIcon> createState() => _AnimatedSwitchIconState();
}

class _AnimatedSwitchIconState extends State<AnimatedSwitchIcon>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();

    // Rotation animation for fans, motors, pumps
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    // Pulse animation for AC, heater, speaker
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Bounce animation for TV, door, window
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    _startAppropriateAnimation();
  }

  void _startAppropriateAnimation() {
    if (widget.isOn) {
      switch (widget.type) {
        case SwitchType.fan:
        case SwitchType.motor:
        case SwitchType.pump:
          _rotationController.repeat();
          break;
        case SwitchType.ac:
        case SwitchType.heater:
        case SwitchType.speaker:
          _pulseController.repeat(reverse: true);
          break;
        case SwitchType.tv:
        case SwitchType.door:
        case SwitchType.window:
          _bounceController.repeat(reverse: true);
          break;
        default:
          break;
      }
    }
  }

  void _stopAllAnimations() {
    _rotationController.stop();
    _pulseController.stop();
    _bounceController.stop();
  }

  @override
  void didUpdateWidget(AnimatedSwitchIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOn != oldWidget.isOn) {
      if (widget.isOn) {
        _startAppropriateAnimation();
      } else {
        _stopAllAnimations();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  Widget _buildAnimatedIcon() {
    final IconData iconData = _getIconData();
    final Color iconColor = _getIconColor();

    switch (widget.type) {
      // Rotating icons
      case SwitchType.fan:
      case SwitchType.motor:
      case SwitchType.pump:
        return RotationTransition(
          turns: _rotationController,
          child: _buildIcon(iconData, iconColor),
        );

      // Pulsing icons
      case SwitchType.ac:
      case SwitchType.heater:
      case SwitchType.speaker:
        return AnimatedBuilder(
          animation: _pulseAnimation,
          child: _buildIcon(iconData, iconColor),
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isOn ? _pulseAnimation.value : 1.0,
              child: child,
            );
          },
        );

      // Bouncing icons
      case SwitchType.tv:
      case SwitchType.door:
      case SwitchType.window:
        return AnimatedBuilder(
          animation: _bounceAnimation,
          child: _buildIcon(iconData, iconColor),
          builder: (context, child) {
            return Transform.scale(
              scale: widget.isOn ? _bounceAnimation.value : 1.0,
              child: child,
            );
          },
        );

      // Special glowing light
      case SwitchType.light:
        return _buildGlowingLight();

      // Sliding curtain
      case SwitchType.curtain:
        return _buildSlidingCurtain();

      // Simple plug
      case SwitchType.plug:
        return _buildIcon(iconData, iconColor);
    }
  }

  Widget _buildIcon(IconData iconData, Color color) {
    return Icon(iconData, size: widget.size, color: color);
  }

  Widget _buildGlowingLight() {
    return SizedBox(
      width: widget.size * 1.8,
      height: widget.size * 1.8,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isOn)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.yellow.withOpacity(0.1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.yellow.withOpacity(0.3),
                      blurRadius: widget.size / 2,
                      spreadRadius: widget.size / 4,
                    ),
                  ],
                ),
              ),
            ),
          Center(
            child: Icon(
              Icons.lightbulb,
              size: widget.size,
              color: widget.isOn ? Colors.yellow : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlidingCurtain() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.window, size: widget.size, color: Colors.grey[400]),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            left: widget.isOn ? widget.size * 0.6 : 0,
            child: Icon(
              Icons.curtains,
              size: widget.size * 0.8,
              color: widget.isOn ? Colors.deepPurple : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData() {
    switch (widget.type) {
      case SwitchType.light:
        return Icons.lightbulb;
      case SwitchType.fan:
        return FontAwesomeIcons.fan;
      case SwitchType.ac:
        return Icons.ac_unit;
      case SwitchType.heater:
        return Icons.whatshot;
      case SwitchType.tv:
        return Icons.tv;
      case SwitchType.speaker:
        return Icons.speaker;
      case SwitchType.plug:
        return Icons.electrical_services;
      case SwitchType.motor:
        return Icons.precision_manufacturing;
      case SwitchType.pump:
        return Icons.water_drop;
      case SwitchType.door:
        return Icons.door_front_door;
      case SwitchType.window:
        return Icons.window;
      case SwitchType.curtain:
        return Icons.curtains;
    }
  }

  Color _getIconColor() {
    if (!widget.isOn) return Colors.grey;

    switch (widget.type) {
      case SwitchType.light:
        return Colors.yellow;
      case SwitchType.fan:
        return Colors.blue;
      case SwitchType.ac:
        return Colors.cyan;
      case SwitchType.heater:
        return Colors.orange;
      case SwitchType.tv:
        return Colors.purple;
      case SwitchType.speaker:
        return Colors.green;
      case SwitchType.plug:
        return Colors.red;
      case SwitchType.motor:
        return Colors.indigo;
      case SwitchType.pump:
        return Colors.teal;
      case SwitchType.door:
        return Colors.brown;
      case SwitchType.window:
        return Colors.lightBlue;
      case SwitchType.curtain:
        return Colors.deepPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildAnimatedIcon();
  }
}
