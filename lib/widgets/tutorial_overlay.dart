import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialOverlay extends StatefulWidget {
  final Widget child;
  final List<TutorialStep> steps;
  final String tutorialKey;
  final VoidCallback? onComplete;

  const TutorialOverlay({
    super.key,
    required this.child,
    required this.steps,
    required this.tutorialKey,
    this.onComplete,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  int _currentStep = 0;
  bool _showTutorial = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _checkShouldShowTutorial();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _hideOverlay();
    super.dispose();
  }

  Future<void> _checkShouldShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial =
        prefs.getBool('tutorial_${widget.tutorialKey}') ?? false;

    if (!hasSeenTutorial && mounted) {
      // Wait for the first frame to be built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startTutorial();
      });
    }
  }

  void _startTutorial() {
    setState(() {
      _showTutorial = true;
      _currentStep = 0;
    });
    _showOverlay();
    _animationController.forward();
  }

  void _showOverlay() {
    _hideOverlay(); // Remove any existing overlay

    _overlayEntry = OverlayEntry(builder: (context) => _buildTutorialOverlay());

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _animationController.reset();
      _animationController.forward();
    } else {
      _completeTutorial();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _skipTutorial() {
    _completeTutorial();
  }

  Future<void> _completeTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_${widget.tutorialKey}', true);

    _animationController.reverse().then((_) {
      _hideOverlay();
      setState(() {
        _showTutorial = false;
      });
      widget.onComplete?.call();
    });
  }

  Widget _buildTutorialOverlay() {
    if (!_showTutorial || _currentStep >= widget.steps.length) {
      return const SizedBox.shrink();
    }

    final step = widget.steps[_currentStep];

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.black.withOpacity(0.7),
            child: Stack(
              children: [
                // Highlight area
                if (step.targetKey != null) _buildHighlightArea(step),

                // Tutorial content
                _buildTutorialContent(step),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightArea(TutorialStep step) {
    return CustomPaint(
      painter: HighlightPainter(
        targetKey: step.targetKey!,
        highlightRadius: step.highlightRadius,
      ),
      child: Container(),
    );
  }

  Widget _buildTutorialContent(TutorialStep step) {
    return Positioned(
      left: 24,
      right: 24,
      bottom: 100,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: step.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Step ${_currentStep + 1} of ${widget.steps.length}',
                      style: TextStyle(
                        color: step.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _skipTutorial,
                    child: const Text('Skip'),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Title
              Text(
                step.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                step.description,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 24),

              // Navigation buttons
              Row(
                children: [
                  if (_currentStep > 0)
                    OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: step.color),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Previous',
                        style: TextStyle(color: step.color),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: step.color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        _currentStep == widget.steps.length - 1
                            ? 'Finish'
                            : 'Next',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class TutorialStep {
  final String title;
  final String description;
  final GlobalKey? targetKey;
  final Color color;
  final double highlightRadius;

  TutorialStep({
    required this.title,
    required this.description,
    this.targetKey,
    this.color = Colors.blue,
    this.highlightRadius = 60.0,
  });
}

class HighlightPainter extends CustomPainter {
  final GlobalKey targetKey;
  final double highlightRadius;

  HighlightPainter({required this.targetKey, required this.highlightRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Get the target widget's position and size
    final RenderBox? renderBox =
        targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      // Calculate center of the target widget
      final center = Offset(
        position.dx + size.width / 2,
        position.dy + size.height / 2,
      );

      // Draw highlight circle
      canvas.drawCircle(center, highlightRadius, paint);
      canvas.drawCircle(center, highlightRadius, borderPaint);

      // Draw pulsing effect
      final pulsePaint = Paint()
        ..color = Colors.white.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      canvas.drawCircle(center, highlightRadius + 10, pulsePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Tutorial Manager for controlling tutorials across the app
class TutorialManager {
  static final TutorialManager _instance = TutorialManager._internal();
  factory TutorialManager() => _instance;
  TutorialManager._internal();

  static const String homeTutorialKey = 'home_tutorial';
  static const String roomTutorialKey = 'room_tutorial';
  static const String boardTutorialKey = 'board_tutorial';

  static Future<bool> shouldShowTutorial(String tutorialKey) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('tutorial_$tutorialKey') ?? false);
  }

  static Future<void> markTutorialCompleted(String tutorialKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_$tutorialKey', true);
  }

  static Future<void> resetAllTutorials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tutorial_$homeTutorialKey');
    await prefs.remove('tutorial_$roomTutorialKey');
    await prefs.remove('tutorial_$boardTutorialKey');
  }
}
