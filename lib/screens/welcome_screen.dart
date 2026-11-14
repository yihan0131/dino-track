import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../repositories/user_repository.dart';
import '../repositories/challenge_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_container.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.forward();

    // Add database initialization here
    _initializeDatabase();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Add this method for database initialization
  Future<void> _initializeDatabase() async {
    try {
      final challengeRepository = ChallengeRepository();
      // Check if database is already initialized
      final challengesSnapshot = await FirebaseFirestore.instance.collection('eco_challenges').limit(1).get();

      if (challengesSnapshot.docs.isEmpty) {
        await challengeRepository.initializeDatabase();
        print("Database successfully initialized with sample data");
      } else {
        print("Database already contains data, skipping initialization");
      }
    } catch (e) {
      print("Error initializing database: $e");
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error initializing database: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _animation,
                child: Image.asset(
                  'assets/recycle_animation.gif',
                  height: 250,
                  width: 250,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('=== GIF LOADING ERROR ===');
                    print('Error: $error');
                    print('Stack trace: $stackTrace');
                    print('Attempted path: assets/recycle_animation.gif');
                    print('========================');
                    return Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.red,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'GIF Not Found',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Check console for details',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(_animation),
                child: FadeTransition(
                  opacity: _animation,
                  child: Text(
                    "Let's Start Recycling with Dino!",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                      fontFamily: 'Roboto', // Use system font
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.3, 1.0),
                  ),
                ),
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _controller,
                    curve: const Interval(0.3, 1.0),
                  ),
                  child: Text(
                    "Every small action counts. Join Dino Trash on a mission to make our planet cleaner!",
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF5A7A5A),
                      fontFamily: 'Roboto', // Use system font
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 60), // Space before button
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: _controller,
                  curve: const Interval(0.7, 1.0),
                ),
                child: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      String username = "User"; // Default fallback username

                      try {
                        final userRepository = UserRepository();
                        final userData = await userRepository.getCurrentUserData();

                        String username = "User"; // Default fallback

                        if (userData != null) {
                          print("User data type: ${userData.runtimeType}");
                          print("Username from user data: ${userData.username}");
                          username = userData.username;

                          // Make sure username is not empty
                          if (username.isEmpty) {
                            username = "User";
                          }
                        } else {
                          print("User data is null, using default username");
                        }

                        // Navigate with the proper username
                        if (!context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                HomeContainer(
                                  username: username,
                                  userId: FirebaseAuth.instance.currentUser?.uid ?? '', // Add userId here
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
                      } catch (e) {
                        print("Error getting user data: $e");
                        // Fallback to default if there's an error
                        if (!context.mounted) return;
                        Navigator.of(context).pushReplacement(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) =>
                                HomeScreen(
                                  username: username, // Make sure this variable is defined before this line
                                  userId: FirebaseAuth.instance.currentUser?.uid ?? '',
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
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(200, 48),
                      backgroundColor: const Color(0xFFB8E6B8), // Soft mint green
                      foregroundColor: const Color(0xFF2E7D32), // Darker green text for contrast
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}