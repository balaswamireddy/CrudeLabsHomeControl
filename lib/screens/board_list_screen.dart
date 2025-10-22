import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/board_model.dart';
import '../services/streamlined_database_service.dart';
import 'switch_control_screen.dart';
import '../widgets/animated_sky_background.dart';
import '../providers/dynamic_theme_provider.dart';

class BoardListScreen extends StatefulWidget {
  final String homeId;

  const BoardListScreen({super.key, required this.homeId});

  @override
  State<BoardListScreen> createState() => _BoardListScreenState();
}

class _BoardListScreenState extends State<BoardListScreen> {
  final _boards = <Board>[];
  bool _isLoading = true;
  bool _isScanning = false;
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();
  List<WiFiAccessPoint> _accessPoints = [];

  @override
  void initState() {
    super.initState();
    _loadBoards();
  }

  Future<void> _loadBoards() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _showError('User not authenticated');
        return;
      }

      // Load boards from the specific home where user is owner or member
      final response = await _supabase
          .from('boards')
          .select('*, switches(*)')
          .eq('home_id', widget.homeId)
          .eq('is_active', true);

      setState(() {
        _boards.clear();
        _boards.addAll(
          (response as List).map((board) => Board.fromJson(board)),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error loading boards: ${e.toString()}');
    }
  }

  Future<void> _scanForDevices() async {
    setState(() {
      _isScanning = true;
    });

    try {
      // Check location permission first
      final locationPermission = await Permission.location.status;
      if (!locationPermission.isGranted) {
        final result = await Permission.location.request();
        if (!result.isGranted) {
          throw Exception("Location permission required for WiFi scanning");
        }
      }

      // Request permission for location (required for WiFi scanning)
      final can = await WiFiScan.instance.canStartScan();
      if (can != CanStartScan.yes) {
        throw Exception("WiFi scanning not available. Try manual board entry.");
      }

      // Start scan
      final result = await WiFiScan.instance.startScan();
      if (result != true) {
        throw Exception("Failed to start WiFi scan. Try manual board entry.");
      }

      // Wait a bit for scan to complete
      await Future.delayed(const Duration(seconds: 3));

      // Get scan results
      final results = await WiFiScan.instance.getScannedResults();

      setState(() {
        _accessPoints = results
            .where(
              (ap) =>
                  ap.ssid.startsWith('SmartSwitch_') ||
                  ap.ssid.startsWith('ESP32-'),
            ) // Filter for SmartSwitch devices
            .toList();
      });

      if (_accessPoints.isEmpty) {
        _showError(
          'No SmartSwitch devices found. Make sure your ESP32 is in configuration mode (hold config button for 3 seconds) and try again, or add manually.',
        );
      } else {
        _showDeviceSelectionDialog();
      }
    } catch (e) {
      _showError(
        'WiFi scan failed: ${e.toString()}\n\nYou can still add boards manually using the "Add Manual Board" option.',
      );
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  void _showDeviceSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select ESP32 Device'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _accessPoints.length,
            itemBuilder: (context, index) {
              final ap = _accessPoints[index];
              return ListTile(
                title: Text(ap.ssid),
                subtitle: Text('Signal Strength: ${ap.level} dBm'),
                onTap: () {
                  Navigator.pop(context);
                  _showBoardNameDialog(ap.ssid);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showBoardNameDialog(String deviceId) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name Your Board'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Board Name',
            hintText: 'Enter a name for this board',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                _addBoard(name, deviceId);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addBoard(String name, String deviceId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _showError('User not authenticated');
        return;
      }

      final boardId = _uuid.v4();
      await _supabase.from('boards').insert({
        'id': boardId,
        'home_id': widget.homeId,
        'owner_id': userId,
        'name': name,
        'mac_address': deviceId,
        'status': 'offline',
        'is_active': true,
      });

      // Initialize 4 switches for the board
      for (var i = 0; i < 4; i++) {
        await _supabase.from('switches').insert({
          'id': _uuid.v4(),
          'board_id': boardId,
          'name': 'Switch ${i + 1}',
          'type': 'light',
          'position': i,
          'state': false,
          'is_enabled': true,
        });
      }

      _loadBoards();
    } catch (e) {
      _showError('Error adding board: ${e.toString()}');
    }
  }

  Future<void> _renameBoard(Board board) async {
    final nameController = TextEditingController(text: board.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Board'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Board Name',
            hintText: 'Enter new name for the board',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = nameController.text.trim();
              if (newName.isNotEmpty && newName != board.name) {
                try {
                  await _supabase
                      .from('boards')
                      .update({'name': newName})
                      .eq('id', board.id);

                  Navigator.pop(context);
                  _loadBoards();

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Board renamed to "$newName"'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  _showError('Error renaming board: ${e.toString()}');
                }
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBoard(Board board) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Board'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to delete "${board.name}"?'),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone. All switches associated with this board will also be deleted.',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                // First delete all switches for this board
                await _supabase
                    .from('switches')
                    .delete()
                    .eq('board_id', board.id);

                // Then delete the board
                await _supabase.from('boards').delete().eq('id', board.id);

                Navigator.pop(context);
                _loadBoards();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Board "${board.name}" deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                _showError('Error deleting board: ${e.toString()}');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _showShareDialog(Board board) async {
    try {
      // Generate a unique referral code for this home
      final referralCode = _uuid.v4().substring(0, 8).toUpperCase();
      final userId = _supabase.auth.currentUser?.id;

      if (userId == null) {
        _showError('User not authenticated');
        return;
      }

      // Store the referral code in the database
      await _supabase.from('home_shares').upsert({
        'home_id': widget.homeId,
        'owner_id': userId,
        'referral_code': referralCode,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now()
            .add(const Duration(days: 7))
            .toIso8601String(),
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Share Home Access'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Share this referral code with others to give them access to your home:',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        referralCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: referralCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Referral code copied to clipboard'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This code will expire in 7 days. People with this code can add your home to their account and control your devices.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                _showJoinHomeDialog();
                Navigator.pop(context);
              },
              child: const Text('Join Another Home'),
            ),
          ],
        ),
      );
    } catch (e) {
      _showError('Error generating share code: ${e.toString()}');
    }
  }

  Future<void> _showJoinHomeDialog() async {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Home'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the referral code shared with you:'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Referral Code',
                hintText: 'Enter 8-character code',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 8,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim().toUpperCase();
              if (code.length == 8) {
                await _joinHomeWithCode(code);
                Navigator.pop(context);
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }

  Future<void> _joinHomeWithCode(String referralCode) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        _showError('User not authenticated');
        return;
      }

      // Check if the referral code exists and is valid
      final shareResponse = await _supabase
          .from('home_shares')
          .select('home_id, owner_id, expires_at')
          .eq('referral_code', referralCode)
          .eq('is_active', true)
          .maybeSingle();

      if (shareResponse == null) {
        _showError('Invalid or expired referral code');
        return;
      }

      final expiresAt = DateTime.parse(shareResponse['expires_at']);
      if (expiresAt.isBefore(DateTime.now())) {
        _showError('This referral code has expired');
        return;
      }

      final homeId = shareResponse['home_id'];

      // Check if user is already a member of this home
      final existingMember = await _supabase
          .from('home_members')
          .select('id')
          .eq('home_id', homeId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existingMember != null) {
        _showError('You are already a member of this home');
        return;
      }

      // Add user as a member of the home
      await _supabase.from('home_members').insert({
        'id': _uuid.v4(),
        'home_id': homeId,
        'user_id': userId,
        'role': 'member',
        'joined_at': DateTime.now().toIso8601String(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Successfully joined home! You can now access shared devices.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      // Reload the boards to show newly accessible ones
      _loadBoards();
    } catch (e) {
      _showError('Error joining home: ${e.toString()}');
    }
  }

  void _showManualBoardDialog() {
    final boardIdController = TextEditingController();
    final nameController = TextEditingController();
    bool isChecking = false;
    Map<String, dynamic>? boardInfo;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Board Manually'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the Board ID from your ESP32 device:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: boardIdController,
                decoration: const InputDecoration(
                  labelText: 'Board ID',
                  hintText: 'e.g., BOARD_001',
                  prefixIcon: Icon(Icons.developer_board),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
                onChanged: (value) {
                  // Clear previous board info when typing
                  if (boardInfo != null) {
                    setState(() {
                      boardInfo = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: isChecking
                    ? null
                    : () async {
                        final boardId = boardIdController.text.trim();
                        if (boardId.isEmpty) return;

                        setState(() {
                          isChecking = true;
                          boardInfo = null;
                        });

                        try {
                          final dbService = StreamlinedDatabaseService();
                          final info = await dbService.checkBoardAvailability(
                            boardId,
                          );

                          setState(() {
                            boardInfo = info;
                            isChecking = false;
                          });

                          // Auto-populate name if board is available
                          if (info['available'] == true &&
                              nameController.text.isEmpty) {
                            nameController.text = info['board_name'] ?? boardId;
                          }
                        } catch (e) {
                          setState(() {
                            isChecking = false;
                            boardInfo = {
                              'exists': false,
                              'available': false,
                              'message': 'Error: ${e.toString()}',
                            };
                          });
                        }
                      },
                icon: isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(isChecking ? 'Checking...' : 'Check Availability'),
              ),
              const SizedBox(height: 12),
              if (boardInfo != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: boardInfo!['available'] == true
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: boardInfo!['available'] == true
                          ? Colors.green
                          : Colors.orange,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            boardInfo!['available'] == true
                                ? Icons.check_circle
                                : boardInfo!['exists'] == true
                                ? Icons.warning
                                : Icons.error,
                            color: boardInfo!['available'] == true
                                ? Colors.green
                                : Colors.orange,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              boardInfo!['message'],
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: boardInfo!['available'] == true
                                    ? Colors.green.shade900
                                    : Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (boardInfo!['exists'] == true) ...[
                        const SizedBox(height: 8),
                        Text(
                          'MAC: ${boardInfo!['mac_address'] ?? 'N/A'}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        if (boardInfo!['last_online'] != null)
                          Text(
                            'Last Online: ${_formatTimestamp(boardInfo!['last_online'])}',
                            style: const TextStyle(fontSize: 11),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (boardInfo?['available'] == true) ...[
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Board Name (Optional)',
                    hintText: 'Give your board a custom name',
                    prefixIcon: Icon(Icons.edit),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (boardInfo?['available'] == true)
              ElevatedButton.icon(
                onPressed: () async {
                  final boardId = boardIdController.text.trim();
                  final customName = nameController.text.trim();

                  if (boardId.isNotEmpty) {
                    Navigator.pop(context);
                    await _claimBoard(boardId, customName);
                  }
                },
                icon: const Icon(Icons.add_circle),
                label: const Text('Add Board'),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> _claimBoard(String boardId, String? customName) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Claiming board...'),
            ],
          ),
        ),
      );

      final dbService = StreamlinedDatabaseService();
      final claimedBoard = await dbService.validateAndClaimBoard(
        boardId: boardId,
        homeId: widget.homeId,
        customName: customName,
      );

      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Board "${claimedBoard['name']}" successfully added! 🎉',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Reload boards to show the newly claimed board
      _loadBoards();
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      _showError('Failed to add board: ${e.toString()}');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Boards')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _boards.isEmpty
          ? Center(
              child: Text(
                'No boards added yet',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            )
          : ListView.builder(
              itemCount: _boards.length,
              itemBuilder: (context, index) {
                final board = _boards[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: board.status == BoardStatus.online
                          ? Colors.green
                          : board.status == BoardStatus.offline
                          ? Colors.red
                          : Colors.orange,
                      child: const Icon(
                        Icons.developer_board,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(board.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (board.macAddress != null)
                          Text('MAC: ${board.macAddress}'),
                        Text('Status: ${board.status.name.toUpperCase()}'),
                        Text('Switches: ${board.switches.length}'),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) {
                        switch (action) {
                          case 'rename':
                            _renameBoard(board);
                            break;
                          case 'delete':
                            _deleteBoard(board);
                            break;
                          case 'share':
                            _showShareDialog(board);
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'rename',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Rename'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'share',
                          child: Row(
                            children: [
                              Icon(Icons.share, size: 20),
                              SizedBox(width: 8),
                              Text('Share Home'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Consumer<DynamicThemeProvider>(
                            builder: (context, themeProvider, child) =>
                                AnimatedSkyBackground(
                                  isDarkMode: themeProvider.isDarkMode,
                                  child: SwitchControlScreen(
                                    boardId: board.id,
                                    boardName: board.name,
                                  ),
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'join',
            onPressed: _showJoinHomeDialog,
            backgroundColor: Colors.blue,
            child: const Icon(Icons.group_add),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.extended(
                heroTag: 'manual',
                onPressed: _showManualBoardDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text('Add Manual'),
              ),
              const SizedBox(width: 16),
              FloatingActionButton.extended(
                heroTag: 'scan',
                onPressed: _isScanning ? null : _scanForDevices,
                icon: _isScanning
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.wifi_find),
                label: const Text('Scan WiFi'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
