import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/board_model.dart';
import 'switch_control_screen_new.dart';
import '../widgets/dynamic_background_widget.dart';
import '../providers/dynamic_theme_provider.dart';
import '../services/streamlined_database_service.dart';

class BoardListScreen extends StatefulWidget {
  final String homeId;
  final String? roomId;
  final String? roomName;

  const BoardListScreen({
    super.key,
    required this.homeId,
    this.roomId,
    this.roomName,
  });

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

      print(
        'Loading boards for homeId: ${widget.homeId}, roomId: ${widget.roomId}',
      );

      // Build query based on whether we're filtering by room or showing all boards in home
      var query = _supabase
          .from('boards')
          .select('*, switches(*)')
          .eq('home_id', widget.homeId)
          .eq('is_active', true);

      // Filter by room if roomId is provided, otherwise show unassigned boards
      if (widget.roomId != null) {
        query = query.eq('room_id', widget.roomId!);
        print('Filtering by room_id: ${widget.roomId}');
      } else {
        // Show boards that are not assigned to any room (room_id is null)
        query = query.isFilter('room_id', null);
        print('Filtering for unassigned boards (room_id is null)');
      }

      final response = await query;
      print('Query response: ${response.length} boards found');

      for (var board in response) {
        print(
          'Board: ${board['id']}, home_id: ${board['home_id']}, room_id: ${board['room_id']}',
        );
      }

      setState(() {
        _boards.clear();
        _boards.addAll(
          (response as List).map((board) => Board.fromJson(board)),
        );
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading boards: $e');
      _showError('Error loading boards: ${e.toString()}');
    }
  }

