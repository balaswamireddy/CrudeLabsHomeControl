import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/switch_model.dart';
import '../models/switch_type.dart';
import '../models/timer_model.dart';

class TimerScreen extends StatefulWidget {
  final String boardId;
  final String boardName;
  final List<SwitchDevice> switches;

  const TimerScreen({
    Key? key,
    required this.boardId,
    required this.boardName,
    required this.switches,
  }) : super(key: key);

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  final _supabase = Supabase.instance.client;
  List<SwitchTimer> _timers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTimers();
  }

  Future<void> _loadTimers() async {
    try {
      final switchIds = widget.switches.map((s) => s.id).toList();
      if (switchIds.isEmpty) {
        setState(() {
          _timers = [];
          _isLoading = false;
        });
        return;
      }

      final response = await _supabase
          .from('timers')
          .select('*')
          .inFilter('switch_id', switchIds);

      if (!mounted) return;

      setState(() {
        _timers = List<Map<String, dynamic>>.from(
          response,
        ).map((data) => SwitchTimer.fromJson(data)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error loading timers: ${e.toString()}');
      }
    }
  }

  Future<void> _showAddTimerDialog() async {
    TimeOfDay selectedTime = TimeOfDay.now();
    SwitchDevice? selectedSwitch;
    bool turnOn = true;
    bool isTimerEnabled = true;
    TimerType timerType = TimerType.scheduled;
    List<String> selectedDays = [];
    DateTime? scheduledDate;
    int countdownMinutes = 30;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Timer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<TimerType>(
                  value: timerType,
                  decoration: const InputDecoration(labelText: 'Timer Type'),
                  items: TimerType.values
                      .map(
                        (type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.name.toUpperCase()),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    timerType = value!;
                    if (value == TimerType.prescheduled) {
                      scheduledDate = DateTime.now().add(
                        const Duration(days: 1),
                      );
                    }
                  }),
                ),
                const SizedBox(height: 16),
                if (timerType == TimerType.scheduled) ...[
                  ListTile(
                    title: const Text('Time'),
                    trailing: TextButton(
                      child: Text(selectedTime.format(context)),
                      onPressed: () async {
                        final TimeOfDay? time = await showTimePicker(
                          context: context,
                          initialTime: selectedTime,
                        );
                        if (time != null) {
                          setState(() => selectedTime = time);
                        }
                      },
                    ),
                  ),
                  const Divider(),
                  const Text('Select Days:', style: TextStyle(fontSize: 16)),
                  Wrap(
                    spacing: 8,
                    children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                        .map(
                          (day) => FilterChip(
                            label: Text(day),
                            selected: selectedDays.contains(day),
                            onSelected: (selected) => setState(() {
                              if (selected) {
                                selectedDays.add(day);
                              } else {
                                selectedDays.remove(day);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
                ] else if (timerType == TimerType.prescheduled) ...[
                  ListTile(
                    title: const Text('Date and Time'),
                    trailing: TextButton(
                      child: Text(
                        scheduledDate != null
                            ? '${scheduledDate!.day}/${scheduledDate!.month} ${selectedTime.format(context)}'
                            : 'Select',
                      ),
                      onPressed: () async {
                        final DateTime? date = await showDatePicker(
                          context: context,
                          initialDate:
                              scheduledDate ??
                              DateTime.now().add(const Duration(days: 1)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 365),
                          ),
                        );
                        if (date != null) {
                          setState(() => scheduledDate = date);
                          final TimeOfDay? time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) {
                            setState(() => selectedTime = time);
                          }
                        }
                      },
                    ),
                  ),
                ] else if (timerType == TimerType.countdown) ...[
                  ListTile(
                    title: const Text('Duration (minutes)'),
                    trailing: SizedBox(
                      width: 100,
                      child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Minutes'),
                        onChanged: (value) {
                          final minutes = int.tryParse(value);
                          if (minutes != null && minutes > 0) {
                            setState(() => countdownMinutes = minutes);
                          }
                        },
                        controller: TextEditingController(
                          text: countdownMinutes.toString(),
                        ),
                      ),
                    ),
                  ),
                ],
                const Divider(),
                SwitchListTile(
                  title: const Text('Timer State'),
                  subtitle: const Text('Enable or disable this timer'),
                  value: isTimerEnabled,
                  onChanged: (value) => setState(() => isTimerEnabled = value),
                ),
                const Divider(),
                const Text('Select Switch:'),
                ...widget.switches.map(
                  (switch_) => RadioListTile<SwitchDevice>(
                    title: Text(switch_.name),
                    value: switch_,
                    groupValue: selectedSwitch,
                    onChanged: (SwitchDevice? value) {
                      setState(() => selectedSwitch = value);
                    },
                  ),
                ),
                const Divider(),
                SwitchListTile(
                  title: const Text('Action'),
                  subtitle: Text(turnOn ? 'Turn ON' : 'Turn OFF'),
                  value: turnOn,
                  onChanged: (value) => setState(() => turnOn = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedSwitch == null
                  ? null
                  : () async {
                      try {
                        // Validate required data
                        if (timerType == TimerType.prescheduled &&
                            scheduledDate == null) {
                          throw Exception(
                            'Scheduled date is required for pre-scheduled timers',
                          );
                        }
                        if (timerType == TimerType.scheduled &&
                            selectedDays.isEmpty) {
                          throw Exception(
                            'At least one day must be selected for scheduled timers',
                          );
                        }

                        final String time;
                        if (timerType == TimerType.countdown) {
                          time = countdownMinutes.toString();
                        } else {
                          time =
                              '${selectedTime.hour.toString().padLeft(2, '0')}:${selectedTime.minute.toString().padLeft(2, '0')}';
                        }

                        final timerData = {
                          'id': const Uuid().v4(),
                          'switch_id': selectedSwitch!.id,
                          'user_id': _supabase
                              .auth
                              .currentUser!
                              .id, // Add this required field
                          'name': 'Timer for ${selectedSwitch!.name}',
                          'is_enabled': isTimerEnabled,
                          'time': time,
                          'days': timerType == TimerType.scheduled
                              ? selectedDays
                              : [],
                          'state': turnOn,
                          'type': timerType.name.toLowerCase(),
                          'scheduled_date': timerType == TimerType.prescheduled
                              ? DateTime(
                                  scheduledDate!.year,
                                  scheduledDate!.month,
                                  scheduledDate!.day,
                                  selectedTime.hour,
                                  selectedTime.minute,
                                ).toUtc().toIso8601String()
                              : null,
                          'created_at': DateTime.now()
                              .toUtc()
                              .toIso8601String(),
                          'updated_at': DateTime.now()
                              .toUtc()
                              .toIso8601String(),
                        };

                        await _supabase.from('timers').insert(timerData);

                        if (!mounted) return;
                        Navigator.pop(context);
                        _loadTimers();
                        _showMessage('Timer created successfully!');
                      } catch (e) {
                        _showError('Error creating timer: ${e.toString()}');
                      }
                    },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTimer(SwitchTimer timer) async {
    final newState = !timer.isEnabled;
    final timerIndex = _timers.indexWhere((t) => t.id == timer.id);

    if (timerIndex == -1) return;

    setState(() {
      _timers[timerIndex] = timer.copyWith(isEnabled: newState);
    });

    try {
      await _supabase
          .from('timers')
          .update({
            'is_enabled': newState,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', timer.id);
    } catch (e) {
      if (mounted) {
        setState(() {
          _timers[timerIndex] = timer.copyWith(isEnabled: !newState);
        });
        _showError('Error updating timer: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteTimer(SwitchTimer timer) async {
    try {
      await _supabase.from('timers').delete().eq('id', timer.id);
      _loadTimers();
      _showMessage('Timer deleted successfully!');
    } catch (e) {
      _showError('Error deleting timer: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  String _getSwitchName(String switchId) {
    final switch_ = widget.switches.firstWhere(
      (s) => s.id == switchId,
      orElse: () => SwitchDevice(
        id: '',
        boardId: '',
        name: 'Unknown Switch',
        state: false,
        type: SwitchType.light,
        position: 0,
      ),
    );
    return switch_.name;
  }

  String _formatTimerTitle(SwitchTimer timer) {
    final switchName = _getSwitchName(timer.switchId);
    switch (timer.type) {
      case TimerType.scheduled:
        return '$switchName - ${timer.time}';
      case TimerType.prescheduled:
        if (timer.scheduledDate != null) {
          return '$switchName - ${timer.scheduledDate!.day}/${timer.scheduledDate!.month} ${timer.time}';
        }
        return '$switchName - ${timer.time}';
      case TimerType.countdown:
        return '$switchName - ${timer.time} min countdown';
    }
  }

  String _formatTimerSubtitle(SwitchTimer timer) {
    final action = timer.state ? 'Turn ON' : 'Turn OFF';
    switch (timer.type) {
      case TimerType.scheduled:
        return '$action on ${timer.days.join(', ')}';
      case TimerType.prescheduled:
        return '$action once';
      case TimerType.countdown:
        return '$action after countdown';
    }
  }

  IconData _getTimerIcon(TimerType type) {
    switch (type) {
      case TimerType.scheduled:
        return Icons.schedule;
      case TimerType.prescheduled:
        return Icons.event;
      case TimerType.countdown:
        return Icons.timer;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.boardName} Timers'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTimers),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _timers.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.timer_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No timers configured',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to add a timer',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _timers.length,
              itemBuilder: (context, index) {
                final timer = _timers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(_getTimerIcon(timer.type)),
                        title: Text(_formatTimerTitle(timer)),
                        subtitle: Text(_formatTimerSubtitle(timer)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: timer.isEnabled,
                              onChanged: (value) => _toggleTimer(timer),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'delete') {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Timer'),
                                      content: const Text(
                                        'Are you sure you want to delete this timer?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _deleteTimer(timer);
                                          },
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              timer.isEnabled
                                  ? Icons.check_circle
                                  : Icons.pause_circle,
                              size: 16,
                              color: timer.isEnabled
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timer.isEnabled ? 'Active' : 'Disabled',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: timer.isEnabled
                                        ? Colors.green
                                        : Colors.grey,
                                  ),
                            ),
                            const Spacer(),
                            Text(
                              timer.type.name.toUpperCase(),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTimerDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
