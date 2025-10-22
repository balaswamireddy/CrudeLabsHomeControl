import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/switch_model.dart';
import '../models/switch_type.dart';
import '../widgets/glass_switch_control_tile.dart';
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
    _loadSwitchTypes().then((_) {
      _loadSwitches();
      _subscribeToChanges();
    });
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

            // Apply stored switch type if it exists
            final storedType = _switchTypes[id];
            final finalSwitchDevice = storedType != null
                ? switchDevice.copyWith(type: storedType)
                : switchDevice;

            _switches.add(finalSwitchDevice);
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
            // Only reload if it's an INSERT or DELETE, not UPDATE
            // This prevents losing switch types when toggles happen
            if (payload.eventType == PostgresChangeEvent.insert ||
                payload.eventType == PostgresChangeEvent.delete) {
              _loadSwitches();
            } else if (payload.eventType == PostgresChangeEvent.update) {
              // For updates, just update the specific switch state
              _handleSwitchUpdate(payload);
            }
          },
        )
        .subscribe();
  }

  Future<void> _toggleSwitch(SwitchDevice switch_) async {
    final newState = !switch_.state;
    final switchIndex = _switches.indexWhere((s) => s.id == switch_.id);

    if (switchIndex == -1) return;

    // Preserve the locally stored switch type if it exists
    final currentType = _switchTypes[switch_.id] ?? switch_.type;

    // Update locally first for immediate feedback
    setState(() {
      _switches[switchIndex] = switch_.copyWith(
        state: newState,
        type: currentType, // Preserve the current type
      );
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
        _switches[switchIndex] = switch_.copyWith(
          state: !newState,
          type: currentType, // Preserve the current type even when reverting
        );
      });
      _showError('Error toggling switch: ${e.toString()}');
    }
  }

  // Handle individual switch updates without full reload
  void _handleSwitchUpdate(PostgresChangePayload payload) {
    final switchData = payload.newRecord;
    final switchId = switchData['id'];
    final newState = switchData['state'] ?? false;

    final switchIndex = _switches.indexWhere((s) => s.id == switchId);
    if (switchIndex != -1) {
      setState(() {
        final currentSwitch = _switches[switchIndex];
        // Preserve the locally stored type
        final preservedType = _switchTypes[switchId] ?? currentSwitch.type;
        _switches[switchIndex] = currentSwitch.copyWith(
          state: newState,
          type: preservedType,
        );
      });
    }
  }

  // Load switch types from SharedPreferences using JSON
  Future<void> _loadSwitchTypes() async {
    final prefs = await SharedPreferences.getInstance();
    final storedTypesJson = prefs.getString('switch_types_${widget.boardId}');

    if (storedTypesJson != null) {
      try {
        final Map<String, dynamic> typesMap = jsonDecode(storedTypesJson);

        _switchTypes.clear();
        typesMap.forEach((switchId, typeString) {
          final type = SwitchType.values.firstWhere(
            (t) => t.name == typeString,
            orElse: () => SwitchType.light,
          );
          _switchTypes[switchId] = type;
        });
        print('Loaded switch types: $_switchTypes'); // Debug log
      } catch (e) {
        print('Error loading switch types: $e');
        await prefs.remove('switch_types_${widget.boardId}');
      }
    }
  }

  // Save switch types to SharedPreferences using JSON
  Future<void> _saveSwitchTypes() async {
    final prefs = await SharedPreferences.getInstance();

    // Convert the map to JSON format
    final typesMap = <String, String>{};
    _switchTypes.forEach((switchId, type) {
      typesMap[switchId] = type.name;
    });

    final typesJson = jsonEncode(typesMap);
    await prefs.setString('switch_types_${widget.boardId}', typesJson);
    print('Saved switch types: $typesMap'); // Debug log
  }

  void _updateSwitchType(String switchId, SwitchType type) {
    final switchIndex = _switches.indexWhere((s) => s.id == switchId);
    if (switchIndex == -1) return;

    print('Updating switch $switchId type to ${type.name}'); // Debug log

    // Update both local map and switch object
    setState(() {
      _switchTypes[switchId] = type;
      _switches[switchIndex] = _switches[switchIndex].copyWith(type: type);
    });

    // Save to local storage
    _saveSwitchTypes();
  }

  SwitchDevice _getCurrentSwitch(String switchId) {
    final switch_ = _switches.firstWhere((s) => s.id == switchId);
    final localType = _switchTypes[switchId];

    // Return the switch with the locally stored type if it exists
    if (localType != null && localType != switch_.type) {
      return switch_.copyWith(type: localType);
    }
    return switch_;
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          widget.boardName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
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
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : SafeArea(
              child: GridView.builder(
                padding: const EdgeInsets.only(
                  top: 16,
                  bottom: 120, // Increased from 100 to 120 pixels
                  left: 16,
                  right: 16,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio:
                      1.1, // Slightly taller than square to better accommodate content
                ),
                itemCount: _switches.length,
                itemBuilder: (context, index) {
                  final switch_ = _switches[index];
                  final currentSwitch = _getCurrentSwitch(switch_.id);
                  return GlassSwitchControlTile(
                    device: currentSwitch,
                    onToggle: (value) => _toggleSwitch(currentSwitch),
                    onTypeChanged: (type) =>
                        _updateSwitchType(switch_.id, type),
                    onNameChanged: (name) =>
                        _updateSwitchName(switch_.id, name),
                  );
                },
              ),
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
