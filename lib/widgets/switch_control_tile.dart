import 'package:flutter/material.dart';
import '../models/switch_model.dart';
import '../models/switch_type.dart';
import 'animated_switch_icon.dart';

class SwitchControlTile extends StatelessWidget {
  final SwitchDevice device;
  final Function(bool) onToggle;
  final Function(SwitchType) onTypeChanged;
  final Function(String) onNameChanged;

  const SwitchControlTile({
    Key? key,
    required this.device,
    required this.onToggle,
    required this.onTypeChanged,
    required this.onNameChanged,
  }) : super(key: key);

  Future<void> _showNameEditDialog(BuildContext context) async {
    final TextEditingController nameController = TextEditingController(
      text: device.name,
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Switch Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Switch Name',
            hintText: 'Enter new name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != device.name) {
                onNameChanged(newName);
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: AnimatedSwitchIcon(
          type: device.type,
          isOn: device.state,
          size: 32,
        ),
        title: GestureDetector(
          onLongPress: () => _showNameEditDialog(context),
          child: Text(device.name),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(value: device.state, onChanged: onToggle),
            PopupMenuButton<SwitchType>(
              icon: const Icon(Icons.more_vert, size: 20),
              itemBuilder: (context) => SwitchType.values
                  .map(
                    (type) => PopupMenuItem<SwitchType>(
                      value: type,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: AnimatedSwitchIcon(
                          type: type,
                          isOn: true,
                          size: 24,
                        ),
                        title: Text(type.name.toUpperCase()),
                      ),
                    ),
                  )
                  .toList(),
              onSelected: (type) => onTypeChanged(type),
            ),
          ],
        ),
      ),
    );
  }
}
