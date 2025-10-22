import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/switch_model.dart';
import '../models/switch_type.dart';
import '../widgets/animated_switch_icon.dart';
import '../widgets/glass_widgets.dart';

class GlassSwitchControlTile extends StatelessWidget {
  final SwitchDevice device;
  final Function(bool) onToggle;
  final Function(SwitchType) onTypeChanged;
  final Function(String) onNameChanged;

  const GlassSwitchControlTile({
    Key? key,
    required this.device,
    required this.onToggle,
    required this.onTypeChanged,
    required this.onNameChanged,
  }) : super(key: key);

  Color _getTypeColor() {
    switch (device.type) {
      case SwitchType.light:
        return Colors.amber;
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

  List<Color> _getGradientColors() {
    final baseColor = _getTypeColor();
    return [baseColor.withOpacity(0.8), baseColor.withOpacity(0.6)];
  }

  Future<void> _showNameEditDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController(
      text: device.name,
    );

    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Edit Switch Name',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Switch Name',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                    hintText: 'Enter new name',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: GlassButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GlassButton(
                        onPressed: () {
                          final newName = nameController.text.trim();
                          if (newName.isNotEmpty && newName != device.name) {
                            onNameChanged(newName);
                          }
                          Navigator.pop(context);
                        },
                        gradientColors: _getGradientColors(),
                        child: const Text(
                          'Save',
                          style: TextStyle(color: Colors.white),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12), // Reduced from 16 to 12
      customShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
        if (device.state)
          BoxShadow(
            color: _getTypeColor().withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
      ],
      onTap: () {
        HapticFeedback.lightImpact();
        onToggle(!device.state);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top row with icon and menu button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icon with glow effect - reduced size
              Container(
                width: 40, // Reduced from 50 to 40
                height: 40, // Reduced from 50 to 40
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: device.state
                        ? _getGradientColors()
                        : [
                            Colors.grey.withOpacity(0.3),
                            Colors.grey.withOpacity(0.1),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    if (device.state)
                      BoxShadow(
                        color: _getTypeColor().withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitchIcon(
                    type: device.type,
                    isOn: device.state,
                    size: 20, // Reduced from 24 to 20
                  ),
                ),
              ),
              // Type selector button
              GlassButton(
                padding: const EdgeInsets.all(4), // Reduced from 6 to 4
                child: Icon(
                  Icons.more_vert,
                  color: Colors.white.withOpacity(0.8),
                  size: 16, // Reduced from 18 to 16
                ),
                onPressed: () => _showTypeSelector(context),
              ),
            ],
          ),

          const SizedBox(height: 8), // Reduced from 12 to 8
          // Switch name and type
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onLongPress: () => _showNameEditDialog(context),
                child: Text(
                  device.name,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    // Changed from titleMedium to titleSmall
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2), // Reduced from 4 to 2
              Text(
                device.type.name.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.7),
                  letterSpacing: 1.0,
                  fontSize: 8, // Reduced from 10 to 8
                ),
              ),
            ],
          ),

          const SizedBox(height: 8), // Reduced from 12 to 8
          // Bottom row with status and toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status indicator - smaller
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ), // Reduced padding
                decoration: BoxDecoration(
                  color: device.state
                      ? _getTypeColor().withOpacity(0.2)
                      : Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(
                    8,
                  ), // Reduced from 10 to 8
                  border: Border.all(
                    color: device.state
                        ? _getTypeColor().withOpacity(0.4)
                        : Colors.grey.withOpacity(0.4),
                  ),
                ),
                child: Text(
                  device.state ? 'ON' : 'OFF',
                  style: TextStyle(
                    color: device.state ? _getTypeColor() : Colors.grey,
                    fontSize: 8, // Reduced from 9 to 8
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Glass toggle switch - smaller
              GlassToggleSwitch(
                value: device.state,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  onToggle(value);
                },
                activeColors: _getGradientColors(),
                width: 40, // Reduced from 50 to 40
                height: 20, // Reduced from 25 to 20
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showTypeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.3),
      isScrollControlled: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          margin: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Switch Type',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),

                // Scrollable list of switch types
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: SwitchType.values.map((type) {
                        final isSelected = type == device.type;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: GlassButton(
                            onPressed: () {
                              onTypeChanged(type);
                              Navigator.pop(context);
                            },
                            gradientColors: isSelected
                                ? _getGradientColors()
                                : null,
                            child: Row(
                              children: [
                                AnimatedSwitchIcon(
                                  key: ValueKey('selector_${type.name}'),
                                  type: type,
                                  isOn: true,
                                  size: 24,
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  type.name.toUpperCase(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
