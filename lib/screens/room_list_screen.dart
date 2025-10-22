import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import '../models/room_model.dart';
import 'board_list_screen_new.dart';
import '../widgets/dynamic_background_widget.dart';
import '../providers/dynamic_theme_provider.dart';

class RoomListScreen extends StatefulWidget {
  final String homeId;
  final String homeName;

  const RoomListScreen({
    super.key,
    required this.homeId,
    required this.homeName,
  });

  @override
  State<RoomListScreen> createState() => _RoomListScreenState();
}

class _RoomListScreenState extends State<RoomListScreen> {
  final _rooms = <Room>[];
  bool _isLoading = true;
  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      // Load rooms from the specific home with their associated boards
      final response = await _supabase
          .from('rooms')
          .select('*, boards(*)')
          .eq('home_id', widget.homeId)
          .eq('is_active', true)
          .order('display_order', ascending: true);

      if (mounted) {
        setState(() {
          _rooms.clear();
          _rooms.addAll((response as List).map((room) => Room.fromJson(room)));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Error loading rooms: ${e.toString()}');
      }
    }
  }

  Future<void> _addRoom(String name, String? description, String? icon) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      final roomId = _uuid.v4();
      final response = await _supabase
          .from('rooms')
          .insert({
            'id': roomId,
            'home_id': widget.homeId,
            'name': name,
            'description': description,
            'icon': icon,
            'display_order': _rooms.length,
            'is_active': true,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final newRoom = Room.fromJson(response);

      if (mounted) {
        setState(() {
          _rooms.add(newRoom);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Room "$name" added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Error adding room: ${e.toString()}');
      }
    }
  }

  Future<void> _editRoom(
    Room room,
    String newName,
    String? newDescription,
    String? newIcon,
  ) async {
    try {
      await _supabase
          .from('rooms')
          .update({
            'name': newName,
            'description': newDescription,
            'icon': newIcon,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', room.id);

      if (mounted) {
        setState(() {
          final index = _rooms.indexWhere((r) => r.id == room.id);
          if (index != -1) {
            _rooms[index] = room.copyWith(
              name: newName,
              description: newDescription,
              icon: newIcon,
            );
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Room updated to "$newName"')));
      }
    } catch (e) {
      if (mounted) {
        _showError('Error updating room: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteRoom(Room room) async {
    try {
      // First, move all boards in this room to "unassigned" (null room_id)
      await _supabase
          .from('boards')
          .update({'room_id': null})
          .eq('room_id', room.id);

      // Then delete the room
      await _supabase.from('rooms').delete().eq('id', room.id);

      if (mounted) {
        setState(() {
          _rooms.removeWhere((r) => r.id == room.id);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Room "${room.name}" deleted')));
      }
    } catch (e) {
      if (mounted) {
        _showError('Error deleting room: ${e.toString()}');
      }
    }
  }

  void _showAddRoomDialog() {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    String selectedIcon = 'meeting_room';

    final List<Map<String, dynamic>> roomIcons = [
      {
        'icon': Icons.meeting_room,
        'name': 'meeting_room',
        'label': 'Living Room',
      },
      {'icon': Icons.bed, 'name': 'bed', 'label': 'Bedroom'},
      {'icon': Icons.kitchen, 'name': 'kitchen', 'label': 'Kitchen'},
      {'icon': Icons.bathtub, 'name': 'bathtub', 'label': 'Bathroom'},
      {'icon': Icons.restaurant, 'name': 'dining_room', 'label': 'Dining Room'},
      {'icon': Icons.work, 'name': 'work', 'label': 'Office'},
      {'icon': Icons.garage, 'name': 'garage', 'label': 'Garage'},
      {'icon': Icons.stairs, 'name': 'stairs', 'label': 'Stairs'},
      {'icon': Icons.balcony, 'name': 'balcony', 'label': 'Balcony'},
      {'icon': Icons.room, 'name': 'room', 'label': 'Other Room'},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Room'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Room Name',
                    hintText: 'Enter room name',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Enter room description',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Select Icon:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: roomIcons.map((iconData) {
                    final isSelected = selectedIcon == iconData['name'];
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedIcon = iconData['name'];
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              iconData['icon'],
                              color: isSelected ? Colors.white : Colors.black54,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              iconData['label'],
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
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
                final description = descriptionController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  _addRoom(
                    name,
                    description.isEmpty ? null : description,
                    selectedIcon,
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRoomOptionsDialog(Room room) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(room.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(context);
                _showEditRoomDialog(room);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog(room);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showEditRoomDialog(Room room) {
    final nameController = TextEditingController(text: room.name);
    final descriptionController = TextEditingController(
      text: room.description ?? '',
    );
    String selectedIcon = room.icon ?? 'meeting_room';

    final List<Map<String, dynamic>> roomIcons = [
      {
        'icon': Icons.meeting_room,
        'name': 'meeting_room',
        'label': 'Living Room',
      },
      {'icon': Icons.bed, 'name': 'bed', 'label': 'Bedroom'},
      {'icon': Icons.kitchen, 'name': 'kitchen', 'label': 'Kitchen'},
      {'icon': Icons.bathtub, 'name': 'bathtub', 'label': 'Bathroom'},
      {'icon': Icons.restaurant, 'name': 'dining_room', 'label': 'Dining Room'},
      {'icon': Icons.work, 'name': 'work', 'label': 'Office'},
      {'icon': Icons.garage, 'name': 'garage', 'label': 'Garage'},
      {'icon': Icons.stairs, 'name': 'stairs', 'label': 'Stairs'},
      {'icon': Icons.balcony, 'name': 'balcony', 'label': 'Balcony'},
      {'icon': Icons.room, 'name': 'room', 'label': 'Other Room'},
    ];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Room'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Room Name',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Select Icon:'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: roomIcons.map((iconData) {
                    final isSelected = selectedIcon == iconData['name'];
                    return GestureDetector(
                      onTap: () {
                        setDialogState(() {
                          selectedIcon = iconData['name'];
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.blue : Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              iconData['icon'],
                              color: isSelected ? Colors.white : Colors.black54,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              iconData['label'],
                              style: TextStyle(
                                fontSize: 10,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
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
                final description = descriptionController.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  _editRoom(
                    room,
                    name,
                    description.isEmpty ? null : description,
                    selectedIcon,
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmDialog(Room room) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room'),
        content: Text(
          'Are you sure you want to delete "${room.name}"?\n\n'
          'This will move all boards in this room to unassigned. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteRoom(room);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _getIconFromName(String? iconName) {
    switch (iconName) {
      case 'meeting_room':
        return Icons.meeting_room;
      case 'bed':
        return Icons.bed;
      case 'kitchen':
        return Icons.kitchen;
      case 'bathtub':
        return Icons.bathtub;
      case 'dining_room':
        return Icons.restaurant;
      case 'work':
        return Icons.work;
      case 'garage':
        return Icons.garage;
      case 'stairs':
        return Icons.stairs;
      case 'balcony':
        return Icons.balcony;
      case 'room':
      default:
        return Icons.room;
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DynamicThemeProvider>(
      builder: (context, themeProvider, child) {
        final isBasicTheme = themeProvider.backgroundType == 'basic';
        final isDark = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              widget.homeName,
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
                  Icons.developer_board_off,
                  color: isBasicTheme ? null : Colors.white,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return DynamicBackgroundWidget(
                          child: BoardListScreen(
                            homeId: widget.homeId,
                            roomId: null, // null means unassigned boards
                            roomName: null,
                          ),
                        );
                      },
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            return FadeTransition(
                              opacity: animation,
                              child: child,
                            );
                          },
                    ),
                  );
                },
                tooltip: 'View Unassigned Boards',
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
              : _rooms.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.meeting_room_outlined,
                        size: 64,
                        color: isBasicTheme
                            ? (isDark ? Colors.white70 : Colors.black54)
                            : Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No rooms added yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: isBasicTheme
                              ? (isDark ? Colors.white : Colors.black87)
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap + to add your first room',
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
                  itemCount: _rooms.length,
                  itemBuilder: (context, index) {
                    final room = _rooms[index];
                    return Hero(
                      tag: 'room-${room.id}',
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
                                          child: BoardListScreen(
                                            homeId: widget.homeId,
                                            roomId: room.id,
                                            roomName: room.name,
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
                                        child: IconButton(
                                          icon: Icon(
                                            Icons.more_vert,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          onPressed: () =>
                                              _showRoomOptionsDialog(room),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Center icon
                                  Expanded(
                                    child: Center(
                                      child: Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: isDark
                                                ? [
                                                    Colors.blue[800]!,
                                                    Colors.purple[800]!,
                                                  ]
                                                : [
                                                    Colors.blue[600]!,
                                                    Colors.purple[600]!,
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
                                        child: Icon(
                                          _getIconFromName(room.icon),
                                          size: 32,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Room name and board count
                                  Column(
                                    children: [
                                      Text(
                                        room.name,
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
                                        '${room.boards.length} boards',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: isDark
                                                  ? Colors.white70
                                                  : Colors.grey[600],
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddRoomDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Room'),
            backgroundColor: isDark
                ? Colors.white.withOpacity(0.2)
                : Colors.blue.withOpacity(0.8),
            foregroundColor: Colors.white,
            elevation: 8,
          ),
        );
      },
    );
  }
}
