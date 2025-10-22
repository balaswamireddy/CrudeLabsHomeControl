enum ThemeType {
  basic, // Plain light and dark themes
  animated, // Current beautiful animated themes
  dynamicTime, // Changes based on time of day
  dynamicWeather, // Changes based on weather conditions
}

enum TimeOfDay {
  sunrise, // 5AM - 8AM: Calm sunrise gradient
  morning, // 8AM - 12PM: Light sky with birds and clouds
  afternoon, // 12PM - 6PM: Bright sky with active clouds and birds
  sunset, // 6PM - 8PM: Beautiful sunset gradient
  night, // 8PM - 5AM: Dark sky with stars and falling stars
}

enum WeatherCondition {
  sunny, // Bright sun theme
  partlyCloudy, // Normal sky with more clouds
  cloudy, // Dim and moody theme
  rainy, // Animated rain theme
  thunderstorm, // Rain with thunder and lightning
  snowy, // Snow falling theme
  foggy, // Misty/foggy theme
}

class ThemeSettings {
  final ThemeType themeType;
  final bool isDarkMode; // For basic themes
  final TimeOfDay? currentTimeOfDay;
  final WeatherCondition? currentWeather;
  final bool autoSwitchByTime; // For dynamic time themes
  final bool autoSwitchByWeather; // For dynamic weather themes
  final String? weatherApiKey; // For weather integration

  const ThemeSettings({
    required this.themeType,
    this.isDarkMode = false,
    this.currentTimeOfDay,
    this.currentWeather,
    this.autoSwitchByTime = true,
    this.autoSwitchByWeather = true,
    this.weatherApiKey,
  });

  ThemeSettings copyWith({
    ThemeType? themeType,
    bool? isDarkMode,
    TimeOfDay? currentTimeOfDay,
    WeatherCondition? currentWeather,
    bool? autoSwitchByTime,
    bool? autoSwitchByWeather,
    String? weatherApiKey,
  }) {
    return ThemeSettings(
      themeType: themeType ?? this.themeType,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      currentTimeOfDay: currentTimeOfDay ?? this.currentTimeOfDay,
      currentWeather: currentWeather ?? this.currentWeather,
      autoSwitchByTime: autoSwitchByTime ?? this.autoSwitchByTime,
      autoSwitchByWeather: autoSwitchByWeather ?? this.autoSwitchByWeather,
      weatherApiKey: weatherApiKey ?? this.weatherApiKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeType': themeType.index,
      'isDarkMode': isDarkMode,
      'currentTimeOfDay': currentTimeOfDay?.index,
      'currentWeather': currentWeather?.index,
      'autoSwitchByTime': autoSwitchByTime,
      'autoSwitchByWeather': autoSwitchByWeather,
      'weatherApiKey': weatherApiKey,
    };
  }

  factory ThemeSettings.fromJson(Map<String, dynamic> json) {
    return ThemeSettings(
      themeType: ThemeType.values[json['themeType'] ?? 0],
      isDarkMode: json['isDarkMode'] ?? false,
      currentTimeOfDay: json['currentTimeOfDay'] != null
          ? TimeOfDay.values[json['currentTimeOfDay']]
          : null,
      currentWeather: json['currentWeather'] != null
          ? WeatherCondition.values[json['currentWeather']]
          : null,
      autoSwitchByTime: json['autoSwitchByTime'] ?? true,
      autoSwitchByWeather: json['autoSwitchByWeather'] ?? true,
      weatherApiKey: json['weatherApiKey'],
    );
  }
}

// Extension to get display names
extension ThemeTypeExtension on ThemeType {
  String get displayName {
    switch (this) {
      case ThemeType.basic:
        return 'Basic Themes';
      case ThemeType.animated:
        return 'Animated Themes';
      case ThemeType.dynamicTime:
        return 'Dynamic Time-based';
      case ThemeType.dynamicWeather:
        return 'Dynamic Weather-based';
    }
  }

  String get description {
    switch (this) {
      case ThemeType.basic:
        return 'Simple light and dark themes without animations';
      case ThemeType.animated:
        return 'Beautiful day and night scenes with animations';
      case ThemeType.dynamicTime:
        return 'Themes change automatically based on time of day';
      case ThemeType.dynamicWeather:
        return 'Themes change based on real weather conditions';
    }
  }
}

extension TimeOfDayExtension on TimeOfDay {
  String get displayName {
    switch (this) {
      case TimeOfDay.sunrise:
        return 'Sunrise';
      case TimeOfDay.morning:
        return 'Morning';
      case TimeOfDay.afternoon:
        return 'Afternoon';
      case TimeOfDay.sunset:
        return 'Sunset';
      case TimeOfDay.night:
        return 'Night';
    }
  }
}

extension WeatherConditionExtension on WeatherCondition {
  String get displayName {
    switch (this) {
      case WeatherCondition.sunny:
        return 'Sunny';
      case WeatherCondition.partlyCloudy:
        return 'Partly Cloudy';
      case WeatherCondition.cloudy:
        return 'Cloudy';
      case WeatherCondition.rainy:
        return 'Rainy';
      case WeatherCondition.thunderstorm:
        return 'Thunderstorm';
      case WeatherCondition.snowy:
        return 'Snowy';
      case WeatherCondition.foggy:
        return 'Foggy';
    }
  }
}
