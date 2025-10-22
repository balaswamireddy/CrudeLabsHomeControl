import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
//import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          _buildSection(context, 'Appearance', [
            _buildThemeSettingsTile(context),
          ]),
          _buildSection(context, 'Help & Support', [
            _buildOnboardingTile(context),
            _buildAboutTile(context),
          ]),
          _buildSection(context, 'Account', [_buildLogoutTile(context)]),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  Widget _buildThemeSettingsTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.palette),
      title: const Text('Advanced Themes'),
      subtitle: const Text('Dynamic themes, time-based, weather-based'),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: () {
        Navigator.pushNamed(context, '/theme-settings');
      },
    );
  }

  Widget _buildOnboardingTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.help_outline),
      title: const Text('View Tutorial'),
      subtitle: const Text('Learn how to use Smart Switch'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        );
      },
    );
  }

  Widget _buildAboutTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('About'),
      subtitle: const Text('Smart Switch v1.0.0'),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('About Smart Switch'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Smart Switch v1.0.0'),
                SizedBox(height: 8),
                Text('Developed by CrudeLabs'),
                SizedBox(height: 8),
                Text('Control your home switches remotely with ease.'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.logout, color: Colors.red),
      title: const Text('Logout', style: TextStyle(color: Colors.red)),
      subtitle: const Text('Sign out from your account'),
      onTap: () async {
        final shouldLogout = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Logout'),
              ),
            ],
          ),
        );

        if (shouldLogout == true) {
          try {
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              // Navigate to login screen and clear navigation stack
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (route) => false);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error logging out: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      },
    );
  }
}
