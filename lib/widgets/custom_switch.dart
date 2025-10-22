import 'package:flutter/material.dart';

class CustomSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color? activeColor;
  final double width;
  final double height;

  const CustomSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.activeColor,
    this.width = 60.0,
    this.height = 35.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Transform.scale(
        scale: width / 60.0, // Scale based on width
        child: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor ?? Theme.of(context).colorScheme.primary,
          thumbIcon: MaterialStateProperty.resolveWith((states) {
            if (states.contains(MaterialState.selected)) {
              return const Icon(Icons.power_settings_new, size: 16);
            }
            return const Icon(Icons.power_settings_new_outlined, size: 16);
          }),
        ),
      ),
    );
  }
}
