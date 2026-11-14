import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  bool _showEmailLogin = false;
  bool _isSignUp = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Check if user document already exists
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        // If user document doesn't exist, create it
        if (!userDoc.exists) {
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'id': userCredential.user!.uid,
            'username': userCredential.user!.displayName ?? "User",
            'email': userCredential.user!.email ?? "",
            'ecoPoints': 0,
            'dinoName': "Eco Dino",
            'dinoStage': "Egg",
          });
        }

        _navigateToWelcomeScreen();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing in with Google: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signUpWithEmailPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await userCredential.user?.updateDisplayName(_nameController.text.trim());

      // Create user document in Firestore with the correct field names
      // matching your User model in user_model.dart
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user?.uid).set({
        'id': userCredential.user?.uid,
        'username': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'ecoPoints': 0,
        'level': 1,
        'dinoName': "Eco Dino",
        'dinoStage': "Egg",
      });

      _navigateToWelcomeScreen();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication error: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToWelcomeScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const WelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          return SlideTransition(position: offsetAnimation, child: child);
        },
      ),
    );
  }

  Future<void> _signInWithEmailPassword() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // Check if user document exists in Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      // If user document doesn't exist, create it
      if (!userDoc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'id': userCredential.user!.uid,
          'username': userCredential.user!.displayName ?? "User",
          'email': userCredential.user!.email ?? "",
          'ecoPoints': 0,
          'dinoName': "Eco Dino",
          'dinoStage': "Egg",
        });
      }

      _navigateToWelcomeScreen();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Authentication error: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleSignUp() {
    setState(() {
      _isSignUp = !_isSignUp;
      // Clear controllers when toggling between sign up and login
      _emailController.clear();
      _passwordController.clear();
      _nameController.clear();

      // Show email form for sign up
      _showEmailLogin = true;
    });
  }

  Future<void> _handleForgotPassword() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email address')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _auth.sendPasswordResetEmail(email: _emailController.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent. Please check your inbox.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send password reset email: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryGreen = const Color(0xFF4CAF50);

    return Scaffold(
      backgroundColor: Colors.amber.shade50,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),

                Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    color: Colors.brown.shade500,
                  ),
                ),
                const SizedBox(height: 20),

                // Choose between initial screen and email login screen
                _showEmailLogin
                    ? _buildEmailLoginForm(primaryGreen)
                    : _buildInitialScreen(primaryGreen),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialScreen(Color primaryGreen) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dinosaur image with speech bubble
          Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/dino_login.png',
                height: 190,
              ),
              Positioned(
                left: 5,
                top: 30,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text(
                    'Hi!',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),

          // Login with Email button
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _showEmailLogin = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            icon: const Icon(Icons.email, size: 20),
            label: const Text(
              'LOGIN WITH EMAIL',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 16),

          // Login with Google button
          OutlinedButton.icon(
            onPressed: _signInWithGoogle,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              side: const BorderSide(color: Colors.black),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            icon: Image.asset(
              'assets/google_logo.png',
              height: 20,
            ),
            label: const Text(
              'LOGIN WITH GOOGLE',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 20),

          // Sign up text
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Didn't have an account? ",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isSignUp = true;
                    _showEmailLogin = true;
                  });
                },
                child: Text(
                  "Sign Up",
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 30), // Added extra space at the bottom
        ],
      ),
    );
  }

  Widget _buildEmailLoginForm(Color primaryGreen) {
    // Make the container taller by adding more padding and spacing
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isSignUp ? 'Create an account :)' : 'Log in :)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 20),

          // Dinosaur image
          Image.asset(
            'assets/dino_login.png',
            height: 150,
          ),
          const SizedBox(height: 20),

          // Name field for signup
          if (_isSignUp)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
              ),
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Full Name',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: InputBorder.none,
                  icon: Icon(Icons.person, color: primaryGreen),
                ),
              ),
            ),

          // Email field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(25),
            ),
            child: TextField(
              controller: _emailController,
              decoration: InputDecoration(
                hintText: 'email@example.com',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: InputBorder.none,
                icon: Icon(Icons.email, color: primaryGreen),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ),

          const SizedBox(height: 12),

          // Password field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(25),
            ),
            child: TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                hintText: '',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: InputBorder.none,
                icon: Icon(Icons.key, color: primaryGreen),
              ),
              obscureText: true,
            ),
          ),

          const SizedBox(height: 20),

          // Login/SignUp button
          ElevatedButton(
            onPressed: _isLoading
                ? null
                : _isSignUp
                ? _signUpWithEmailPassword
                : _signInWithEmailPassword,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : Text(_isSignUp ? 'SIGN UP' : 'LOGIN WITH EMAIL'),
          ),

          const SizedBox(height: 16),

          // Forgot password or Toggle between login and signup
          _isSignUp
              ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Already have an account? ",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: _toggleSignUp,
                child: Text(
                  "Login",
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Forgot Password? ",
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: _handleForgotPassword,
                child: Text(
                  "Click Here",
                  style: TextStyle(
                    color: primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Back button
          TextButton(
            onPressed: () {
              setState(() {
                _showEmailLogin = false;
                _isSignUp = false;
              });
            },
            child: Text(
              '← Back to login options',
              style: TextStyle(
                color: primaryGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 10), // Extra space at the bottom
        ],
      ),
    );
  }
}
