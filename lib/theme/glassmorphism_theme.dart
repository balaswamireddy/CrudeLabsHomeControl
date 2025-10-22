import 'package:flutter/material.dart';

class GlassmorphismTheme {
  // Glass effect colors
  static const Color glassWhite = Color(0x20FFFFFF);
  static const Color glassBorder = Color(0x30FFFFFF);
  static const Color glassBackground = Color(0x10FFFFFF);

  // Primary gradient colors
  static const List<Color> primaryGradient = [
    Color(0xFF667eea),
    Color(0xFF764ba2),
  ];

  static const List<Color> secondaryGradient = [
    Color(0xFFf093fb),
    Color(0xFFf5576c),
  ];

  static const List<Color> accentGradient = [
    Color(0xFF4facfe),
    Color(0xFF00f2fe),
  ];

  // Time-based gradients
  static List<Color> getMorningGradient() => [
    const Color(0xFFFFE259),
    const Color(0xFFFFA751),
  ];

  static List<Color> getAfternoonGradient() => [
    const Color(0xFF74b9ff),
    const Color(0xFF0984e3),
  ];

  static List<Color> getEveningGradient() => [
    const Color(0xFFfd79a8),
    const Color(0xFFe84393),
  ];

  static List<Color> getNightGradient() => [
    const Color(0xFF2d3436),
    const Color(0xFF636e72),
  ];

  // Get gradient based on current time
  static List<Color> getTimeBasedGradient() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 12) {
      return getMorningGradient(); // Morning
    } else if (hour >= 12 && hour < 18) {
      return getAfternoonGradient(); // Afternoon
    } else if (hour >= 18 && hour < 21) {
      return getEveningGradient(); // Evening
    } else {
      return getNightGradient(); // Night
    }
  }

  // Glass morphism theme data
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF667eea),
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: glassWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: glassWhite,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF667eea),
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: const Color(0x20FFFFFF),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0x30FFFFFF),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
    );
  }
}

// Glass effect box decoration
class GlassDecoration {
  static BoxDecoration get primary => BoxDecoration(
    gradient: LinearGradient(
      colors: [
        GlassmorphismTheme.glassWhite,
        GlassmorphismTheme.glassBackground,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: GlassmorphismTheme.glassBorder, width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 20,
        offset: const Offset(0, 10),
      ),
      BoxShadow(
        color: Colors.white.withOpacity(0.2),
        blurRadius: 10,
        offset: const Offset(-5, -5),
      ),
    ],
  );

  static BoxDecoration get card => BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.white.withOpacity(0.25), Colors.white.withOpacity(0.1)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 15,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration get button => BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static BoxDecoration switchOn(List<Color> gradientColors) => BoxDecoration(
    gradient: LinearGradient(
      colors: gradientColors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(25),
    boxShadow: [
      BoxShadow(
        color: gradientColors.first.withOpacity(0.4),
        blurRadius: 15,
        spreadRadius: 2,
      ),
    ],
  );

  static BoxDecoration get switchOff => BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.grey.shade300, Colors.grey.shade400],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(25),
    boxShadow: [
      BoxShadow(
        color: Colors.grey.withOpacity(0.3),
        blurRadius: 10,
        spreadRadius: 1,
      ),
    ],
  );
}
