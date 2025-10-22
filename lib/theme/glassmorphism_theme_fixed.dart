import 'package:flutter/material.dart';

class GlassmorphismTheme {
  // Glass effect colors that adapt to theme
  static Color glassWhite(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0x20FFFFFF)
        : const Color(0x30FFFFFF);
  }

  static Color glassBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0x30FFFFFF)
        : const Color(0x40FFFFFF);
  }

  static Color glassBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0x10FFFFFF)
        : const Color(0x20FFFFFF);
  }

  // Subtle time-based gradients
  static List<Color> getMorningGradient() => [
    const Color(0xFFfef3c7).withOpacity(0.3),
    const Color(0xFFfde68a).withOpacity(0.2),
  ];

  static List<Color> getAfternoonGradient() => [
    const Color(0xFFdbeafe).withOpacity(0.3),
    const Color(0xFFbfdbfe).withOpacity(0.2),
  ];

  static List<Color> getEveningGradient() => [
    const Color(0xFFfce7f3).withOpacity(0.3),
    const Color(0xFFfbcfe8).withOpacity(0.2),
  ];

  static List<Color> getNightGradient() => [
    const Color(0xFF1f2937).withOpacity(0.4),
    const Color(0xFF374151).withOpacity(0.3),
  ];

  // Get subtle gradient based on current time
  static List<Color> getTimeBasedGradient() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 12) {
      return getMorningGradient();
    } else if (hour >= 12 && hour < 18) {
      return getAfternoonGradient();
    } else if (hour >= 18 && hour < 21) {
      return getEveningGradient();
    } else {
      return getNightGradient();
    }
  }

  // Enhanced theme that builds on existing themes
  static ThemeData enhanceTheme(ThemeData baseTheme) {
    return baseTheme.copyWith(
      appBarTheme: baseTheme.appBarTheme.copyWith(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
    );
  }
}

// Glass effect box decoration
class GlassDecoration {
  static BoxDecoration card(BuildContext context) => BoxDecoration(
    gradient: LinearGradient(
      colors: [
        GlassmorphismTheme.glassWhite(context),
        GlassmorphismTheme.glassBackground(context),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: GlassmorphismTheme.glassBorder(context),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 15,
        offset: const Offset(0, 8),
      ),
    ],
  );

  static BoxDecoration button(BuildContext context) => BoxDecoration(
    gradient: LinearGradient(
      colors: [
        GlassmorphismTheme.glassWhite(context),
        GlassmorphismTheme.glassBackground(context),
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    ),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: GlassmorphismTheme.glassBorder(context),
      width: 1,
    ),
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
