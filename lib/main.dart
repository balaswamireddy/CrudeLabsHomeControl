import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen_new.dart';
import 'screens/settings_screen.dart';
import 'screens/onboarding_tutorial_screen.dart';
import 'theme/app_theme.dart';
import 'theme/glassmorphism_theme_fixed.dart';
import 'providers/dynamic_theme_provider.dart';
import 'widgets/dynamic_background_widget.dart';
import 'pages/theme_settings_page.dart';
import 'models/theme_models.dart' as theme_models;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase - NEW PROJECT CREDENTIALS
  await Supabase.initialize(
    url: 'https://iotsupabase.myqrmart.com',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzYwOTcwMDY2LCJleHAiOjIwNzYzMzAwNjZ9.bLY8rFo1pJndr_6XNsugIorxgVTGGIOJL193mhQZ-o8',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DynamicThemeProvider(),
      child: Consumer<DynamicThemeProvider>(
        builder: (context, dynamicThemeProvider, child) {
          // For basic theme, use proper Material theme mode for text colors
          final useBasicThemeMode =
              dynamicThemeProvider.themeSettings.themeType ==
              theme_models.ThemeType.basic;

          return MaterialApp(
            title: 'Smart Home',
            theme: GlassmorphismTheme.enhanceTheme(AppTheme.lightTheme),
            darkTheme: GlassmorphismTheme.enhanceTheme(AppTheme.darkTheme),
            // Use themeMode only for basic theme to get proper text colors
            themeMode: useBasicThemeMode
                ? (dynamicThemeProvider.isDarkMode
                      ? ThemeMode.dark
                      : ThemeMode.light)
                : ThemeMode.light, // Always light for animated themes
            initialRoute: '/',
            onGenerateRoute: (settings) {
              Widget page;
              switch (settings.name) {
                case '/':
                  page = const SplashScreen();
                  break;
                case '/onboarding':
                  page = const OnboardingScreen();
                  break;
                case '/onboarding-tutorial':
                  page = const OnboardingTutorialScreen();
                  break;
                case '/login':
                  page = const LoginScreen();
                  break;
                case '/register':
                  page = const RegisterScreen();
                  break;
                case '/home':
                  page = const HomeScreen();
                  break;
                case '/settings':
                  page = const SettingsScreen();
                  break;
                case '/theme-settings':
                  page = const ThemeSettingsPage();
                  break;
                default:
                  page = const SplashScreen();
              }
              return PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    DynamicBackgroundWidget(child: page),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      const begin = Offset(1.0, 0.0);
                      const end = Offset.zero;
                      const curve = Curves.easeInOutCubic;
                      var tween = Tween(
                        begin: begin,
                        end: end,
                      ).chain(CurveTween(curve: curve));
                      var offsetAnimation = animation.drive(tween);
                      return SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      );
                    },
                transitionDuration: const Duration(milliseconds: 300),
              );
            },
          );
        },
      ),
    );
  }
}
