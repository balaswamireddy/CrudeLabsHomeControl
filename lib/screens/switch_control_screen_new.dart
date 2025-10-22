import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/switch_model.dart';
import '../models/switch_type.dart';
import '../widgets/glass_switch_control_tile.dart';
import '../providers/dynamic_theme_provider.dart';
import 'timer_screen.dart';
import '../widgets/dynamic_background_widget.dart';

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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadSwitches();
    _subscribeToChanges();
    _startPeriodicRefresh(); // Add periodic refresh as fallback
  }

  Future<void> _loadSwitches() async {
    try {
      print('Loading switches for board: ${widget.boardId}'); // Debug log

      final response = await _supabase
          .from('switches')
          .select('id, board_id, name, state, position')
          .eq('board_id', widget.boardId)
          .order('position');

      print('Response received: $response'); // Debug log

      if (!mounted) return;

      // Store old states for comparison
      final oldStates = <String, bool>{};
      for (final switch_ in _switches) {
        oldStates[switch_.id] = switch_.state;
      }

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
            final position = switchData['position'] ?? 0;

            print(
              'Processing switch: id=$id, name=$name, state=$state',
            ); // Debug log

            if (id == null || boardId == null || name == null) {
              print('Missing required fields in switch data: $switchData');
              continue;
            }

            // Check if state changed
            final oldState = oldStates[id];
            if (oldState != null && oldState != state) {
              print('🔄 State change detected for $name: $oldState → $state');
            }

            final switchDevice = SwitchDevice(
              id: id,
              boardId: boardId,
              name: name,
              type: SwitchType.light, // Default type
              position: position,
              state: state ?? false,
            );

            _switches.add(switchDevice);
          } catch (e) {
            print('Error processing switch data: $switchData, error: $e');
          }
        }

        // Sort switches by position
        _switches.sort((a, b) => a.position.compareTo(b.position));
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading switches: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Error loading switches: ${e.toString()}');
      }
    }
  }

  void _subscribeToChanges() {
    print('Setting up real-time subscription for board: ${widget.boardId}');

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
            print('Real-time switch change detected: $payload');
            if (mounted) {
              _loadSwitches(); // Reload switches when changes occur
            }
          },
        )
        .subscribe((status, [error]) {
          print('Subscription status: $status, error: $error');
        });
  }

  void _startPeriodicRefresh() {
    // Refresh every 1 second as fallback for real-time updates (faster to match ESP32 polling)
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        print('Periodic refresh triggered (1s)');
        _loadSwitches();
      }
    });
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

  void _updateSwitchType(String switchId, SwitchType type) {
    final switchIndex = _switches.indexWhere((s) => s.id == switchId);
    if (switchIndex == -1) return;

    // Update both local map and switch object
    setState(() {
      _switchTypes[switchId] = type;
      _switches[switchIndex] = _switches[switchIndex].copyWith(type: type);
    });
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
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DynamicThemeProvider>(
      builder: (context, themeProvider, child) {
        final isBasicTheme = themeProvider.backgroundType == 'basic';

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              widget.boardName,
              style: TextStyle(
                color: isBasicTheme ? null : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: isBasicTheme ? null : Colors.white),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.timer,
                  color: isBasicTheme ? null : Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DynamicBackgroundWidget(
                        child: TimerScreen(
                          boardId: widget.boardId,
                          boardName: widget.boardName,
                          switches: _switches,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isBasicTheme
                          ? Theme.of(context).primaryColor
                          : Colors.white,
                    ),
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
      },
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
