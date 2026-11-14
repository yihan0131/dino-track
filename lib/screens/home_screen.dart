import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../repositories/user_repository.dart';
import '../models/user_model.dart';
import '../screens/recycling_guides_screen.dart';
import 'eco_challenges_screen.dart';

class HomeScreen extends StatefulWidget {
  final String username;
  final String userId;

  const HomeScreen({
    super.key,
    required this.username,
    required this.userId,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // User data
  int ecoPoints = 0;
  String dinoStage = "Egg";
  String petName = "Dino";
  String displayUsername = "";
  String nextStageLabel = "Cracked Egg";
  int pointsToNextStage = 50;
  bool isLoading = true;
  final UserRepository _userRepository = UserRepository();

  @override
  void initState() {
    super.initState();
    // Initialize displayUsername from widget parameter as fallback
    displayUsername = widget.username;
    _loadUserData();
    _loadPetName();
  }

  // Add a manual refresh method for pull-to-refresh
  Future<void> _refreshData() async {
    print(" Pull-to-refresh triggered");
    await _loadUserData(showLoadingIndicator: false);
  }

  // Load user data from Firebase
  Future<void> _loadUserData({bool showLoadingIndicator = true}) async {
    if (!mounted) return;

    if (showLoadingIndicator) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      User? user = await _userRepository.getUserData(widget.userId);
      if (!mounted) return;

      if (user != null) {
        // DEBUG: Log the user data to see what we're getting
        print("=== DEBUG USER DATA ===");
        print("User ID: ${user.id}");
        print("Username: ${user.username}");
        print("Eco Points: ${user.ecoPoints}");
        print("Dino Stage: ${user.dinoStage}");
        print("Has Unseen Level Up: ${user.hasUnseenLevelUp}");
        print("======================");

        setState(() {
          displayUsername = user.username; // Update display username from Firebase
          ecoPoints = user.ecoPoints;
          dinoStage = user.dinoStage;
          // If pet name was saved in Firebase, use it
          if (user.dinoName.isNotEmpty) {
            petName = user.dinoName;
          }
          _calculateNextStage();
          if (showLoadingIndicator) {
            isLoading = false;
          }
        });

        // Check for unseen level up and show popup with more logging
        print("Checking level up flag: ${user.hasUnseenLevelUp}");
        if (user.hasUnseenLevelUp == true) {
          print(" LEVEL UP DETECTED! Showing popup in 500ms...");
          final previousStage = _getPreviousStage(user.dinoStage);
          Future.delayed(const Duration(milliseconds: 500), () async {
            if (mounted) {
              await _clearLevelUpFlag();
              _showLevelUpDialog(previousStage, user.dinoStage);
            }
          });
        } else {
          print("ℹ No level up to show (flag is false or null)");
        }
      } else {
        print(" User data is null");
        if (!mounted) return;
        setState(() {
          if (showLoadingIndicator) {
            isLoading = false;
          }
        });
      }
    } catch (e) {
      print(" Error loading user data: $e");
      if (!mounted) return;
      setState(() {
        if (showLoadingIndicator) {
          isLoading = false;
        }
      });
    }
  }

  // Calculate next stage based on current points - with simplified next stage labels
  void _calculateNextStage() {
    if (ecoPoints < 50) {
      dinoStage = "Stage 1: Egg";
      nextStageLabel = "Crack"; // Simplified: removed "Stage 2:" prefix
      pointsToNextStage = 50;
    } else if (ecoPoints < 150) {
      dinoStage = "Stage 2: Cracked Egg";
      nextStageLabel = "Baby Dino"; // Simplified: removed "Stage 3:" prefix
      pointsToNextStage = 150;
    } else if (ecoPoints < 300) {
      dinoStage = "Stage 3: Baby Dino";
      nextStageLabel = "Teen Dino"; // Simplified: removed "Stage 4:" prefix
      pointsToNextStage = 300;
    } else if (ecoPoints < 500) {
      dinoStage = "Stage 4: Teen Dino";
      nextStageLabel = "Warrior"; // Simplified and shortened
      pointsToNextStage = 500;
    } else {
      dinoStage = "Stage 5: Eco Dino Warrior";
      nextStageLabel = "Max Level";
      pointsToNextStage = 500; // Maximum stage reached
    }
  }

  // This method returns the asset path based on the stage
  String _getDinoAssetPath(String stage) {
    if (stage.contains("Egg") && !stage.contains("Cracked")) {
      return 'assets/egg.png';
    } else if (stage.contains("Cracked Egg")) {
      return 'assets/cracked_egg.png';
    } else if (stage.contains("Baby Dino")) {
      return 'assets/baby_dino.png';
    } else if (stage.contains("Teen Dino")) {
      return 'assets/teen_dino.png';
    } else if (stage.contains("Eco Dino Warrior")) {
      return 'assets/warrior_dino.png';
    } else {
      return 'assets/egg.png';
    }
  }

  // This method returns the widget without setting a fixed height
  Widget _getDinoImageWidget(String stage) {
    return Image.asset(_getDinoAssetPath(stage));
  }

  // For backward compatibility, renamed to avoid duplicate definition
  Widget _getLegacyDinoImage(String stage) {
    return Image.asset(_getDinoAssetPath(stage), height: 220);
  }

  // Load pet name from shared preferences
  Future<void> _loadPetName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      // Use widget.username for storage keys (keep consistent)
      petName = prefs.getString('petName_${widget.username}') ?? "Dino";
    });
  }

  // Save pet name to shared preferences and Firebase
  Future<void> _savePetName(String name) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Use widget.username for storage keys (keep consistent)
    await prefs.setString('petName_${widget.username}', name);

    try {
      // Get current user data
      User? user = await _userRepository.getUserData(widget.userId);
      if (user != null) {
        // Update dino name
        User updatedUser = user.copyWith(dinoName: name);
        await _userRepository.updateUserData(updatedUser);
      }
    } catch (e) {
      print("Error saving pet name to Firebase: $e");
    }
  }

  // Show rename dialog
  void _showRenameDialog() {
    TextEditingController nameController = TextEditingController(text: petName);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Rename Your Pet"),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: "New Name",
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  petName = nameController.text;
                });
                _savePetName(nameController.text);
                Navigator.of(context).pop();
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // Show level up dialog
  void _showLevelUpDialog(String oldStage, String newStage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Your Dino Evolved!"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Your eco-friend has grown from $oldStage to $newStage!"),
              const SizedBox(height: 20),
              _getLegacyDinoImage(newStage),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Keep Going!"),
            ),
          ],
        );
      },
    );
  }

  // Clear the level up flag after showing popup
  Future<void> _clearLevelUpFlag() async {
    try {
      await _userRepository.clearLevelUpFlag(widget.userId);
    } catch (e) {
      print("Error clearing level up flag: $e");
    }
  }

  String _getPreviousStage(String currentStage) {
    switch (currentStage) {
      case 'Cracked Egg': return 'Egg';
      case 'Baby Dino': return 'Cracked Egg';
      case 'Teen Dino': return 'Baby Dino';
      case 'Eco Dino Warrior': return 'Teen Dino';
      default: return 'Egg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFCBD7CC),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Column(
                children: [
                  // Pet card - takes up top half of screen
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.58, // Slightly reduced height for pet card
                    width: double.infinity,
                    child: Column(
                      children: [
                        // Top part with background image - contains header and dinosaur
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: const BoxDecoration(
                              image: DecorationImage(
                                image: AssetImage('assets/pet_background.png'), // Replace with your image path
                                fit: BoxFit.cover,
                              ),
                            ),
                            width: double.infinity,
                            child: SafeArea(
                              bottom: false,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                                child: Column(
                                  children: [
                                    // Header with username - removed add points button
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        'Hello, $displayUsername',
                                        style: GoogleFonts.nunito(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                          shadows: [
                                            Shadow(
                                              offset: const Offset(1, 1),
                                              blurRadius: 3.0,
                                              color: Colors.black.withOpacity(0.5),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Expanded area for pet image
                                    Expanded(
                                      child: Center(
                                        child: _getDinoImageWidget(dinoStage),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Bottom part with white background - contains pet name, stage, and stats
                        // MODIFIED: Removed borderRadius to remove rounded corners
                        Expanded(
                          flex: 2,
                          child: Container(
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              // Removed borderRadius property to eliminate rounded corners
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                // Pet name with edit button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      petName,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: _showRenameDialog,
                                      child: const Icon(Icons.edit, size: 18),
                                    ),
                                  ],
                                ),

                                // Location or stage info
                                Text(
                                  dinoStage,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                ),

                                // Add more space between stage and stats
                                const SizedBox(height: 12),

                                // Stats row - UPDATED with simplified next stage label
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatContainer("Points", "$ecoPoints", Colors.amber.shade100),
                                    _buildStatContainer("Next Stage", nextStageLabel, Colors.green.shade100, width: 100), // Width reduced since labels are shorter now
                                    _buildStatContainer("Next", "$pointsToNextStage pts", Colors.blue.shade100),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Remaining content
                  Expanded(
                    flex: 3, // Reduced flex even more to make the container shorter
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0), // Removed horizontal padding
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          // Removed rounded corners
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.2),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Feature buttons
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  // Recycling & DIY Guides button
                                  Expanded(
                                    child: _buildFeatureButton(
                                      "Recycling &\nDIY Guides",
                                      Colors.blue.shade100,  // Changed to light blue
                                      imagePath: 'assets/recycle_guides.png',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => RecyclingGuidesScreen(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Eco-challenge button
                                  Expanded(
                                    child: _buildFeatureButton(
                                      "Eco-challenge",
                                      Colors.green.shade100,
                                      imagePath: 'assets/eco_challenge.png',
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => EcoChallengesScreen(userId: widget.userId),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

// Helper method for stat container with adjustable width
  Widget _buildStatContainer(String label, String value, Color backgroundColor, {double? width}) {
    return Container(
      width: width ?? 80, // Default to 80 if no width provided
      height: 80,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

// Helper method to build feature buttons
  Widget _buildFeatureButton(String text, Color color,
      {required VoidCallback onTap, String? imagePath}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 190, // Increased from 180 to make it even taller
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 16),
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
            ),
            if (imagePath != null)
              Align(
                alignment: Alignment.bottomRight,
                child: Image.asset(
                  imagePath,
                  height: 110, // Increased from 80 to make images larger
                  fit: BoxFit.contain,
                ),
              ),
          ],
        ),
      ),
    );
  }
}