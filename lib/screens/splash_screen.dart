// lib/screens/splash_screen.dart
//
// Animated launch screen shown while CrimeProvider initialises.
// Uses a single AnimationController with two sub-animations on an
// Interval curve so the logo scales in first, then the tagline fades in.

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // Single controller drives both sub-animations
  late AnimationController _controller;

  // Scale animation: logo bounces from 50 % → 100 % in the first 60 % of the timeline
  late Animation<double> _scaleAnim;

  // Fade animation: tagline + name fades in during the last 70 % of the timeline
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Interval(0.0, 0.6) means this animation runs during t=0 to t=0.9s
    _scaleAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
    ).drive(Tween(begin: 0.5, end: 1.0));

    // Interval(0.3, 1.0) means the fade starts at t=0.45s (overlap with scale)
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
    );

    // Start the animation and navigate to HomeScreen when it finishes
    _controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const HomeScreen(),
            // Crossfade transition between splash and home
            transitionsBuilder: (_, anim, __, child) =>
                FadeTransition(opacity: anim, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose(); // always dispose controllers to avoid memory leaks
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Zimbabwe dark green background — matches the app bar colour
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Animated shield logo ───────────────────────────────────────
            ScaleTransition(
              scale: _scaleAnim,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🛡️', style: TextStyle(fontSize: 54)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── App name + tagline (fades in slightly after the logo) ──────
            FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  const Text(
                    'ZimCrimeWatch',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Public Safety Awareness',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 60),

            // ── Loading indicator ──────────────────────────────────────────
            FadeTransition(
              opacity: _fadeAnim,
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation(
                    Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
