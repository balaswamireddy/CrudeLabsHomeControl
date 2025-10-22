import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dynamic_theme_provider.dart';
import '../models/theme_models.dart' as theme_models;

class ThemeSettingsPage extends StatefulWidget {
  const ThemeSettingsPage({super.key});

  @override
  State<ThemeSettingsPage> createState() => _ThemeSettingsPageState();
}

class _ThemeSettingsPageState extends State<ThemeSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theme Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<DynamicThemeProvider>(
        builder: (context, themeProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildThemeTypeSection(themeProvider),
              const SizedBox(height: 24),

              // Show appropriate settings based on theme type
              if (themeProvider.themeSettings.themeType ==
                      theme_models.ThemeType.basic ||
                  themeProvider.themeSettings.themeType ==
                      theme_models.ThemeType.animated)
                _buildAnimatedThemeSettings(themeProvider),

              if (themeProvider.themeSettings.themeType ==
                  theme_models.ThemeType.dynamicTime)
                _buildDynamicTimeSettings(themeProvider),

              if (themeProvider.themeSettings.themeType ==
                  theme_models.ThemeType.dynamicWeather)
                _buildDynamicWeatherSettings(themeProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeTypeSection(DynamicThemeProvider themeProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Theme Type',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Theme type selection cards
            ...theme_models.ThemeType.values.map((themeType) {
              final isSelected =
                  themeProvider.themeSettings.themeType == themeType;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => themeProvider.updateThemeType(themeType),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      color: isSelected
                          // ignore: deprecated_member_use
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getThemeTypeIcon(themeType),
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                themeType.displayName,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                themeType.description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Theme.of(context).primaryColor,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedThemeSettings(DynamicThemeProvider themeProvider) {
    final isBasicTheme =
        themeProvider.themeSettings.themeType == theme_models.ThemeType.basic;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBasicTheme ? 'Basic Theme Settings' : 'Animated Theme Settings',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: Text(
                isBasicTheme
                    ? 'Simple dark or light theme without animations'
                    : themeProvider.themeSettings.isDarkMode
                    ? 'Beautiful night sky with stars and falling stars'
                    : 'Bright day scene with clouds and flying birds',
              ),
              value: themeProvider.themeSettings.isDarkMode,
              onChanged: (value) {
                if (isBasicTheme) {
                  // Update basic theme which ensures theme type stays basic
                  themeProvider.updateBasicTheme(value);
                } else {
                  // For other themes, just update dark mode without changing theme type
                  themeProvider.updateDarkMode(value);
                }
              },
              secondary: Icon(
                themeProvider.themeSettings.isDarkMode
                    ? (isBasicTheme ? Icons.dark_mode : Icons.nights_stay)
                    : (isBasicTheme ? Icons.light_mode : Icons.wb_sunny),
              ),
            ),

            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue.shade600, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      themeProvider.themeSettings.isDarkMode
                          ? 'Night mode: Animated stars, falling stars, and twinkling effects'
                          : 'Day mode: Animated clouds, flying birds, and beautiful sky gradients',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicTimeSettings(DynamicThemeProvider themeProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dynamic Time-based Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Current time of day display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.1),
                    Theme.of(context).primaryColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getTimeOfDayIcon(
                      themeProvider.themeSettings.currentTimeOfDay,
                    ),
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Theme',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          themeProvider
                                  .themeSettings
                                  .currentTimeOfDay
                                  ?.displayName ??
                              'Morning',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Time schedule preview
            const Text(
              'Time Schedule',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            ...theme_models.TimeOfDay.values.map((timeOfDay) {
              final timeRange = _getTimeRange(timeOfDay);
              final isActive =
                  themeProvider.themeSettings.currentTimeOfDay == timeOfDay;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isActive
                      ? Theme.of(context).primaryColor.withOpacity(0.1)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isActive
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getTimeOfDayIcon(timeOfDay),
                      size: 20,
                      color: isActive
                          ? Theme.of(context).primaryColor
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            timeOfDay.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                          ),
                          Text(
                            timeRange,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 16),

            // Manual time testing
            const Text(
              'Test Different Times',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              children: theme_models.TimeOfDay.values.map((timeOfDay) {
                return OutlinedButton(
                  onPressed: () => themeProvider.setTimeOfDay(timeOfDay),
                  child: Text(timeOfDay.displayName),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDynamicWeatherSettings(DynamicThemeProvider themeProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dynamic Weather-based Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Current weather display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.1),
                    Theme.of(context).primaryColor.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _getWeatherIcon(themeProvider.themeSettings.currentWeather),
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Weather Theme',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          themeProvider
                                  .themeSettings
                                  .currentWeather
                                  ?.displayName ??
                              'Sunny',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Weather condition testing
            const Text(
              'Test Different Weather Conditions',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: theme_models.WeatherCondition.values.map((weather) {
                final isActive =
                    themeProvider.themeSettings.currentWeather == weather;

                return InkWell(
                  onTap: () => themeProvider.setWeatherCondition(weather),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Theme.of(context).primaryColor.withOpacity(0.1)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActive
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _getWeatherIcon(weather),
                          size: 20,
                          color: isActive
                              ? Theme.of(context).primaryColor
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            weather.displayName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isActive
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Weather themes automatically change based on real weather conditions. Use the buttons above to preview different weather themes.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getThemeTypeIcon(theme_models.ThemeType themeType) {
    switch (themeType) {
      case theme_models.ThemeType.basic:
        return Icons.palette;
      case theme_models.ThemeType.animated:
        return Icons.animation;
      case theme_models.ThemeType.dynamicTime:
        return Icons.schedule;
      case theme_models.ThemeType.dynamicWeather:
        return Icons.cloud;
    }
  }

  IconData _getTimeOfDayIcon(theme_models.TimeOfDay? timeOfDay) {
    switch (timeOfDay) {
      case theme_models.TimeOfDay.sunrise:
        return Icons.wb_twilight;
      case theme_models.TimeOfDay.morning:
        return Icons.wb_sunny;
      case theme_models.TimeOfDay.afternoon:
        return Icons.light_mode;
      case theme_models.TimeOfDay.sunset:
        return Icons.wb_twilight;
      case theme_models.TimeOfDay.night:
        return Icons.nights_stay;
      default:
        return Icons.wb_sunny;
    }
  }

  IconData _getWeatherIcon(theme_models.WeatherCondition? weather) {
    switch (weather) {
      case theme_models.WeatherCondition.sunny:
        return Icons.wb_sunny;
      case theme_models.WeatherCondition.partlyCloudy:
        return Icons.cloud;
      case theme_models.WeatherCondition.cloudy:
        return Icons.cloud_queue;
      case theme_models.WeatherCondition.rainy:
        return Icons.umbrella;
      case theme_models.WeatherCondition.thunderstorm:
        return Icons.flash_on;
      case theme_models.WeatherCondition.snowy:
        return Icons.ac_unit;
      case theme_models.WeatherCondition.foggy:
        return Icons.foggy;
      default:
        return Icons.wb_sunny;
    }
  }

  String _getTimeRange(theme_models.TimeOfDay timeOfDay) {
    switch (timeOfDay) {
      case theme_models.TimeOfDay.sunrise:
        return '5:00 AM - 8:00 AM';
      case theme_models.TimeOfDay.morning:
        return '8:00 AM - 12:00 PM';
      case theme_models.TimeOfDay.afternoon:
        return '12:00 PM - 6:00 PM';
      case theme_models.TimeOfDay.sunset:
        return '6:00 PM - 8:00 PM';
      case theme_models.TimeOfDay.night:
        return '8:00 PM - 5:00 AM';
    }
  }
}
