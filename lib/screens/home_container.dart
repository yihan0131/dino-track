import 'package:flutter/material.dart';
// Import your page screens here
import 'home_screen.dart';
import 'map_screen.dart';
import 'goal_screen.dart';
import 'profile_screen.dart';

 //ProfileScreen will be imported when they're created

class HomeContainer extends StatefulWidget {
  final String username;
  final String userId;

  const HomeContainer({
    super.key,
    required this.username,
    required this.userId
  });

  @override
  State<HomeContainer> createState() => _HomeContainerState();
}

class _HomeContainerState extends State<HomeContainer> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _selectedIndex == 0
          ? HomeScreen(username: widget.username, userId: widget.userId)
          : _selectedIndex == 1
          ? MapScreen()
          : _selectedIndex == 2
          ? GoalScreen(userId: widget.userId)
          : ProfilePage(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed, // Important for 4+ items
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          _buildNavItem(Icons.home, 'Home'),
          _buildNavItem(Icons.map, 'Map'),
          _buildNavItem(Icons.emoji_events, 'Goals'),
          _buildNavItem(Icons.person, 'Profile'),
        ],
      ),
    );
  }

  // Helper method to build navigation items
  BottomNavigationBarItem _buildNavItem(IconData icon, String label) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
        ),
        child: Icon(icon),
      ),
      label: label,
    );
  }
}