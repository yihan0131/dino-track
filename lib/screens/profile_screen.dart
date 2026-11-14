import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'dart:io';
import '../repositories/user_repository.dart';
import '../service/cloudinary_service.dart';
import '../models/user_model.dart';
import '../screens/login_screen.dart';
import '../screens/admin_panel_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final UserRepository _userRepository = UserRepository();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final TextEditingController _usernameController = TextEditingController();
  User? currentUser;
  bool isLoading = true;
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final userData = await _userRepository.getCurrentUserData();
      if (userData != null) {
        setState(() {
          currentUser = userData;
          _usernameController.text = userData.username;
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateUsername() async {
    if (_usernameController.text.trim().isEmpty) {
      _showErrorDialog("Username cannot be empty");
      return;
    }

    if (_usernameController.text.trim() == currentUser?.username) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      isUpdating = true;
    });

    try {
      // copyWith keeps every other field (isAdmin, processedReports, ...).
      // Building a new User here used to reset them to their defaults.
      final updatedUser = currentUser!.copyWith(
        username: _usernameController.text.trim(),
      );

      await _userRepository.updateUserData(updatedUser);

      setState(() {
        currentUser = updatedUser;
        isUpdating = false;
      });

      if (!mounted) return;
      Navigator.pop(context);
      _showSuccessSnackBar("Username updated successfully!");
    } catch (e) {
      setState(() {
        isUpdating = false;
      });
      _showErrorDialog("Failed to update username: $e");
    }
  }

  Future<void> _changeProfileImage() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Change Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageOption(
                  Icons.camera_alt,
                  'Camera',
                      () => _pickImage(ImageSource.camera),
                ),
                _buildImageOption(
                  Icons.photo_library,
                  'Gallery',
                      () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildImageOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 32,
              color: const Color(0xFF4CAF50),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // Close bottom sheet

    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image != null) {
      setState(() {
        isUpdating = true;
      });

      try {
        // Upload image to Cloudinary
        final imageUrl = await _cloudinaryService.uploadImage(
          File(image.path),
          'profile_images',
        );

        // Update user data
        // copyWith keeps every other field (isAdmin, processedReports, ...).
        final updatedUser = currentUser!.copyWith(profileImageUrl: imageUrl);

        await _userRepository.updateUserData(updatedUser);

        setState(() {
          currentUser = updatedUser;
          isUpdating = false;
        });

        _showSuccessSnackBar("Profile picture updated successfully!");
      } catch (e) {
        setState(() {
          isUpdating = false;
        });
        _showErrorDialog("Failed to update profile picture: $e");
      }
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext); // Close the dialog
              try {
                await auth.FirebaseAuth.instance.signOut();
                if (mounted) {
                  // Use the screen's context: the dialog's context is gone after pop
                  Navigator.pushAndRemoveUntil(
                    this.context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                  );
                }
              } catch (e) {
                _showErrorDialog("Failed to logout: $e");
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showEditUsernameDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Edit Username'),
        content: TextField(
          controller: _usernameController,
          decoration: InputDecoration(
            labelText: 'Username',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            prefixIcon: const Icon(Icons.person),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _usernameController.text = currentUser?.username ?? '';
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isUpdating ? null : _updateUsername,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: isUpdating
                ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Error'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: isLoading
          ? Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF81C784),
              Color(0xFFA5D6A7),
            ],
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      )
          : Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF81C784),
              Color(0xFFA5D6A7),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Profile Section with Decorative Background
              Stack(
                children: [
                  // Trees and Mountains (Decorations)
                  Positioned(
                    left: 30,
                    top: 20,
                    child: Icon(
                      Icons.park,
                      color: Colors.white.withOpacity(0.3),
                      size: 40,
                    ),
                  ),
                  Positioned(
                    right: 30,
                    top: 40,
                    child: Icon(
                      Icons.park,
                      color: Colors.white.withOpacity(0.3),
                      size: 35,
                    ),
                  ),
                  Positioned(
                    right: 50,
                    top: 10,
                    child: Icon(
                      Icons.terrain,
                      color: Colors.white.withOpacity(0.4),
                      size: 50,
                    ),
                  ),

                  // Profile Info
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 40),
                    width: MediaQuery.of(context).size.width,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.2),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child: currentUser?.profileImageUrl != null &&
                                    currentUser!.profileImageUrl!.isNotEmpty
                                    ? Image.network(
                                  currentUser!.profileImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (isUpdating)
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.5),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          currentUser?.username ?? 'User',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Menu Options
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMenuItem(
                        Icons.edit,
                        'Edit Username',
                        Colors.orange,
                        _showEditUsernameDialog,
                      ),
                      const Divider(height: 32),
                      _buildMenuItem(
                        Icons.camera_alt,
                        'Change Profile Picture',
                        Colors.blue,
                        _changeProfileImage,
                      ),
                      const Divider(height: 32),
                      if (currentUser?.isAdmin == true) ...[
                        const Divider(height: 32),
                        _buildMenuItem(
                          Icons.admin_panel_settings,
                          'Admin Panel',
                          Colors.deepPurple,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminPanelScreen(),
                            ),
                          ),
                        ),
                      ],
                      const Divider(height: 32),
                      _buildMenuItem(
                        Icons.logout,
                        'Logout',
                        Colors.red,
                        _logout,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildMenuItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
}