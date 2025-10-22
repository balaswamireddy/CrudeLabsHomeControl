import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/theme_models.dart' as theme_models;

class DynamicThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'theme_settings';
  static const String _weatherApiKey =
      'your_openweather_api_key'; // Replace with actual API key

  theme_models.ThemeSettings _themeSettings = const theme_models.ThemeSettings(
    themeType: theme_models.ThemeType.basic,
    isDarkMode: false,
    currentTimeOfDay: theme_models.TimeOfDay.morning,
    currentWeather: theme_models.WeatherCondition.sunny,
  );

  Timer? _timeUpdateTimer;
  Timer? _weatherUpdateTimer;
  bool _isInitialized = false;

  DynamicThemeProvider() {
    _initializeProvider();
  }

  theme_models.ThemeSettings get themeSettings => _themeSettings;

  bool get isDarkMode {
    switch (_themeSettings.themeType) {
      case theme_models.ThemeType.basic:
        return _themeSettings.isDarkMode;
      case theme_models.ThemeType.animated:
        return _themeSettings.isDarkMode;
      case theme_models.ThemeType.dynamicTime:
        return _isDarkTimeOfDay(_themeSettings.currentTimeOfDay);
      case theme_models.ThemeType.dynamicWeather:
        return _isDarkWeather(_themeSettings.currentWeather);
    }
  }

  String get backgroundType {
    final type = switch (_themeSettings.themeType) {
      theme_models.ThemeType.basic => 'basic',
      theme_models.ThemeType.animated => 'animated',
      theme_models.ThemeType.dynamicTime => _getTimeBasedBackground(),
      theme_models.ThemeType.dynamicWeather => _getSimpleWeatherBackground(),
    };

    debugPrint(
      '🚨 THEME DEBUG: backgroundType=$type, themeType=${_themeSettings.themeType}, isDarkMode=${_themeSettings.isDarkMode}',
    );
    return type;
  }

  Future<void> _initializeProvider() async {
    if (_isInitialized) return;

    await _loadSettings();
    await _setupLocationPermissions();
    _startTimeUpdates();
    await _updateCurrentTime();

    if (_themeSettings.themeType == theme_models.ThemeType.dynamicWeather) {
      _startWeatherUpdates();
      await _updateWeather();
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_prefsKey);

      if (settingsJson != null) {
        final settingsMap = jsonDecode(settingsJson) as Map<String, dynamic>;
        _themeSettings = theme_models.ThemeSettings.fromJson(settingsMap);
      }
    } catch (e) {
      debugPrint('Error loading theme settings: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, jsonEncode(_themeSettings.toJson()));
    } catch (e) {
      debugPrint('Error saving theme settings: $e');
    }
  }

  Future<void> _setupLocationPermissions() async {
    if (_themeSettings.themeType != theme_models.ThemeType.dynamicWeather)
      return;

    try {
      final status = await Permission.location.request();
      if (status.isGranted) {
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          debugPrint('Location services are disabled.');
        }
      }
    } catch (e) {
      debugPrint('Error setting up location permissions: $e');
    }
  }

  void _startTimeUpdates() {
    _timeUpdateTimer?.cancel();
    _timeUpdateTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_themeSettings.themeType == theme_models.ThemeType.dynamicTime &&
          _themeSettings.autoSwitchByTime) {
        _updateCurrentTime();
      }
    });
  }

  void _startWeatherUpdates() {
    _weatherUpdateTimer?.cancel();
    _weatherUpdateTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (_themeSettings.themeType == theme_models.ThemeType.dynamicWeather &&
          _themeSettings.autoSwitchByWeather) {
        _updateWeather();
      }
    });
  }

  Future<void> _updateCurrentTime() async {
    final now = DateTime.now();
    final hour = now.hour;

    theme_models.TimeOfDay newTimeOfDay;
    if (hour >= 5 && hour < 8) {
      newTimeOfDay = theme_models.TimeOfDay.sunrise;
    } else if (hour >= 8 && hour < 12) {
      newTimeOfDay = theme_models.TimeOfDay.morning;
    } else if (hour >= 12 && hour < 18) {
      newTimeOfDay = theme_models.TimeOfDay.afternoon;
    } else if (hour >= 18 && hour < 20) {
      newTimeOfDay = theme_models.TimeOfDay.sunset;
    } else {
      newTimeOfDay = theme_models.TimeOfDay.night;
    }

    if (_themeSettings.currentTimeOfDay != newTimeOfDay) {
      _themeSettings = _themeSettings.copyWith(currentTimeOfDay: newTimeOfDay);
      await _saveSettings();
      notifyListeners();
    }
  }

  Future<void> _updateWeather() async {
    try {
      final position = await _getCurrentPosition();
      if (position != null) {
        final weather = await _fetchWeatherData(
          position.latitude,
          position.longitude,
        );
        if (weather != null && weather != _themeSettings.currentWeather) {
          _themeSettings = _themeSettings.copyWith(currentWeather: weather);
          await _saveSettings();
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error updating weather: $e');
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final hasPermission = await Permission.location.isGranted;
      if (!hasPermission) return null;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Error getting current position: $e');
      return null;
    }
  }

  Future<theme_models.WeatherCondition?> _fetchWeatherData(
    double lat,
    double lon,
  ) async {
    try {
      // Using OpenWeatherMap API (free tier)
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_weatherApiKey';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final weatherId = data['weather'][0]['id'] as int;
        return _mapWeatherIdToCondition(weatherId);
      }
    } catch (e) {
      debugPrint('Error fetching weather data: $e');
      // Fallback to mock weather for demo purposes
      return _getMockWeather();
    }
    return null;
  }

  theme_models.WeatherCondition _mapWeatherIdToCondition(int weatherId) {
    // OpenWeatherMap weather condition IDs mapping
    if (weatherId >= 200 && weatherId < 300) {
      return theme_models.WeatherCondition.thunderstorm;
    } else if (weatherId >= 300 && weatherId < 600) {
      return theme_models.WeatherCondition.rainy;
    } else if (weatherId >= 600 && weatherId < 700) {
      return theme_models.WeatherCondition.snowy;
    } else if (weatherId >= 700 && weatherId < 800) {
      return theme_models.WeatherCondition.foggy;
    } else if (weatherId == 800) {
      return theme_models.WeatherCondition.sunny;
    } else if (weatherId > 800 && weatherId < 803) {
      return theme_models.WeatherCondition.partlyCloudy;
    } else {
      return theme_models.WeatherCondition.cloudy;
    }
  }

  // Mock weather for testing/demo purposes
  theme_models.WeatherCondition _getMockWeather() {
    // For demo purposes, return sunny weather instead of random
    // This prevents random lightning effects in normal animated mode
    return theme_models.WeatherCondition.sunny;
  }

  bool _isDarkTimeOfDay(theme_models.TimeOfDay? timeOfDay) {
    switch (timeOfDay) {
      case theme_models.TimeOfDay.night:
        return true;
      case theme_models.TimeOfDay.sunset:
        return false; // Sunset has its own beautiful gradient
      default:
        return false;
    }
  }

  bool _isDarkWeather(theme_models.WeatherCondition? weather) {
    switch (weather) {
      case theme_models.WeatherCondition.thunderstorm:
      case theme_models.WeatherCondition.foggy:
        return true;
      case theme_models.WeatherCondition.cloudy:
      case theme_models.WeatherCondition.rainy:
        return false; // These have their own moody themes
      default:
        return false;
    }
  }

  String _getTimeBasedBackground() {
    switch (_themeSettings.currentTimeOfDay) {
      case theme_models.TimeOfDay.sunrise:
        return 'sunrise';
      case theme_models.TimeOfDay.morning:
        return 'animated'; // Bright day scene
      case theme_models.TimeOfDay.afternoon:
        return 'sunny';
      case theme_models.TimeOfDay.sunset:
        return 'sunset';
      case theme_models.TimeOfDay.night:
        return 'animated'; // Night sky with stars
      default:
        return 'animated';
    }
  }

  String _getSimpleWeatherBackground() {
    switch (_themeSettings.currentWeather) {
      case theme_models.WeatherCondition.sunny:
        return 'sunny';
      case theme_models.WeatherCondition.partlyCloudy:
      case theme_models.WeatherCondition.cloudy:
        return 'cloudy';
      case theme_models.WeatherCondition.rainy:
        return 'rainy';
      case theme_models.WeatherCondition.thunderstorm:
        return 'thunderstorm'; // Use specific thunderstorm background
      case theme_models.WeatherCondition.snowy:
        return 'cloudy'; // Use cloudy instead of complex snow
      case theme_models.WeatherCondition.foggy:
        return 'foggy';
      default:
        return 'animated';
    }
  }

  // Public methods for updating themes
  Future<void> updateThemeType(theme_models.ThemeType themeType) async {
    debugPrint('🎛️ updateThemeType called: NEW themeType=$themeType');
    _themeSettings = _themeSettings.copyWith(themeType: themeType);
    await _saveSettings();

    // Setup appropriate timers based on theme type
    if (themeType == theme_models.ThemeType.dynamicTime) {
      _startTimeUpdates();
      await _updateCurrentTime();
    } else if (themeType == theme_models.ThemeType.dynamicWeather) {
      _startWeatherUpdates();
      await _updateWeather();
    } else {
      _timeUpdateTimer?.cancel();
      _weatherUpdateTimer?.cancel();
    }

    debugPrint(
      '✅ updateThemeType completed: themeType=${_themeSettings.themeType}',
    );
    notifyListeners();
  }

  Future<void> updateBasicTheme(bool isDarkMode) async {
    debugPrint(
      '🔥 updateBasicTheme called: isDarkMode=$isDarkMode, currentThemeType=${_themeSettings.themeType}',
    );
    _themeSettings = _themeSettings.copyWith(
      isDarkMode: isDarkMode,
      themeType: theme_models.ThemeType.basic, // FORCE basic theme
    );
    await _saveSettings();
    debugPrint(
      '✅ updateBasicTheme completed: new themeType=${_themeSettings.themeType}, new isDarkMode=${_themeSettings.isDarkMode}',
    );
    notifyListeners();
  }

  Future<void> updateDarkMode(bool isDarkMode) async {
    debugPrint(
      'updateDarkMode called: isDarkMode=$isDarkMode, currentThemeType=${_themeSettings.themeType}',
    );
    _themeSettings = _themeSettings.copyWith(isDarkMode: isDarkMode);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setTimeOfDay(theme_models.TimeOfDay timeOfDay) async {
    _themeSettings = _themeSettings.copyWith(currentTimeOfDay: timeOfDay);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> setWeatherCondition(
    theme_models.WeatherCondition weather,
  ) async {
    _themeSettings = _themeSettings.copyWith(currentWeather: weather);
    await _saveSettings();
    notifyListeners();
  }

  Future<void> updateAutoSwitchByTime(bool autoSwitch) async {
    _themeSettings = _themeSettings.copyWith(autoSwitchByTime: autoSwitch);
    await _saveSettings();

    if (autoSwitch &&
        _themeSettings.themeType == theme_models.ThemeType.dynamicTime) {
      _startTimeUpdates();
      await _updateCurrentTime();
    } else {
      _timeUpdateTimer?.cancel();
    }

    notifyListeners();
  }

  Future<void> updateAutoSwitchByWeather(bool autoSwitch) async {
    _themeSettings = _themeSettings.copyWith(autoSwitchByWeather: autoSwitch);
    await _saveSettings();

    if (autoSwitch &&
        _themeSettings.themeType == theme_models.ThemeType.dynamicWeather) {
      _startWeatherUpdates();
      await _updateWeather();
    } else {
      _weatherUpdateTimer?.cancel();
    }

    notifyListeners();
  }

  Future<void> updateWeatherApiKey(String apiKey) async {
    _themeSettings = _themeSettings.copyWith(weatherApiKey: apiKey);
    await _saveSettings();

    if (_themeSettings.themeType == theme_models.ThemeType.dynamicWeather) {
      await _updateWeather();
    }

    notifyListeners();
  }

  // Force refresh weather data
  Future<void> refreshWeather() async {
    if (_themeSettings.themeType == theme_models.ThemeType.dynamicWeather) {
      await _updateWeather();
    }
  }

  // Force refresh time-based theme
  Future<void> refreshTimeTheme() async {
    if (_themeSettings.themeType == theme_models.ThemeType.dynamicTime) {
      await _updateCurrentTime();
    }
  }

  @override
  void dispose() {
    _timeUpdateTimer?.cancel();
    _weatherUpdateTimer?.cancel();
    super.dispose();
  }
}
