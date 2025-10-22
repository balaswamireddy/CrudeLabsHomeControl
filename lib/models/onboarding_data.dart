import 'package:flutter/material.dart';

class OnboardingData {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> features;

  OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.features,
  });
}

class OnboardingContent {
  static List<OnboardingData> pages = [
    OnboardingData(
      title: "Welcome to Smart Switch",
      description:
          "Control your home's electrical switches remotely with ease and convenience.",
      icon: Icons.home_rounded,
      color: Colors.blue,
      features: [
        "Remote switch control",
        "Multiple home management",
        "Real-time monitoring",
        "Secure connection",
      ],
    ),
    OnboardingData(
      title: "Organize Your Homes",
      description:
          "Create and manage multiple homes, each with their own set of smart switches and boards.",
      icon: Icons.house,
      color: Colors.green,
      features: [
        "Multiple home support",
        "Custom home names",
        "Easy home switching",
        "Organized control",
      ],
    ),
    OnboardingData(
      title: "Connect Smart Boards",
      description:
          "Easily connect your ESP32 boards and switches to start controlling your devices.",
      icon: Icons.developer_board,
      color: Colors.orange,
      features: [
        "WiFi device scanning",
        "Quick board setup",
        "Multiple switch support",
        "Real-time sync",
      ],
    ),
    OnboardingData(
      title: "Smart Timers",
      description:
          "Schedule your switches with advanced timer features for automation and convenience.",
      icon: Icons.schedule,
      color: Colors.purple,
      features: [
        "Scheduled timers",
        "One-time scheduling",
        "Countdown timers",
        "Smart automation",
      ],
    ),
    OnboardingData(
      title: "Ready to Start!",
      description:
          "You're all set! Start by creating your first home and adding smart switches.",
      icon: Icons.rocket_launch,
      color: Colors.red,
      features: [
        "Create your first home",
        "Add smart boards",
        "Control switches",
        "Set up timers",
      ],
    ),
  ];
}
