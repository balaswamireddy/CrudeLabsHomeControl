#!/bin/bash

# Script to apply all theme fixes to the Smart Switch app

echo "===== Applying Theme Fixes ====="

# Step 1: Make backups of original files
echo "Making backups of original files..."
cp lib/screens/home_screen.dart lib/screens/home_screen.dart.original
cp lib/screens/board_list_screen.dart lib/screens/board_list_screen.dart.original
cp lib/screens/switch_control_screen.dart lib/screens/switch_control_screen.dart.original
cp lib/main.dart lib/main.dart.original

# Step 2: Replace original files with fixed versions
echo "Replacing files with fixed versions..."
cp lib/screens/home_screen_new.dart lib/screens/home_screen.dart
cp lib/screens/board_list_screen_new.dart lib/screens/board_list_screen.dart
cp lib/screens/switch_control_screen_new.dart lib/screens/switch_control_screen.dart

# Step 3: Update imports in login_screen.dart if needed
echo "Updating imports in login_screen.dart..."
sed -i '' 's/import .home_screen_new.dart./import "home_screen.dart";/g' lib/screens/login_screen.dart

# Step 4: Final clean-up
echo "Cleaning up..."
flutter clean
flutter pub get

echo "===== Theme Fixes Applied ====="
echo "Please run 'flutter run' to test the changes."
echo "If you encounter any issues, you can restore original files from the .original backups."