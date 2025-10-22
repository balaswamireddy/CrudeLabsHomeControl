import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../providers/dynamic_theme_provider.dart';

class OnboardingTutorialScreen extends StatefulWidget {
  const OnboardingTutorialScreen({super.key});

  @override
  State<OnboardingTutorialScreen> createState() =>
      _OnboardingTutorialScreenState();
}

class _OnboardingTutorialScreenState extends State<OnboardingTutorialScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _currentPage = 0;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: "Welcome to SmartSwitch",
      description:
          "Take control of your home with intelligent switch management. Let's get you started!",
      icon: Icons.home_rounded,
      color: Colors.blue,
    ),
    OnboardingStep(
      title: "Create Your Home",
      description:
          "First, create a home profile to organize all your smart devices in one place.",
      icon: Icons.add_home,
      color: Colors.green,
      tutorialText: "Tap the '+' button to add your first home",
    ),
    OnboardingStep(
      title: "Organize with Rooms",
      description:
          "Group your devices by rooms like Living Room, Bedroom, Kitchen for better organization.",
      icon: Icons.meeting_room,
      color: Colors.purple,
      tutorialText: "Click 'Add Room' to create different areas in your home",
    ),
    OnboardingStep(
      title: "Add Smart Boards",
      description:
          "Connect your ESP32 smart switch boards to control multiple switches wirelessly.",
      icon: Icons.developer_board,
      color: Colors.orange,
      tutorialText: "Use 'Scan WiFi' to find and connect your smart boards",
    ),
    OnboardingStep(
      title: "Control Your Switches",
      description:
          "Turn lights, fans, and other devices on/off remotely. Set timers and schedules.",
      icon: Icons.toggle_on,
      color: Colors.red,
      tutorialText: "Tap any switch card to toggle devices instantly",
    ),
    OnboardingStep(
      title: "Share & Collaborate",
      description:
          "Share home access with family members so everyone can control the devices.",
      icon: Icons.group,
      color: Colors.teal,
      tutorialText: "Use the share button to invite family members",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);

    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DynamicThemeProvider>(
      builder: (context, themeProvider, child) {
        final isBasicTheme = themeProvider.backgroundType == 'basic';
        final isDark = themeProvider.isDarkMode;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Header with skip button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Getting Started',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isBasicTheme
                                ? (isDark ? Colors.white : Colors.black87)
                                : Colors.white,
                          ),
                        ),
                        TextButton(
                          onPressed: _skipOnboarding,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: isBasicTheme
                                  ? (isDark ? Colors.white70 : Colors.black54)
                                  : Colors.white.withOpacity(0.8),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: LinearProgressIndicator(
                      value: (_currentPage + 1) / _steps.length,
                      backgroundColor: isBasicTheme
                          ? (isDark ? Colors.grey[700] : Colors.grey[300])
                          : Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _steps[_currentPage].color,
                      ),
                    ),
                  ),

                  // Page content
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemCount: _steps.length,
                      itemBuilder: (context, index) {
                        return _buildOnboardingPage(
                          _steps[index],
                          isBasicTheme,
                          isDark,
                        );
                      },
                    ),
                  ),

                  // Bottom navigation
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        // Page indicators
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            _steps.length,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentPage == index ? 12 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? _steps[_currentPage].color
                                    : isBasicTheme
                                    ? (isDark
                                          ? Colors.grey[600]
                                          : Colors.grey[400])
                                    : Colors.white.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Navigation buttons
                        Row(
                          children: [
                            if (_currentPage > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    _pageController.previousPage(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: isBasicTheme
                                          ? (isDark
                                                ? Colors.white
                                                : Colors.black87)
                                          : Colors.white,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                  child: Text(
                                    'Previous',
                                    style: TextStyle(
                                      color: isBasicTheme
                                          ? (isDark
                                                ? Colors.white
                                                : Colors.black87)
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            if (_currentPage > 0) const SizedBox(width: 16),
                            Expanded(
                              flex: _currentPage == 0 ? 1 : 1,
                              child: ElevatedButton(
                                onPressed: _nextPage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _steps[_currentPage].color,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  _currentPage == _steps.length - 1
                                      ? 'Get Started'
                                      : 'Next',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOnboardingPage(
    OnboardingStep step,
    bool isBasicTheme,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: isBasicTheme
                ? (isDark
                      ? Colors.grey[900]!.withOpacity(0.85)
                      : Colors.white.withOpacity(0.85))
                : Colors.white.withOpacity(0.15),
            border: Border.all(
              color: isBasicTheme
                  ? (isDark
                        ? Colors.grey[700]!.withOpacity(0.5)
                        : Colors.grey[300]!.withOpacity(0.5))
                  : Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon with animation
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 800),
                    tween: Tween(begin: 0.0, end: 1.0),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: step.color.withOpacity(0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: step.color.withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                          child: Icon(step.icon, size: 60, color: step.color),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 48),

                  // Title
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: isBasicTheme
                          ? (isDark ? Colors.white : Colors.black87)
                          : Colors.white,
                      shadows: !isBasicTheme
                          ? [
                              Shadow(
                                offset: const Offset(1, 1),
                                blurRadius: 3,
                                color: Colors.black.withOpacity(0.3),
                              ),
                            ]
                          : null,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Description
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: isBasicTheme
                          ? (isDark
                                ? Colors.white.withOpacity(0.8)
                                : Colors.black.withOpacity(0.7))
                          : Colors.white.withOpacity(0.9),
                      shadows: !isBasicTheme
                          ? [
                              Shadow(
                                offset: const Offset(1, 1),
                                blurRadius: 2,
                                color: Colors.black.withOpacity(0.2),
                              ),
                            ]
                          : null,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Tutorial text (if available)
                  if (step.tutorialText != null) ...[
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: step.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: step.color.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            color: step.color,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              step.tutorialText!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isBasicTheme
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.white,
                                shadows: !isBasicTheme
                                    ? [
                                        Shadow(
                                          offset: const Offset(1, 1),
                                          blurRadius: 2,
                                          color: Colors.black.withOpacity(0.2),
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String? tutorialText;

  OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.tutorialText,
  });
}
