import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'home_container.dart';
import '../repositories/user_repository.dart';
import '../repositories/challenge_repository.dart';
import 'package:audioplayers/audioplayers.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final UserRepository _userRepository = UserRepository();
  final ChallengeRepository _challengeRepository = ChallengeRepository();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _playSound();
    _controller.forward();

    // Check authentication after animation completes
    Future.delayed(const Duration(seconds: 3), () {
      _checkAuthenticationAndNavigate();
    });
  }

  Future<void> _playSound() async {
    try {
      await _audioPlayer.play(AssetSource('splash_sound.mp3'));
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  // Enhanced method: Check if user is logged in and ensure database is initialized
  Future<void> _checkAuthenticationAndNavigate() async {
    try {
      // Check if user is already logged in
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        print("✅ User is already logged in: ${currentUser.email}");

        // User is logged in - get their data and ensure database is initialized
        try {
          // Get user data from Firestore
          final userData = await _userRepository.getCurrentUserData();

          if (userData != null) {
            print("✅ User data loaded successfully");

            // ✅ ENSURE DATABASE IS INITIALIZED (this is important for your challenges!)
            try {
              print("🗄️ Ensuring database is initialized after authentication...");
              await _challengeRepository.initializeDatabase();
              print("✅ Database initialization confirmed after authentication");
            } catch (e) {
              print("⚠️ Database initialization failed in splash: $e");
              // Continue anyway - app will still work, but some features might not be available
            }

            // Navigate to home screen with slide transition
            if (mounted) {
              Navigator.of(context).pushReplacement(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => HomeContainer(
                    username: userData.username,
                    userId: userData.id,
                  ),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;
                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(position: offsetAnimation, child: child);
                  },
                ),
              );
            }
          } else {
            print("⚠️ User data not found, redirecting to login");
            _navigateToLogin();
          }
        } catch (e) {
          print("❌ Error loading user data: $e");
          _navigateToLogin();
        }
      } else {
        print("ℹ️ No user logged in, redirecting to login");
        _navigateToLogin();
      }
    } catch (e) {
      print("❌ Error during authentication check: $e");
      _navigateToLogin();
    }
  }

  // Navigate to login screen with slide transition
  void _navigateToLogin() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            var offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Curves.elasticOut,
                ),
              ),
              child: Image.asset(
                'assets/dino_trash_logo.gif',
                height: 200,
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _controller,
              child: Text(
                'Dino Track',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.5, 1.0),
                ),
              ),
              child: Text(
                'Your friendly eco dinosaur',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}