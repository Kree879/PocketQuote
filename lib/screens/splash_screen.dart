import 'package:flutter/material.dart';
import '../widgets/auth_wrapper.dart';

class CustomSplashScreen extends StatefulWidget {
  const CustomSplashScreen({super.key});

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 10.0, end: 45.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Show splash for 3 seconds as requested
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthWrapper()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Using precisely #0A1128 as requested for perfect baton-pass transition
    const backgroundColor = Color(0xFF0A1128);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Logo with Pulsing Glow
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withAlpha((_glowAnimation.value * 4).toInt().clamp(0, 255)),
                        blurRadius: _glowAnimation.value * 2.0,
                        spreadRadius: _glowAnimation.value / 1.2,
                      ),
                    ],
                  ),
                  child: child,
                );
              },
              child: Image.asset(
                'assets/icon/app_icon.png',
                width: 400, // Doubled size from 200
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 48), // Increased spacing for larger assets
            // 2. Slogan Text
            Text(
              'Instant quotes from your Pocket',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withAlpha(220),
                    fontSize: 40, // Doubled size from 20)
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
