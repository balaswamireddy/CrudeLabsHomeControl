import 'package:flutter/material.dart';
import '../services/board_discovery_service_new.dart';
import '../services/streamlined_database_service.dart';
import '../widgets/glass_widgets.dart';

/// Screen for discovering and configuring new SmartSwitch boards
/// Implements the simplified WiFi-only configuration flow
class BoardConfigurationScreen extends StatefulWidget {
  final String roomId;
  final String roomName;

  const BoardConfigurationScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  State<BoardConfigurationScreen> createState() =>
      _BoardConfigurationScreenState();
}

class _BoardConfigurationScreenState extends State<BoardConfigurationScreen> {
  final BoardDiscoveryService _discoveryService = BoardDiscoveryService();
  final StreamlinedDatabaseService _databaseService =
      StreamlinedDatabaseService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _boardNameController = TextEditingController();
  final _boardDescriptionController = TextEditingController();
  final _wifiSSIDController = TextEditingController();
  final _wifiPasswordController = TextEditingController();

  // State
  ConfigurationStep _currentStep = ConfigurationStep.discovery;
  List<DiscoveredBoard> _discoveredBoards = [];
  DiscoveredBoard? _selectedBoard;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isConfiguring = false;

  @override
  void initState() {
    super.initState();
    _startBoardDiscovery();
  }

  @override
  void dispose() {
    _boardNameController.dispose();
    _boardDescriptionController.dispose();
    _wifiSSIDController.dispose();
    _wifiPasswordController.dispose();
    super.dispose();
  }

  /// Start scanning for available boards
  Future<void> _startBoardDiscovery() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final boards = await _discoveryService.scanForBoards();
      setState(() {
        _discoveredBoards = boards;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to scan for boards: $e';
        _isLoading = false;
      });
    }
  }

  /// Select a board and move to configuration
  void _selectBoard(DiscoveredBoard board) {
    setState(() {
      _selectedBoard = board;
      _boardNameController.text = '${board.boardId} Controller';
      _currentStep = ConfigurationStep.configuration;
    });
  }

  /// Configure the selected board
  Future<void> _configureBoard() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBoard == null) return;

    setState(() {
      _isConfiguring = true;
      _errorMessage = null;
    });

    try {
      // Get Supabase configuration
      final dbConfig = await _databaseService.getBoardConfigInfo();

      // Configure the board with WiFi and database credentials
      final result = await _discoveryService.configureBoard(
        board: _selectedBoard!,
        wifiSSID: _wifiSSIDController.text.trim(),
        wifiPassword: _wifiPasswordController.text.trim(),
        supabaseURL: dbConfig['supabase_url'],
        supabaseKey: dbConfig['supabase_key'],
      );

      if (result.success) {
        // Check if board is available for assignment
        final isAvailable = await _databaseService.isBoardAvailable(
          _selectedBoard!.boardId,
        );

        if (!isAvailable) {
          throw Exception(
            'Board ${_selectedBoard!.boardId} is already assigned to another room',
          );
        }

        // Assign board to room in database
        await _databaseService.assignBoardToRoom(
          boardId: _selectedBoard!.boardId,
          roomId: widget.roomId,
          name: _boardNameController.text.trim(),
          description: _boardDescriptionController.text.trim().isEmpty
              ? null
              : _boardDescriptionController.text.trim(),
        );

        setState(() {
          _currentStep = ConfigurationStep.success;
        });
      } else {
        throw Exception(result.message);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Configuration failed: $e';
      });
    } finally {
      setState(() {
        _isConfiguring = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Board to ${widget.roomName}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildCurrentStepContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case ConfigurationStep.discovery:
        return _buildDiscoveryStep();
      case ConfigurationStep.configuration:
        return _buildConfigurationStep();
      case ConfigurationStep.success:
        return _buildSuccessStep();
    }
  }

  Widget _buildDiscoveryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        const Text(
          '🔍 Scanning for SmartSwitch Boards',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Make sure your board is in configuration mode. The board should create a WiFi network named "SmartSwitch_BOARD_XXX".',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 32),

        if (_isLoading) ...[
          const Center(
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Scanning for boards...'),
              ],
            ),
          ),
        ] else if (_errorMessage != null) ...[
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _startBoardDiscovery,
                    child: const Text('Retry Scan'),
                  ),
                ],
              ),
            ),
          ),
        ] else if (_discoveredBoards.isEmpty) ...[
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.orange, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'No boards found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Make sure your board is powered on and in configuration mode.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _startBoardDiscovery,
                    child: const Text('Scan Again'),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Expanded(
            child: ListView.builder(
              itemCount: _discoveredBoards.length,
              itemBuilder: (context, index) {
                final board = _discoveredBoards[index];
                return GlassCard(
                  child: ListTile(
                    leading: Icon(
                      Icons.router,
                      color: _getSignalColor(board.signalStrength),
                      size: 32,
                    ),
                    title: Text(
                      board.boardId,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Network: ${board.ssid}'),
                        Text('Signal: ${board.signalStrength} dBm'),
                      ],
                    ),
                    trailing: Icon(
                      board.isSecure ? Icons.lock : Icons.lock_open,
                      color: board.isSecure ? Colors.green : Colors.orange,
                    ),
                    onTap: () => _selectBoard(board),
                  ),
                );
              },
            ),
          ),
        ],

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _startBoardDiscovery,
            child: const Text('Refresh'),
          ),
        ),
      ],
    );
  }

  Widget _buildConfigurationStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            '⚙️ Configure ${_selectedBoard?.boardId ?? "Board"}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter your WiFi credentials and board details. The board will connect to your home network and register with the database.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Board Information
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Board Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _boardNameController,
                            decoration: const InputDecoration(
                              labelText: 'Board Name',
                              hintText: 'e.g., Living Room Controller',
                              prefixIcon: Icon(Icons.label),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter a board name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _boardDescriptionController,
                            decoration: const InputDecoration(
                              labelText: 'Description (Optional)',
                              hintText: 'e.g., Controls main lights and fan',
                              prefixIcon: Icon(Icons.description),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // WiFi Configuration
                  GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'WiFi Configuration',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _wifiSSIDController,
                            decoration: const InputDecoration(
                              labelText: 'WiFi Network Name',
                              hintText: 'Your home WiFi network',
                              prefixIcon: Icon(Icons.wifi),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter WiFi network name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _wifiPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'WiFi Password',
                              hintText: 'Your WiFi password',
                              prefixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter WiFi password';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isConfiguring
                      ? null
                      : () {
                          setState(() {
                            _currentStep = ConfigurationStep.discovery;
                          });
                        },
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isConfiguring ? null : _configureBoard,
                  child: _isConfiguring
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Configuring...'),
                          ],
                        )
                      : const Text('Configure Board'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 80),
        const SizedBox(height: 24),
        const Text(
          '🎉 Board Configured Successfully!',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Your ${_selectedBoard?.boardId ?? "board"} has been configured and added to ${widget.roomName}.',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Next Steps:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text('• The board will restart and connect to your WiFi'),
                const Text('• You can now control switches from the app'),
                const Text('• Set up timers and automation'),
                const Text('• Customize switch names and types'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(true); // Return success
            },
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }

  Color _getSignalColor(int signalStrength) {
    if (signalStrength >= -50) return Colors.green;
    if (signalStrength >= -70) return Colors.orange;
    return Colors.red;
  }
}

enum ConfigurationStep { discovery, configuration, success }
