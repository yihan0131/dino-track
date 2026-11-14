import 'package:flutter/material.dart';
import 'goals_list_screen.dart';
import 'recycling_record_screen.dart';

class GoalScreen extends StatelessWidget {
  final String userId;

  const GoalScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),

                // Goals Title
                Text(
                  "Goals",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                SizedBox(height: 16),

                // Set Goal
                _buildTaskCard(
                  context,
                  title: "Set Goal",
                  description: "Set eco-friendly goals and track your daily progress",
                  icon: "assets/set_goal.png",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GoalsListScreen(userId: userId),
                      ),
                    );
                  },
                ),

                SizedBox(height: 16),

                // Record Recycling
                _buildTaskCard(
                  context,
                  title: "Record Recycling Effort",
                  description: "Log the types and amounts of materials you have recycled",
                  icon: "assets/record_recycling_effort.png",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RecyclingRecordsPage(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(
      BuildContext context, {
        required String title,
        required String description,
        required String icon,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/goal_bg.png"),
            fit: BoxFit.cover,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF18562D),
              ),
            ),
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(height: 12),

            // Image - positioned on the right with much larger size
            Container(
              width: double.infinity,
              alignment: Alignment.centerRight,
              child: Image.asset(
                icon,
                height: 180,  // Doubled height
                width: 180,   // Doubled width
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    width: 200,
                    alignment: Alignment.center,
                    child: Text(
                      "Image not found",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Placeholder screen for navigations
class PlaceholderScreen extends StatelessWidget {
  final String title;
  final String userId;

  const PlaceholderScreen({super.key, required this.title, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Color(0xFF5E8C43),
      ),
      body: Center(
        child: Text(
          "$title Screen\nThis is a placeholder for $title functionality",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}