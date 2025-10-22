import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referralCodeController = TextEditingController();
  bool _isLoading = false;
  bool _showReferralCode = false;

  @override
  void initState() {
    super.initState();
    _clearProblematicPreferences();
  }

  // Clear any preferences that might be causing issues
  Future<void> _clearProblematicPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    // Reset tutorial preferences to avoid cross-screen display
    await prefs.remove('has_seen_arrow_tutorial');

    // Also ensure any stale auth state is cleared
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      print('Clearing stale authentication session...');
      await Supabase.instance.client.auth.signOut();
    }

    print('Cleared problematic preferences and auth state');
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        print('Attempting login for: ${_emailController.text.trim()}');

        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        print('Login response received');
        print('User: ${response.user?.id}');
        final token = response.session?.accessToken;
        print(
          'Session: ${token != null && token.isNotEmpty ? "${token.substring(0, 20)}..." : "No token"}',
        );

        if (response.user != null && mounted) {
          print('Login successful, verifying user profile...');
          // Verify user profile exists in database before allowing access
          await _verifyUserProfileAndNavigate(response.user!);
        } else {
          print('Login failed: No user in response');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login failed: Invalid credentials'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } on AuthException catch (e) {
        print('AuthException: ${e.message}');
        if (mounted) {
          if (e.message.toLowerCase().contains('email not confirmed')) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Email Not Verified'),
                  content: const Text(
                    'Please check your email and click the verification link to activate your account. If you didn\'t receive the email, you can request a new one.',
                  ),
                  actions: <Widget>[
                    TextButton(
                      child: const Text('OK'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      child: const Text('Resend Email'),
                      onPressed: () async {
                        try {
                          await Supabase.instance.client.auth.resend(
                            type: OtpType.signup,
                            email: _emailController.text.trim(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Verification email sent!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.of(context).pop();
                          }
                        } catch (error) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: ${error.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            );
          } else if (e.message.toLowerCase().contains(
                'invalid login credentials',
              ) ||
              e.message.toLowerCase().contains('invalid email or password') ||
              e.message.toLowerCase().contains('email not found')) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Invalid email or password. Please check your credentials and try again.',
                ),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Login failed: ${e.message}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _joinHomeWithReferralCode() async {
    final referralCode = _referralCodeController.text.trim().toUpperCase();
    if (referralCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a referral code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Check if the referral code exists and is valid
      final shareResponse = await Supabase.instance.client
          .from('home_shares')
          .select('home_id, owner_id, expires_at')
          .eq('referral_code', referralCode)
          .eq('is_active', true)
          .maybeSingle();

      if (shareResponse == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid or expired referral code'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final expiresAt = DateTime.parse(shareResponse['expires_at']);
      if (expiresAt.isBefore(DateTime.now())) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This referral code has expired'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show dialog for user to login or register
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Join Home'),
            content: const Text(
              'To join this home, you need to login or create an account first. After logging in, you will automatically be added to the shared home.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Store referral code for after login
                  _storeReferralCodeForLater(referralCode);
                },
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _storeReferralCodeForLater(String referralCode) {
    // Store in shared preferences or similar for processing after login
    // For now, we'll just show a message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Login first, then use code: $referralCode'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _verifyUserProfileAndNavigate(User user) async {
    try {
      print('Verifying user profile for user: ${user.id}');

      // Check if user profile exists in the database
      final profileResponse = await Supabase.instance.client
          .from('user_profiles')
          .select('username, email')
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse == null) {
        print('No user profile found in database');
        // User authenticated but no profile exists - this shouldn't happen for valid users
        await Supabase.instance.client.auth.signOut();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Account not found. Please register first or contact support.',
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      print('User profile verified: ${profileResponse['username']}');
      // Profile exists, proceed with navigation
      await _checkAndNavigateAfterLogin();
    } catch (e) {
      print('Error verifying user profile: $e');

      // Sign out the user since verification failed
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login verification failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _checkAndNavigateAfterLogin() async {
    print('Checking navigation after login...');
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('hasSeenTutorial') ?? false;
    print('Has seen tutorial: $hasSeenTutorial');

    if (mounted) {
      if (!hasSeenTutorial) {
        print('Navigating to onboarding tutorial...');
        // First-time user - navigate to onboarding tutorial
        Navigator.of(context).pushReplacementNamed('/onboarding-tutorial');
      } else {
        print('Navigating to home...');
        // Returning user - go directly to home
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      print('Warning: Widget not mounted, skipping navigation');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Welcome Back',
                  style: GoogleFonts.montserrat(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Toggle for referral code
                Row(
                  children: [
                    Checkbox(
                      value: _showReferralCode,
                      onChanged: (value) {
                        setState(() {
                          _showReferralCode = value ?? false;
                        });
                      },
                    ),
                    const Text('I have a referral code'),
                  ],
                ),
                if (_showReferralCode) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _referralCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Referral Code',
                      hintText: 'Enter 8-character code',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 8,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : _joinHomeWithReferralCode,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Join Home with Code'),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Login'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                      child: const Text('Register now'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _referralCodeController.dispose();
    super.dispose();
  }
}
