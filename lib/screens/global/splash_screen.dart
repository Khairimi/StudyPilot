import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:study_app/screens/global/auth_screens.dart';
import 'package:study_app/studypilot/core/branding.dart';
import 'package:study_app/studypilot/core/theme/sp_colors.dart';
import 'package:study_app/studypilot/screens/shell/studypilot_shell.dart';

class SplashScreen extends StatefulWidget {
  /// Test hooks (tests run without Firebase): the initial sign-in state and
  /// the screen shown to a signed-in user.
  @visibleForTesting
  final Future<bool> Function()? isSignedInOverride;
  @visibleForTesting
  final Widget? signedInDestinationOverride;

  const SplashScreen({super.key, this.isSignedInOverride, this.signedInDestinationOverride});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    _routeAfterSplash();
  }

  /// Firebase restores a saved session asynchronously, so `currentUser` can
  /// briefly be null on web. The first auth event is the reliable answer.
  /// If it fails or never arrives, the user sees sign-in instead of a stuck splash.
  Future<bool> _isSignedIn() async {
    try {
      final user = await FirebaseAuth.instance.authStateChanges().first.timeout(const Duration(seconds: 10));
      return user != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _routeAfterSplash() async {
    final signedIn = (widget.isSignedInOverride ?? _isSignedIn)();
    await Future<void>.delayed(const Duration(seconds: 3));
    final isSignedIn = await signedIn;
    if (!mounted) return;

    final Widget destination = isSignedIn
        ? (widget.signedInDestinationOverride ?? const StudyPilotShell())
        : const AuthEntryScreen();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [SpColors.indigo500, SpColors.indigo700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      height: 120,
                      width: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.school_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  SpBrand.appName,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: Colors.white,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  SpBrand.tagline,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
