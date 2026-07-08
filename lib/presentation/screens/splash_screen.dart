import 'package:flutter/material.dart';
import 'package:habit_flow/presentation/screens/home_screen.dart'; 
import 'package:habit_flow/presentation/screens/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  final bool hasSeenOnboarding;

  const SplashScreen({super.key, required this.hasSeenOnboarding});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    
    // 1. Animation Timer Setup 
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // 2. Bounce Effect 
    _scaleAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack)
    );

    // 3. Fade In Effect 
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn)
    );

    // 4. Animation Shuru Karo
    _controller.forward();

    // 5. Thik 2.5 second baad agle screen par bhej do
    Future.delayed(const Duration(milliseconds: 2500), () {
      _navigateToNextScreen();
    });
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) return;

    // Don't navigate if we're no longer the top route. An alarm's AlarmScreen
    // may have been pushed on top of us while this 2.5s timer was pending —
    // replacing the current route here would wipe out the alarm UI.
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => widget.hasSeenOnboarding
            ? const HomeScreen()
            : const OnboardingScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        // 🚨 NATIVE FLUTTER ANIMATION
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacityAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // --- Custom Logo Design ---
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ]
                      ),
                      child: Icon(
                        Icons.check_circle_rounded, // Habit tick icon
                        size: 80,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // --- App Name ---
                    Text(
                      "Habitick",
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.primary,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // --- Tagline ---
                    Text(
                      "Build Better Habits",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        ),
      ),
    );
  }
}