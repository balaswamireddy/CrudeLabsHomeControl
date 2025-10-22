import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/switch_model.dart';
import '../models/switch_type.dart';
import '../widgets/switch_control_tile.dart';
import 'timer_screen.dart';

class SwitchControlScreen extends StatefulWidget {
  final String boardId;
  final String boardName;

  const SwitchControlScreen({
    super.key,
    required this.boardId,
    required this.boardName,
  });

  @override
  State<SwitchControlScreen> createState() => _SwitchControlScreenState();
}

class _SwitchControlScreenState extends State<SwitchControlScreen> {
  final _switches = <SwitchDevice>[];
  final _switchTypes = <String, SwitchType>{}; // Store switch types locally
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _switchChannel;

  @override
  void initState() {
    super.initState();
    _loadSwitches();
    _subscribeToChanges();
  }

  Future<void> _loadSwitches() async {
    try {
      print('Loading switches for board: ${widget.boardId}'); // Debug log

      final response = await _supabase
          .from('switches')
          .select('id, board_id, name, state')
          .eq('board_id', widget.boardId);

      print('Response received: $response'); // Debug log

      if (!mounted) return;

      setState(() {
        _switches.clear();
        final List<dynamic> switchList = response;
        print('Processing ${switchList.length} switches'); // Debug log

        for (final Map<String, dynamic> switchData in switchList) {
          try {
            final id = switchData['id'];
            final boardId = switchData['board_id'];
            final name = switchData['name'];
            final state = switchData['state'];

            print('Processing switch: id=$id, name=$name'); // Debug log

            if (id == null || boardId == null || name == null) {
              print('Missing required fields in switch data: $switchData');
              continue;
            }

            final switchDevice = SwitchDevice(
              id: id,
              boardId: boardId,
              name: name,
              type: SwitchType.light, // Default type
              position: 0,
              state: state ?? false,
            );

            _switches.add(switchDevice);
          } catch (e) {
            print('Error processing switch data: $switchData, error: $e');
          }
        }

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Error loading switches: ${e.toString()}');
      }
    }
  }

  void _subscribeToChanges() {
    _switchChannel = _supabase
        .channel('switch_changes_${widget.boardId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'switches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'board_id',
            value: widget.boardId,
          ),
          callback: (payload) {
            print('Switch change detected: $payload');
            _loadSwitches(); // Reload switches when changes occur
          },
        )
        .subscribe();
  }

  Future<void> _toggleSwitch(SwitchDevice switch_) async {
    final newState = !switch_.state;
    final switchIndex = _switches.indexWhere((s) => s.id == switch_.id);

    if (switchIndex == -1) return;

    // Update locally first for immediate feedback
    setState(() {
      _switches[switchIndex] = switch_.copyWith(state: newState);
    });

    try {
      // Update the database
      await _supabase
          .from('switches')
          .update({'state': newState})
          .eq('id', switch_.id);
    } catch (e) {
      // Revert the state if the update fails
      setState(() {
        _switches[switchIndex] = switch_.copyWith(state: !newState);
      });
      _showError('Error toggling switch: ${e.toString()}');
    }
  }

  void _updateSwitchType(String switchId, SwitchType type) {
    final switchIndex = _switches.indexWhere((s) => s.id == switchId);
    if (switchIndex == -1) return;

    // Update only in local state
    setState(() {
      _switchTypes[switchId] = type;
      _switches[switchIndex] = _switches[switchIndex].copyWith(type: type);
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _switchChannel?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.boardName),
        actions: [
          IconButton(
            icon: const Icon(Icons.timer),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TimerScreen(
                    boardId: widget.boardId,
                    boardName: widget.boardName,
                    switches: _switches,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: _switches.length,
              itemBuilder: (context, index) {
                final switch_ = _switches[index];
                return SwitchControlTile(
                  device: switch_,
                  onToggle: (value) => _toggleSwitch(switch_),
                  onTypeChanged: (type) => _updateSwitchType(switch_.id, type),
                  onNameChanged: (name) => _updateSwitchName(switch_.id, name),
                );
              },
            ),
    );
  }

  Future<void> _updateSwitchName(String switchId, String newName) async {
    final switchIndex = _switches.indexWhere((s) => s.id == switchId);
    if (switchIndex == -1) return;

    // Update locally first
    setState(() {
      _switches[switchIndex] = _switches[switchIndex].copyWith(name: newName);
    });

    try {
      // Update the name in the database
      await _supabase
          .from('switches')
          .update({'name': newName})
          .eq('id', switchId);
    } catch (e) {
      // If database update fails, revert the local change
      if (mounted) {
        setState(() {
          _switches[switchIndex] = _switches[switchIndex].copyWith(
            name: _switches[switchIndex].name,
          );
        });
        _showError('Error updating switch name: ${e.toString()}');
      }
    }
  }
}
