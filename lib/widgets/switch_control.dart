import 'package:flutter/material.dart';

class SwitchControl extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SwitchControl({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(value: value, onChanged: onChanged);
  }
}
