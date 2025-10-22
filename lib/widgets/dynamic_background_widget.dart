import 'package:flutter/material.dart';
import '../providers/dynamic_theme_provider.dart';
import 'animated_sky_background.dart';
import 'sunrise_gradient_background.dart';
import 'rainy_animated_background.dart';
import 'package:provider/provider.dart';

// Simplified universal background widget that chooses safe backgrounds only
class DynamicBackgroundWidget extends StatelessWidget {
  final Widget child;

  const DynamicBackgroundWidget({Key? key, required this.child})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<DynamicThemeProvider>(
      builder: (context, themeProvider, _) {
        final backgroundType = themeProvider.backgroundType;
        final isDark = themeProvider.isDarkMode;
        final weatherCondition = themeProvider.themeSettings.currentWeather;

        return _buildBackgroundForType(
          backgroundType,
          isDark,
          weatherCondition,
        );
      },
    );
  }

  Widget _buildBackgroundForType(
    String backgroundType,
    bool isDark,
    dynamic weatherCondition,
  ) {
    debugPrint(
      '🔥 BUILDING BACKGROUND: type=$backgroundType, isDark=$isDark, weather=$weatherCondition',
    );

    // ABSOLUTELY FORCE basic theme to be plain solid colors ONLY
    if (backgroundType == 'basic') {
      debugPrint(
        '🎯 BASIC THEME DETECTED - Building SOLID ${isDark ? 'DARK' : 'LIGHT'} background NO ANIMATIONS',
      );
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF121212)
            : const Color(0xFFF5F5F5),
        body: child,
      );
    }

    // Only show animations for non-basic themes
    switch (backgroundType) {
      case 'animated':
        debugPrint('🌟 Building animated background');
        return AnimatedSkyBackground(isDarkMode: isDark, child: child);

      case 'sunrise':
        return SunriseGradientBackground(isSunset: false, child: child);

      case 'sunset':
        return SunriseGradientBackground(isSunset: true, child: child);

      case 'sunny':
        return _buildSunnyBackground();

      case 'cloudy':
        return _buildCloudyBackground();

      case 'rainy':
        // Special case for thunderstorm weather condition
        if (weatherCondition == 'thunderstorm') {
          return _buildThunderstormBackground();
        }
        return _buildRainyBackground();

      case 'foggy':
        return _buildFoggyBackground();

      case 'thunderstorm':
        return _buildThunderstormBackground();

      default:
        // Fallback to animated background
        return AnimatedSkyBackground(isDarkMode: isDark, child: child);
    }
  }

  Widget _buildSunnyBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4FC3F7), // Bright sky blue
            Color(0xFF81C784), // Light green
            Color(0xFFAED581), // Bright yellow-green
            Color(0xFFFFEB3B), // Sunny yellow
          ],
        ),
      ),
      child: Stack(
        children: [
          // Bright sun
          Positioned(
            top: 100,
            right: 80,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white,
                    Colors.yellow.shade300,
                    Colors.orange.shade200,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.yellow.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }

  Widget _buildCloudyBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF90A4AE), // Gray-blue
            Color(0xFFB0BEC5), // Light gray
            Color(0xFFCFD8DC), // Very light gray
            Color(0xFFECEFF1), // Almost white
          ],
        ),
      ),
      child: child,
    );
  }

  Widget _buildRainyBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF607D8B), // Gray-blue for rain
            Color(0xFF78909C),
            Color(0xFF90A4AE),
            Color(0xFFB0BEC5),
          ],
        ),
      ),
      child: child,
    );
  }

  Widget _buildFoggyBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF757575), // Medium gray
            Color(0xFF9E9E9E), // Light gray
            Color(0xFFBDBDBD), // Very light gray
            Color(0xFFE0E0E0), // Foggy white
          ],
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3), // Foggy overlay
        ),
        child: child,
      ),
    );
  }

  Widget _buildThunderstormBackground() {
    // Use the RainyAnimatedBackground with isThunderstorm set to true
    return RainyAnimatedBackground(isThunderstorm: true, child: child);
  }
}
