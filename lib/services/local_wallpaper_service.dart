import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing wallpapers locally without Supabase dependency
/// Stores wallpaper paths and images in app's local storage
class LocalWallpaperService {
  static const String _wallpaperPrefsKey = 'home_wallpapers';
  static const String _wallpaperDirName = 'wallpapers';

  /// Get the wallpapers directory
  Future<Directory> _getWallpapersDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final wallpapersDir = Directory('${appDir.path}/$_wallpaperDirName');

    if (!await wallpapersDir.exists()) {
      await wallpapersDir.create(recursive: true);
    }

    return wallpapersDir;
  }

  /// Save wallpaper mapping to SharedPreferences
  Future<void> _saveWallpaperMapping(Map<String, String> wallpaperMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_wallpaperPrefsKey, jsonEncode(wallpaperMap));
  }

  /// Load wallpaper mapping from SharedPreferences
  Future<Map<String, String>> _loadWallpaperMapping() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final wallpaperJson = prefs.getString(_wallpaperPrefsKey);

      if (wallpaperJson != null) {
        final Map<String, dynamic> decoded = jsonDecode(wallpaperJson);
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      print('Error loading wallpaper mapping: $e');
    }

    return <String, String>{};
  }

  /// Set wallpaper for a home (saves image locally and stores path)
  Future<String?> setHomeWallpaper({
    required String homeId,
    required String sourcePath,
  }) async {
    try {
      // Verify source file exists
      final sourceFile = File(sourcePath);
      if (!await sourceFile.exists()) {
        throw Exception('Source image file not found: $sourcePath');
      }

      // Get wallpapers directory
      final wallpapersDir = await _getWallpapersDirectory();

      // Create unique filename using home ID and timestamp
      final extension = sourcePath.split('.').last.toLowerCase();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'home_${homeId}_$timestamp.$extension';
      final localPath = '${wallpapersDir.path}/$filename';

      // Remove old wallpaper if exists
      await removeHomeWallpaper(homeId);

      // Copy the image to local directory
      final localFile = await sourceFile.copy(localPath);

      // Update wallpaper mapping
      final wallpaperMap = await _loadWallpaperMapping();
      wallpaperMap[homeId] = localFile.path;
      await _saveWallpaperMapping(wallpaperMap);

      print('✅ Wallpaper saved for home $homeId: ${localFile.path}');
      return localFile.path;
    } catch (e) {
      print('❌ Error setting wallpaper for home $homeId: $e');
      return null;
    }
  }

  /// Get wallpaper path for a home
  Future<String?> getHomeWallpaper(String homeId) async {
    try {
      final wallpaperMap = await _loadWallpaperMapping();
      final wallpaperPath = wallpaperMap[homeId];

      if (wallpaperPath != null) {
        // Verify file still exists
        final file = File(wallpaperPath);
        if (await file.exists()) {
          return wallpaperPath;
        } else {
          // File doesn't exist, remove from mapping
          print(
            '⚠️ Wallpaper file missing for home $homeId, removing from mapping',
          );
          await removeHomeWallpaper(homeId);
        }
      }

      return null;
    } catch (e) {
      print('❌ Error getting wallpaper for home $homeId: $e');
      return null;
    }
  }

  /// Remove wallpaper for a home
  Future<bool> removeHomeWallpaper(String homeId) async {
    try {
      final wallpaperMap = await _loadWallpaperMapping();
      final wallpaperPath = wallpaperMap[homeId];

      if (wallpaperPath != null) {
        // Delete the physical file
        try {
          final file = File(wallpaperPath);
          if (await file.exists()) {
            await file.delete();
            print('🗑️ Deleted wallpaper file: $wallpaperPath');
          }
        } catch (fileError) {
          print('⚠️ Could not delete wallpaper file: $fileError');
          // Continue anyway to remove from mapping
        }

        // Remove from mapping
        wallpaperMap.remove(homeId);
        await _saveWallpaperMapping(wallpaperMap);

        print('✅ Wallpaper removed for home $homeId');
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Error removing wallpaper for home $homeId: $e');
      return false;
    }
  }

  /// Get all wallpaper mappings
  Future<Map<String, String>> getAllWallpapers() async {
    return await _loadWallpaperMapping();
  }

  /// Clean up orphaned wallpaper files (files not in mapping)
  Future<void> cleanupOrphanedWallpapers() async {
    try {
      final wallpapersDir = await _getWallpapersDirectory();
      final wallpaperMap = await _loadWallpaperMapping();

      // Get all wallpaper paths from mapping
      final mappedPaths = wallpaperMap.values.toSet();

      // List all files in wallpapers directory
      if (await wallpapersDir.exists()) {
        final files = wallpapersDir
            .listSync()
            .where((entity) => entity is File)
            .cast<File>();

        int deletedCount = 0;
        for (final file in files) {
          if (!mappedPaths.contains(file.path)) {
            try {
              await file.delete();
              deletedCount++;
              print('🗑️ Deleted orphaned wallpaper: ${file.path}');
            } catch (e) {
              print('⚠️ Could not delete orphaned file: ${file.path} - $e');
            }
          }
        }

        if (deletedCount > 0) {
          print('🧹 Cleaned up $deletedCount orphaned wallpaper files');
        }
      }
    } catch (e) {
      print('❌ Error cleaning up orphaned wallpapers: $e');
    }
  }

  /// Get total size of wallpapers directory
  Future<int> getWallpapersDirectorySize() async {
    try {
      final wallpapersDir = await _getWallpapersDirectory();
      int totalSize = 0;

      if (await wallpapersDir.exists()) {
        final files = wallpapersDir
            .listSync(recursive: true)
            .where((entity) => entity is File)
            .cast<File>();

        for (final file in files) {
          try {
            final stat = await file.stat();
            totalSize += stat.size;
          } catch (e) {
            // Skip files we can't read
          }
        }
      }

      return totalSize;
    } catch (e) {
      print('❌ Error calculating wallpapers directory size: $e');
      return 0;
    }
  }

  /// Clear all wallpapers and reset mappings
  Future<void> clearAllWallpapers() async {
    try {
      final wallpapersDir = await _getWallpapersDirectory();

      // Delete all files in wallpapers directory
      if (await wallpapersDir.exists()) {
        final files = wallpapersDir
            .listSync()
            .where((entity) => entity is File)
            .cast<File>();

        for (final file in files) {
          try {
            await file.delete();
          } catch (e) {
            print('⚠️ Could not delete file: ${file.path} - $e');
          }
        }
      }

      // Clear mappings
      await _saveWallpaperMapping(<String, String>{});

      print('🧹 All wallpapers cleared');
    } catch (e) {
      print('❌ Error clearing all wallpapers: $e');
    }
  }

  /// Check if a home has a wallpaper
  Future<bool> hasWallpaper(String homeId) async {
    final wallpaperPath = await getHomeWallpaper(homeId);
    return wallpaperPath != null;
  }

  /// Get wallpaper file info
  Future<Map<String, dynamic>?> getWallpaperInfo(String homeId) async {
    try {
      final wallpaperPath = await getHomeWallpaper(homeId);

      if (wallpaperPath != null) {
        final file = File(wallpaperPath);
        final stat = await file.stat();

        return {
          'path': wallpaperPath,
          'filename': file.path.split('/').last,
          'size': stat.size,
          'modified': stat.modified,
          'exists': await file.exists(),
        };
      }

      return null;
    } catch (e) {
      print('❌ Error getting wallpaper info for home $homeId: $e');
      return null;
    }
  }
}
