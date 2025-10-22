#!/bin/bash

# Script to fix only the main.dart import for testing

echo "===== Updating main.dart import ====="

# Backup main.dart
cp lib/main.dart lib/main.dart.bak2

# Replace 'home_screen.dart' with 'home_screen_new.dart' in main.dart
sed -i '' 's/import .screens\/home_screen.dart./import "screens\/home_screen_new.dart";/g' lib/main.dart

echo "Done. Original file backed up as lib/main.dart.bak2"
echo "Run 'flutter run' to test the change."