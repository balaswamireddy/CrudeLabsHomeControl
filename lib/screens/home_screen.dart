import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../models/home_model.dart';
import 'board_list_screen.dart';
import '../widgets/welcome_card.dart';
import '../widgets/animated_sky_background.dart';
import '../providers/dynamic_theme_provider.dart';
import '../services/streamlined_database_service.dart';
import '../services/local_wallpaper_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StreamlinedDatabaseService _databaseService =
      StreamlinedDatabaseService();
  final LocalWallpaperService _wallpaperService = LocalWallpaperService();
  final List<Home> _homes = [];
  bool _isLoading = true;
  bool _showWelcomeCard = false;

  @override
  void initState() {
    super.initState();
    _loadHomes();
    _checkWelcomeCardStatus();
  }

  Future<void> _checkWelcomeCardStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenWelcomeCard = prefs.getBool('has_seen_welcome_card') ?? false;

    setState(() {
      _showWelcomeCard = !hasSeenWelcomeCard;
    });
  }

  Future<void> _hideWelcomeCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_welcome_card', true);

    setState(() {
      _showWelcomeCard = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DynamicThemeProvider>(
      builder: (context, themeProvider, child) {
        // Determine if we should use basic theme
        final useBasicTheme = themeProvider.backgroundType == 'basic';

        // Build the appropriate UI based on theme type
        return Scaffold(
          backgroundColor: useBasicTheme
              ? (themeProvider.isDarkMode
                    ? const Color(0xFF121212)
                    : const Color(0xFFF5F5F5))
              : Colors.transparent,
          appBar: AppBar(
            title: const Text(
              'My Homes',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () {
                  Navigator.pushNamed(context, '/settings');
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
              : Column(
                  children: [
                    // Welcome card for new users
                    if (_showWelcomeCard && _homes.isEmpty)
                      WelcomeCard(
                        onGetStarted: () {
                          _hideWelcomeCard();
                          _showAddHomeDialog();
                        },
                        onDismiss: _hideWelcomeCard,
                      ),

                    // Home list or empty state
                    Expanded(
                      child: _homes.isEmpty
                          ? _showWelcomeCard
                                ? const SizedBox() // Welcome card is shown above
                                : Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.home_outlined,
                                          size: 64,
                                          color: Colors.white.withOpacity(0.7),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No homes added yet',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(color: Colors.white),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Tap + to add your first home',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                          : AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 1,
                                      mainAxisSpacing: 16,
                                      crossAxisSpacing: 16,
                                      childAspectRatio: 1.8,
                                    ),
                                itemCount: _homes.length,
                                itemBuilder: (context, index) {
                                  final home = _homes[index];
                                  return Hero(
                                    tag: 'home-${home.id}',
                                    child: Card(
                                      elevation: 8,
                                      shadowColor: Colors.black.withOpacity(
                                        0.3,
                                      ),
                                      clipBehavior: Clip.hardEdge,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          image: home.wallpaperPath != null
                                              ? DecorationImage(
                                                  image: FileImage(
                                                    File(home.wallpaperPath!),
                                                  ),
                                                  fit: BoxFit.cover,
                                                  colorFilter: ColorFilter.mode(
                                                    Colors.black.withOpacity(
                                                      0.3,
                                                    ),
                                                    BlendMode.darken,
                                                  ),
                                                )
                                              : null,
                                          gradient: home.wallpaperPath == null
                                              ? LinearGradient(
                                                  colors:
                                                      themeProvider.isDarkMode
                                                      ? [
                                                          Colors.grey[800]!
                                                              .withOpacity(0.9),
                                                          Colors.grey[900]!
                                                              .withOpacity(0.9),
                                                        ]
                                                      : [
                                                          Colors.white
                                                              .withOpacity(0.9),
                                                          Colors.grey[100]!
                                                              .withOpacity(0.9),
                                                        ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                )
                                              : null,
                                        ),
                                        child: InkWell(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              PageRouteBuilder(
                                                pageBuilder:
                                                    (
                                                      context,
                                                      animation,
                                                      secondaryAnimation,
                                                    ) => Consumer<DynamicThemeProvider>(
                                                      builder:
                                                          (
                                                            context,
                                                            themeProvider,
                                                            child,
                                                          ) => AnimatedSkyBackground(
                                                            isDarkMode:
                                                                themeProvider
                                                                    .isDarkMode,
                                                            child:
                                                                BoardListScreen(
                                                                  homeId:
                                                                      home.id,
                                                                ),
                                                          ),
                                                    ),
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
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              children: [
                                                // Top row with title and menu
                                                Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        home.name,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headlineSmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  home.wallpaperPath !=
                                                                      null
                                                                  ? Colors.white
                                                                  : themeProvider
                                                                        .isDarkMode
                                                                  ? Colors.white
                                                                  : Colors
                                                                        .black87,
                                                              shadows:
                                                                  home.wallpaperPath !=
                                                                      null
                                                                  ? [
                                                                      Shadow(
                                                                        offset:
                                                                            const Offset(
                                                                              1,
                                                                              1,
                                                                            ),
                                                                        blurRadius:
                                                                            3,
                                                                        color: Colors
                                                                            .black
                                                                            .withOpacity(
                                                                              0.7,
                                                                            ),
                                                                      ),
                                                                    ]
                                                                  : null,
                                                            ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    Container(
                                                      decoration: BoxDecoration(
                                                        color:
                                                            home.wallpaperPath !=
                                                                null
                                                            ? Colors.black
                                                                  .withOpacity(
                                                                    0.3,
                                                                  )
                                                            : themeProvider
                                                                  .isDarkMode
                                                            ? Colors.grey[800]!
                                                                  .withOpacity(
                                                                    0.5,
                                                                  )
                                                            : Colors.grey[200]!
                                                                  .withOpacity(
                                                                    0.5,
                                                                  ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      child: IconButton(
                                                        icon: Icon(
                                                          Icons.more_vert,
                                                          color:
                                                              home.wallpaperPath !=
                                                                  null
                                                              ? Colors.white
                                                              : themeProvider
                                                                    .isDarkMode
                                                              ? Colors.white
                                                              : Colors.black87,
                                                        ),
                                                        onPressed: () =>
                                                            _showHomeOptionsDialog(
                                                              home,
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),

                                                // Spacer to push icon to center (only show icon when no wallpaper)
                                                Expanded(
                                                  child: Center(
                                                    child:
                                                        home.wallpaperPath ==
                                                                null ||
                                                            home
                                                                .wallpaperPath!
                                                                .isEmpty
                                                        ? Container(
                                                            width: 80,
                                                            height: 80,
                                                            decoration: BoxDecoration(
                                                              gradient: LinearGradient(
                                                                colors:
                                                                    themeProvider
                                                                        .isDarkMode
                                                                    ? [
                                                                        Colors
                                                                            .blue[800]!,
                                                                        Colors
                                                                            .purple[800]!,
                                                                      ]
                                                                    : [
                                                                        Colors
                                                                            .blue[600]!,
                                                                        Colors
                                                                            .purple[600]!,
                                                                      ],
                                                                begin: Alignment
                                                                    .topLeft,
                                                                end: Alignment
                                                                    .bottomRight,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    20,
                                                                  ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withOpacity(
                                                                        0.3,
                                                                      ),
                                                                  blurRadius: 8,
                                                                  offset:
                                                                      const Offset(
                                                                        0,
                                                                        4,
                                                                      ),
                                                                ),
                                                              ],
                                                            ),
                                                            child: Icon(
                                                              Icons
                                                                  .home_rounded,
                                                              size: 40,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          )
                                                        : const SizedBox.shrink(), // Hide icon when wallpaper is present
                                                  ),
                                                ), // Bottom section with boards info and progress
                                                Column(
                                                  children: [
                                                    Text(
                                                      '${home.boards.length} boards',
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .bodyMedium
                                                          ?.copyWith(
                                                            color:
                                                                home.wallpaperPath !=
                                                                    null
                                                                ? Colors.white
                                                                : themeProvider
                                                                      .isDarkMode
                                                                ? Colors.white70
                                                                : Colors
                                                                      .grey[600],
                                                            shadows:
                                                                home.wallpaperPath !=
                                                                    null
                                                                ? [
                                                                    Shadow(
                                                                      offset:
                                                                          const Offset(
                                                                            1,
                                                                            1,
                                                                          ),
                                                                      blurRadius:
                                                                          3,
                                                                      color: Colors
                                                                          .black
                                                                          .withOpacity(
                                                                            0.7,
                                                                          ),
                                                                    ),
                                                                  ]
                                                                : null,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 8),
                                                    LinearProgressIndicator(
                                                      value: home.boards.isEmpty
                                                          ? 0.0
                                                          : home.boards.length /
                                                                10,
                                                      backgroundColor:
                                                          home.wallpaperPath !=
                                                              null
                                                          ? Colors.white
                                                                .withOpacity(
                                                                  0.3,
                                                                )
                                                          : themeProvider
                                                                .isDarkMode
                                                          ? Colors.grey[700]
                                                          : Colors.grey[300],
                                                      valueColor:
                                                          AlwaysStoppedAnimation<
                                                            Color
                                                          >(
                                                            themeProvider
                                                                    .isDarkMode
                                                                ? Colors
                                                                      .blue[400]!
                                                                : Colors
                                                                      .blue[600]!,
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
                            ),
                    ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _showAddHomeDialog,
            icon: const Icon(Icons.add_home),
            label: const Text('Add Home'),
            backgroundColor: themeProvider.isDarkMode
                ? Colors.white.withOpacity(0.2)
                : Colors.blue.withOpacity(0.8),
            foregroundColor: Colors.white,
            elevation: 8,
          ),
        );
      },
    );
  }

  Future<void> _loadHomes() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      try {
        final response = await _supabase
            .from('homes')
            .select('*, boards(*)')
            .eq('user_id', user.id)
            .order('created_at', ascending: true);

        final homesWithLocalWallpapers = <Home>[];
        for (final homeData in response as List) {
          final home = Home.fromJson(homeData);

          // Get local wallpaper path using the local wallpaper service
          final localWallpaperPath = await _wallpaperService.getHomeWallpaper(
            home.id,
          );

          homesWithLocalWallpapers.add(
            Home(
              id: home.id,
              name: home.name,
              userId: home.userId,
              wallpaperPath: localWallpaperPath, // Use local wallpaper path
              boards: home.boards,
            ),
          );
        }

        if (mounted) {
          setState(() {
            _homes.clear();
            _homes.addAll(homesWithLocalWallpapers);
            _isLoading = false;
          });
        }
      } catch (tableError) {
        if (tableError.toString().contains('does not exist') ||
            tableError.toString().contains('cannot find')) {
          if (mounted) {
            setState(() {
              _homes.clear();
              _isLoading = false;
            });
          }
          _showError(
            'Database tables are being set up. Please try adding a home.',
          );
        } else {
          throw tableError;
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showError('Error loading homes: ${e.toString()}');
      }
    }
  }

  Future<void> _addHome(String name) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/login');
        }
        return;
      }

      // Use the proper database service that generates custom IDs
      final response = await _databaseService.createHome(name: name);
      final newHome = Home.fromJson(response);

      if (mounted) {
        setState(() {
          _homes.add(newHome);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Home "$name" added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Error adding home: ${e.toString()}');
      }
    }
  }

  Future<void> _editHome(Home home, String newName) async {
    try {
      await _supabase.from('homes').update({'name': newName}).eq('id', home.id);

      if (mounted) {
        setState(() {
          final index = _homes.indexWhere((h) => h.id == home.id);
          if (index != -1) {
            _homes[index] = Home(
              id: home.id,
              name: newName,
              userId: home.userId,
              wallpaperPath: home.wallpaperPath,
              boards: home.boards,
            );
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Home renamed to "$newName"')));
      }
    } catch (e) {
      if (mounted) {
        _showError('Error updating home: ${e.toString()}');
      }
    }
  }

  Future<void> _deleteHome(Home home) async {
    try {
      await _supabase.from('homes').delete().eq('id', home.id);

      if (mounted) {
        setState(() {
          _homes.removeWhere((h) => h.id == home.id);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Home "${home.name}" deleted')));
      }
    } catch (e) {
      if (mounted) {
        _showError('Error deleting home: ${e.toString()}');
      }
    }
  }

  void _showAddHomeDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Home'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Home Name',
            hintText: 'Enter home name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.pop(context);
              _addHome(value.trim());
            }
          },
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
                Navigator.pop(context);
                _addHome(name);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showHomeOptionsDialog(Home home) {
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
            Text(home.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename'),
              onTap: () {
                Navigator.pop(context);
                _showEditHomeDialog(home);
              },
            ),
            ListTile(
              leading: const Icon(Icons.wallpaper, color: Colors.blue),
              title: const Text('Set Wallpaper'),
              onTap: () {
                Navigator.pop(context);
                _showWallpaperOptions(home);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog(home);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showWallpaperOptions(Home home) {
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
            Text(
              'Set Wallpaper for ${home.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.photo_camera, color: Colors.green),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickWallpaper(home, ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickWallpaper(home, ImageSource.gallery);
              },
            ),
            if (home.wallpaperPath != null)
              ListTile(
                leading: const Icon(Icons.clear, color: Colors.red),
                title: const Text('Remove Wallpaper'),
                onTap: () {
                  Navigator.pop(context);
                  _removeWallpaper(home);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickWallpaper(Home home, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();

      // Check if the image picker is available
      if (!mounted) return;

      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image != null && mounted) {
        // Verify file exists before proceeding
        final file = File(image.path);
        if (await file.exists()) {
          // Save image using the local wallpaper service with persistence
          final localImagePath = await _wallpaperService.setHomeWallpaper(
            homeId: home.id,
            sourcePath: image.path,
          );
          if (localImagePath != null) {
            await _updateHomeWallpaper(home, localImagePath);
          }
        } else {
          _showError('Selected image file not found');
        }
      }
    } on PlatformException catch (e) {
      if (mounted) {
        if (e.code == 'photo_access_denied') {
          _showError('Photo library access denied. Please enable in settings.');
        } else if (e.code == 'camera_access_denied') {
          _showError('Camera access denied. Please enable in settings.');
        } else {
          _showError(
            'Error accessing ${source == ImageSource.camera ? 'camera' : 'gallery'}: ${e.message}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error selecting image: ${e.toString()}');
      }
    }
  }

  Future<void> _updateHomeWallpaper(Home home, String localImagePath) async {
    try {
      // Store wallpaper locally only - no database update needed
      if (mounted) {
        setState(() {
          final index = _homes.indexWhere((h) => h.id == home.id);
          if (index != -1) {
            _homes[index] = Home(
              id: home.id,
              name: home.name,
              userId: home.userId,
              wallpaperPath: localImagePath, // Store full local path in memory
              boards: home.boards,
            );
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Wallpaper updated and saved locally - will persist across app restarts',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Error updating wallpaper: ${e.toString()}');
      }
    }
  }

  Future<void> _removeWallpaper(Home home) async {
    try {
      // Remove wallpaper using the local wallpaper service
      final success = await _wallpaperService.removeHomeWallpaper(home.id);

      if (success) {
        // Update UI only
        if (mounted) {
          setState(() {
            final index = _homes.indexWhere((h) => h.id == home.id);
            if (index != -1) {
              _homes[index] = Home(
                id: home.id,
                name: home.name,
                userId: home.userId,
                wallpaperPath: null,
                boards: home.boards,
              );
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Wallpaper removed successfully')),
          );
        }
      } else {
        _showError('Failed to remove wallpaper');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error removing wallpaper: ${e.toString()}');
      }
    }
  }

  void _showEditHomeDialog(Home home) {
    final nameController = TextEditingController(text: home.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Home'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Home Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty && value.trim() != home.name) {
              Navigator.pop(context);
              _editHome(home, value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty && name != home.name) {
                Navigator.pop(context);
                _editHome(home, name);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(Home home) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Home'),
        content: Text(
          'Are you sure you want to delete "${home.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteHome(home);
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

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }
}