  Future<void> _scanWiFiDevices() async {
    setState(() {
      _isScanning = true;
    });

    try {
      // Check if WiFi is enabled
      print('=== WiFi Scan Diagnostics ===');

      // Check location permission first
      final locationPermission = await Permission.location.status;
      print('Location permission status: $locationPermission');

      if (!locationPermission.isGranted) {
        print('Requesting location permission...');
        final result = await Permission.location.request();
        print('Location permission result: $result');
        if (!result.isGranted) {
          throw Exception(
            "Location permission is required for WiFi scanning on Android. Please enable location permission in app settings.",
          );
        }
      }

      // Check nearby WiFi devices permission (Android 13+)
      try {
        if (await Permission.nearbyWifiDevices.isDenied) {
          final result = await Permission.nearbyWifiDevices.request();
          if (!result.isGranted) {
            print(
              'Nearby WiFi devices permission denied, continuing anyway...',
            );
          }
        }
      } catch (e) {
        // Permission might not be available on older Android versions
        print('Nearby WiFi devices permission not available: $e');
      }

      // Check if we can start scanning
      print('Checking if WiFi scan can be started...');
      final can = await WiFiScan.instance.canStartScan();
      print('Can start scan result: $can');

      if (can != CanStartScan.yes) {
        String errorMsg = "WiFi scanning not available.";
        switch (can) {
          case CanStartScan.notSupported:
            errorMsg = "WiFi scanning not supported on this device.";
            break;
          case CanStartScan.noLocationPermissionRequired:
            errorMsg = "Location permission is required for WiFi scanning.";
            break;
          case CanStartScan.noLocationPermissionDenied:
            errorMsg =
                "Location permission denied. Please enable in app settings.";
            break;
          case CanStartScan.noLocationServiceDisabled:
            errorMsg =
                "Location services are disabled. Please enable location services in device settings.";
            break;
          default:
            errorMsg = "WiFi scanning not available: $can";
        }
        throw Exception("$errorMsg\n\nTry manual board entry instead.");
      }

      // Start scan
      print('Starting WiFi scan...');
      final result = await WiFiScan.instance.startScan();
      print('Scan start result: $result');

      if (result != true) {
        throw Exception(
          "Failed to start WiFi scan. This may be due to:\n• System restrictions\n• WiFi not enabled\n• Location services disabled\n\nTry manual board entry.",
        );
      }

      // Wait for scan to complete
      print('Waiting for scan to complete...');
      await Future.delayed(const Duration(seconds: 4));

      // Get scan results
      print('Getting scan results...');
      final results = await WiFiScan.instance.getScannedResults();
      print('Found ${results.length} total WiFi networks');

      // Debug: Print first few SSIDs
      for (int i = 0; i < results.length && i < 5; i++) {
        final ap = results[i];
        print('Network $i: "${ap.ssid}" (${ap.bssid})');
      }

      setState(() {
        _accessPoints = results
            .where(
              (ap) =>
                  ap.ssid.isNotEmpty &&
                  (ap.ssid.startsWith('SmartSwitch_') ||
                      ap.ssid.startsWith('ESP32-') ||
                      ap.ssid.startsWith('ESP32_') ||
                      ap.ssid.toLowerCase().contains('smartswitch')),
            )
            .toList();
      });

      print('Filtered SmartSwitch devices: ${_accessPoints.length}');
      for (var ap in _accessPoints) {
        print('SmartSwitch device: ${ap.ssid}');
      }

      if (_accessPoints.isEmpty) {
        _showError(
          'No SmartSwitch devices found in WiFi scan.\n\n'
          'Troubleshooting steps:\n'
          '• ESP32 board is powered on\n'
          '• ESP32 is in config mode (hold config button 3+ seconds)\n'
          '• You are within 10 meters of the device\n'
          '• WiFi is enabled on your phone\n'
          '• Location services are enabled\n'
          '• Try restarting the ESP32 board\n\n'
          'Found ${results.length} total networks. You can add boards manually using "Add Manual Board".',
        );
      } else {
        _showDeviceSelectionDialog();
      }
    } catch (e) {
      print('WiFi scan error: $e');
      _showError(
        'WiFi scan failed: ${e.toString()}\n\n'
        'Common solutions:\n'
        '• Enable location services in device settings\n'
        '• Grant location permission to this app in device settings\n'
        '• Make sure WiFi is enabled\n'
        '• Restart the app and try again\n'
        '• Move closer to the ESP32 device\n\n'
        'You can still add boards manually using "Add Manual Board".',
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
        'room_id': widget.roomId, // Assign to current room, null if unassigned
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Board Name',
                hintText: 'Enter a name for this board',
                prefixIcon: Icon(Icons.label),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final boardId = boardIdController.text.trim().toUpperCase();
              final name = nameController.text.trim();
              if (boardId.isNotEmpty && name.isNotEmpty) {
                Navigator.pop(context);
                _claimBoard(boardId, name);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _claimBoard(String boardId, String? customName) async {
    try {
      print(
        'Claiming board: $boardId for homeId: ${widget.homeId}, roomId: ${widget.roomId}',
      );

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
              Text('Adding board...'),
            ],
          ),
        ),
      );

      final dbService = StreamlinedDatabaseService();
      final claimedBoard = await dbService.validateAndClaimBoard(
        boardId: boardId,
        homeId: widget.homeId,
        roomId: widget.roomId,
        customName: customName,
      );

      print('Board claimed successfully: ${claimedBoard['id']}');
      print(
        'Board home_id: ${claimedBoard['home_id']}, room_id: ${claimedBoard['room_id']}',
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

      // Reload boards to show the newly added board
      print('Reloading boards...');
      _loadBoards();
    } catch (e) {
      Navigator.pop(context); // Close loading dialog

      print('Error claiming board: $e');
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
    return Consumer<DynamicThemeProvider>(
      builder: (context, themeProvider, child) {
        final isBasicTheme = themeProvider.backgroundType == 'basic';
        final isDark = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor:
              Colors.transparent, // Allow parent's background to show through
          appBar: AppBar(
            title: Text(
              widget.roomName ?? 'Unassigned Boards',
              style: TextStyle(
                color: isBasicTheme ? null : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: IconThemeData(color: isBasicTheme ? null : Colors.white),
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
              : _boards.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.developer_board_off,
                        size: 64,
                        color: isBasicTheme
                            ? (isDark ? Colors.white70 : Colors.black54)
                            : Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No boards added yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isBasicTheme
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Scan WiFi or add manually to get started',
                        style: TextStyle(
                          color: isBasicTheme
                              ? (isDark ? Colors.white70 : Colors.black54)
                              : Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _boards.length,
                  itemBuilder: (context, index) {
                    final board = _boards[index];
                    return Hero(
                      tag: 'board-${board.id}',
                      child: Card(
                        elevation: 8,
                        shadowColor: Colors.black.withOpacity(0.3),
                        clipBehavior: Clip.hardEdge,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [
                                      Colors.grey[800]!.withOpacity(0.9),
                                      Colors.grey[900]!.withOpacity(0.9),
                                    ]
                                  : [
                                      Colors.white.withOpacity(0.9),
                                      Colors.grey[100]!.withOpacity(0.9),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (context, animation, secondaryAnimation) {
                                        return DynamicBackgroundWidget(
                                          child: SwitchControlScreen(
                                            boardId: board.id,
                                            boardName: board.name,
                                          ),
                                        );
                                      },
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  // Top row with menu button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.grey[800]!.withOpacity(
                                                  0.5,
                                                )
                                              : Colors.grey[200]!.withOpacity(
                                                  0.5,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: PopupMenuButton<String>(
                                          icon: Icon(
                                            Icons.more_vert,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
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
                                                  Icon(
                                                    Icons.delete,
                                                    size: 20,
                                                    color: Colors.red,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Center icon with status indicator
                                  Expanded(
                                    child: Center(
                                      child: Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors:
                                                board.status ==
                                                    BoardStatus.online
                                                ? [
                                                    Colors.green[600]!,
                                                    Colors.green[800]!,
                                                  ]
                                                : board.status ==
                                                      BoardStatus.offline
                                                ? [
                                                    Colors.red[600]!,
                                                    Colors.red[800]!,
                                                  ]
                                                : [
                                                    Colors.orange[600]!,
                                                    Colors.orange[800]!,
                                                  ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.3,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.developer_board,
                                          size: 32,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Board name and details
                                  Column(
                                    children: [
                                      Text(
                                        board.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${board.switches.length} switches',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.grey[600],
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              board.status == BoardStatus.online
                                              ? Colors.green.withOpacity(0.2)
                                              : board.status ==
                                                    BoardStatus.offline
                                              ? Colors.red.withOpacity(0.2)
                                              : Colors.orange.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          board.status.name.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                board.status ==
                                                    BoardStatus.online
                                                ? Colors.green[700]
                                                : board.status ==
                                                      BoardStatus.offline
                                                ? Colors.red[700]
                                                : Colors.orange[700],
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
                    onPressed: _isScanning ? null : _scanWiFiDevices,
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
      },
    );
  }
}
