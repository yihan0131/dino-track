import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recycling_goal.dart';
import '../repositories/goal_repository.dart';
import '../service/notification_service.dart';


class GoalDetailScreen extends StatefulWidget {
  final String userId;
  final String goalId;

  const GoalDetailScreen({
    super.key,
    required this.userId,
    required this.goalId,
  });

  @override
  _GoalDetailScreenState createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  final GoalRepository _goalRepository = GoalRepository();
  RecyclingGoal? goal;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGoalDetails();
  }

  // Check if the goal should be completed today (not any other day)
  bool _shouldCompleteToday() {
    if (goal == null) return false;
    return goal!.shouldCompleteOnDate(DateTime.now());
  }

  Future<void> _loadGoalDetails() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Load all goals for the user and find the specific one
      List<RecyclingGoal> goals = await _goalRepository.getUserRecyclingGoals(
          widget.userId);

      for (var g in goals) {
        if (g.id == widget.goalId) {
          setState(() {
            goal = g;
            isLoading = false;
          });
          break;
        }
      }

      if (goal == null) {
        // Handle case where goal is not found
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading goal details: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  // NEW: Navigate to edit goal screen
  void _editGoal() {
    if (goal == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditGoalScreen(
              userId: widget.userId,
              goal: goal!,
            ),
      ),
    ).then((result) {
      // Reload goal details when returning from edit screen
      if (result == true) {
        _loadGoalDetails();
      }
    });
  }

  // Calculate total expected amount based on frequency and duration
  double _calculateTotalExpectedAmount() {
    if (goal == null) return 0.0;
    return goal!.getTotalExpectedAmount();
  }

  // Calculate progress percentage based on total expected amount
  double _calculateProgressPercentage() {
    if (goal == null) return 0.0;
    return goal!.getCompletionRate();
  }

  // Check if goal was completed on a specific date using real data
  bool _shouldCompleteOnDate(DateTime date) {
    if (goal == null) return false;
    return goal!.shouldCompleteOnDate(date);
  }

  Future<bool> _hasCheckedInToday() async {
    if (goal == null) return false;
    return await _goalRepository.hasCheckedInToday(goal!.id);
  }

  // Check if goal was completed on a specific date - simplified and more reliable
  bool _wasCompletedOnDate(DateTime date) {
    if (goal == null) return false;
    return goal!.wasCompletedOnDate(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Goal Details'),
        backgroundColor: Color(0xFF5E8C43),
        actions: [
          // NEW: Edit button
          if (goal != null && !goal!.completed)
            IconButton(
              icon: Icon(Icons.edit),
              onPressed: _editGoal,
              tooltip: 'Edit Goal',
            ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: goal == null ? null : () {
              _showDeleteConfirmation();
            },
            tooltip: 'Delete Goal',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : goal == null
          ? Center(child: Text('Goal not found'))
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGoalHeader(),
              SizedBox(height: 24),
              _buildProgressSection(),

              if (!goal!.completed && _shouldCompleteToday())
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: FutureBuilder<bool>(
                          future: _hasCheckedInToday(),
                          builder: (context, snapshot) {
                            bool hasCheckedIn = snapshot.data ?? false;

                            if (hasCheckedIn) {
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: Color(0xFF5E8C43).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Color(0xFF5E8C43).withOpacity(
                                          0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Color(0xFF5E8C43), size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Completed today',
                                      style: TextStyle(
                                        color: Color(0xFF5E8C43),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    // Use recordDailyCheckIn instead of updateGoalProgress
                                    await _goalRepository.recordDailyCheckIn(
                                        goal!.id, goal!.targetAmount);

                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            '✅ Checked in successfully!'),
                                        backgroundColor: Color(0xFF5E8C43),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              10),
                                        ),
                                      ),
                                    );

                                    await _loadGoalDetails(); // Refresh
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                              10),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                icon: Icon(Icons.add),
                                label: Text('Check-in Today'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF5E8C43),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

              SizedBox(height: 24),
              _buildCompletionCalendar(),

              //  Reminder Information Section
              if (goal!.reminderEnabled || goal!.reminderTime != null)
                SizedBox(height: 24),
              if (goal!.reminderEnabled || goal!.reminderTime != null)
                _buildReminderInfoSection(),

              SizedBox(height: 24),
              _buildGoalDetails(),
            ],
          ),
        ),
      ),
    );
  }

  //Build reminder information section
  Widget _buildReminderInfoSection() {
    if (goal == null) return SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  color: Color(0xFF5E8C43),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Reminder Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Roboto', // Different font
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            if (goal!.reminderEnabled && goal!.reminderTime != null) ...[
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFF5E8C43).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(0xFF5E8C43).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      color: Color(0xFF5E8C43),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reminders Enabled',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Color(0xFF5E8C43),
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Daily reminder at ${_formatReminderTime(
                                goal!.reminderTime!)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _getReminderFrequencyDescription(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              ...[
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_off,
                        color: Colors.grey[600],
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'No reminders set',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }

  // NEW: Format reminder time for display
  String _formatReminderTime(DateTime reminderTime) {
    return TimeOfDay.fromDateTime(reminderTime).format(context);
  }

  // NEW: Get reminder frequency description
  String _getReminderFrequencyDescription() {
    if (goal == null) return '';

    switch (goal!.frequency.toLowerCase()) {
      case 'daily':
        return 'You\'ll receive a reminder every day';
      case 'weekly':
        List<String> dayNames = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        int selectedDayIndex = goal!.selectedDays.indexOf(true);
        if (selectedDayIndex != -1) {
          return 'You\'ll receive a reminder every ${dayNames[selectedDayIndex]}';
        }
        return 'You\'ll receive weekly reminders';
      case 'custom':
        int selectedDaysCount = goal!
            .selectedDays
            .where((day) => day)
            .length;
        if (selectedDaysCount == 1) {
          return 'You\'ll receive a reminder once per week';
        }
        if (selectedDaysCount == 7) {
          return 'You\'ll receive a reminder every day';
        }
        return 'You\'ll receive reminders $selectedDaysCount days per week';
      default:
        return 'You\'ll receive reminders based on your goal frequency';
    }
  }

  Widget _buildGoalHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                goal?.title ?? 'Unknown Goal',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: goal!.completed
                    ? Colors.green.shade100
                    : Colors.amber.shade100,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                goal!.completed ? 'Completed' : 'In Progress',
                style: TextStyle(
                  color: goal!.completed
                      ? Colors.green.shade800
                      : Colors.amber.shade800,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          goal?.description ?? '',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Icon(
              Icons.date_range,
              size: 16,
              color: Colors.grey.shade600,
            ),
            SizedBox(width: 6),
            Text(
              '${DateFormat('MMM d, yyyy').format(
                  goal?.startDate ?? DateTime.now())} - ${DateFormat(
                  'MMM d, yyyy').format(goal?.endDate ?? DateTime.now())}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.repeat,
              size: 16,
              color: Colors.grey.shade600,
            ),
            SizedBox(width: 6),
            Text(
              '${goal?.frequency ?? 'Unknown'} frequency',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            SizedBox(width: 12),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Color(0xFF5E8C43).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${goal?.targetAmount ?? 0} ${goal?.unit ??
                    ''} per ${_getFrequencyLabel()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5E8C43),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getFrequencyLabel() {
    if (goal == null) return 'occurrence';

    switch (goal!.frequency.toLowerCase()) {
      case 'daily':
        return 'day';
      case 'weekly':
        return 'week';
      case 'custom':
        return 'occurrence';
      default:
        return 'occurrence';
    }
  }

  Widget _buildProgressSection() {
    final progressPercentage = _calculateProgressPercentage();
    final totalExpectedAmount = _calculateTotalExpectedAmount();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),

            // Target progress with updated logic
            Text(
              'Target Progress',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${goal?.progress ?? 0}/${totalExpectedAmount.toStringAsFixed(
                      1)} ${goal?.unit ?? ''}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
                Text(
                  '${(progressPercentage * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: progressPercentage >= 0.8
                        ? Color(0xFF5E8C43)
                        : Colors.orange,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
            LinearProgressIndicator(
              value: progressPercentage,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                progressPercentage >= 0.8
                    ? Color(0xFF5E8C43)
                    : Colors.orange,
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),

            // Information about frequency
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue.shade700,
                    size: 16,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your goal is to recycle ${goal?.targetAmount ?? 0} ${goal
                          ?.unit ?? ''} ${_getFrequencyDescription()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Points eligibility status
            SizedBox(height: 16),
            _buildPointsEligibilityStatus(),
          ],
        ),
      ),
    );
  }

  String _getFrequencyDescription() {
    if (goal == null) return '';

    switch (goal!.frequency.toLowerCase()) {
      case 'daily':
        return 'every day';
      case 'weekly':
        return 'every week';
      case 'custom':
        int selectedDays = goal!
            .selectedDays
            .where((day) => day)
            .length;
        return '$selectedDays times per week';
      default:
        return '';
    }
  }

  Widget _buildPointsEligibilityStatus() {
    if (goal == null) return SizedBox();

    bool isEligible = goal!.completed
        ? goal!.pointsAwarded // If completed, check if points were awarded
        : _isEligibleForPoints(); // If not completed, check current eligibility

    // Determine the appropriate message
    String message;
    String? subMessage;

    DateTime now = DateTime.now();
    bool goalHasEnded = goal!.completed || now.isAfter(goal!.endDate);

    if (goalHasEnded) {
      if (goal!.pointsAwarded) {
        message = 'Earned 10 eco points!';
      } else {
        if (isEligible) {
          message = 'Eligible for 10 eco points!';
          subMessage = 'Goal ended successfully with 80%+ completion rate';
        } else {
          message = 'Goal ended - no points earned';
          int actualCompletions = goal!.completedActions;

          // Calculate final completion rate for ended goals
          final durationDays = goal!.endDate.difference(goal!.startDate).inDays;
          int totalExpectedCompletions = 0;
          switch (goal!.frequency.toLowerCase()) {
            case 'daily':
              totalExpectedCompletions = durationDays;
              break;
            case 'weekly':
              totalExpectedCompletions = (durationDays / 7).floor();
              break;
            case 'custom':
              int selectedDaysPerWeek = goal!.selectedDays.where((day) => day).length;
              totalExpectedCompletions = (durationDays / 7 * selectedDaysPerWeek).floor();
              break;
          }

          if (actualCompletions < 3) {
            subMessage = 'Only $actualCompletions completions (needed 3+)';
          } else if (totalExpectedCompletions > 0) {
            double finalRate = actualCompletions / totalExpectedCompletions;
            subMessage = 'Final completion rate: ${(finalRate * 100).toInt()}% (needed 80%)';
          } else {
            subMessage = 'Did not meet point requirements';
          }
        }
      }
    } else {
      // Goal is still ongoing
      if (isEligible) {
        // Check if user is currently on track
        int expectedCompletionsByNow = _calculateExpectedCompletionsByDate(now);
        int actualCompletions = goal!.completedActions;

        if (expectedCompletionsByNow >= 3) {
          double currentRate = expectedCompletionsByNow > 0 ? actualCompletions / expectedCompletionsByNow : 0.0;
          if (currentRate >= 0.8) {
            message = 'On track to earn 10 eco points!';
            subMessage = 'Keep up the great work to maintain 80% completion rate';
          } else {
            message = 'At risk of not earning points';
            subMessage = 'Current completion rate: ${(currentRate * 100).toInt()}% (need 80%)';
          }
        } else {
          message = 'Could earn 10 eco points when completed';
          subMessage = 'Must maintain 80% completion rate';
        }
      } else {
        message = 'Not eligible for eco points';
        // Determine why not eligible
        final durationDays = goal!.endDate.difference(goal!.startDate).inDays;
        if (durationDays < 7) {
          subMessage = 'Goal must be at least 7 days long';
        } else {
          int expectedCompletions = 0;
          switch (goal!.frequency.toLowerCase()) {
            case 'daily':
              expectedCompletions = durationDays;
              break;
            case 'weekly':
              expectedCompletions = (durationDays / 7).floor();
              break;
            case 'custom':
              int selectedDaysPerWeek = goal!.selectedDays.where((day) => day).length;
              expectedCompletions = (durationDays / 7 * selectedDaysPerWeek).floor();
              break;
          }
          if (expectedCompletions < 3) {
            subMessage = 'Goal must allow for at least 3 completions';
          } else {
            subMessage = 'Must maintain 80% completion rate with at least 3 completions';
          }
        }
      }
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isEligible ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isEligible ? Colors.green.shade200 : Colors.amber.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isEligible ? Icons.check_circle : Icons.info_outline,
            color: isEligible ? Colors.green : Colors.amber.shade800,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isEligible ? Colors.green.shade700 : Colors.amber.shade800,
                  ),
                ),
                if (subMessage != null) ...[
                  SizedBox(height: 4),
                  Text(
                    subMessage,
                    style: TextStyle(
                      fontSize: 12,
                      color: isEligible ? Colors.green.shade600 : Colors.amber.shade800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


// Updated _isEligibleForPoints method that checks actual performance
  bool _isEligibleForPoints() {
    if (goal == null) return false;

    // Check duration - at least 7 days
    final durationDays = goal!.endDate.difference(goal!.startDate).inDays;
    if (durationDays < 7) return false;

    // Calculate expected completions
    int expectedCompletions = 0;
    switch (goal!.frequency.toLowerCase()) {
      case 'daily':
        expectedCompletions = durationDays;
        break;
      case 'weekly':
        expectedCompletions = (durationDays / 7).floor();
        break;
      case 'custom':
        int selectedDaysPerWeek = goal!.selectedDays.where((day) => day).length;
        expectedCompletions = (durationDays / 7 * selectedDaysPerWeek).floor();
        break;
    }

    // Check if can have at least 3 completions
    if (expectedCompletions < 3) return false;

    DateTime now = DateTime.now();
    if (goal!.startDate.isBefore(now) || goal!.startDate.isAtSameMomentAs(now)) {
      // Get actual completions
      int actualCompletions = goal!.completedActions;

      // Check if goal has ended (either marked completed OR end date has passed)
      bool goalHasEnded = goal!.completed || now.isAfter(goal!.endDate);

      if (goalHasEnded) {
        // For ended goals, use total expected completions for the entire duration
        double completionRate = expectedCompletions > 0 ? actualCompletions / expectedCompletions : 0.0;
        return actualCompletions >= 3 && completionRate >= 0.8;
      } else {
        // For ongoing goals, calculate expected completions by now
        int expectedCompletionsByNow = _calculateExpectedCompletionsByDate(now);

        // Only apply completion rate requirement if enough time has passed for meaningful assessment
        if (expectedCompletionsByNow >= 3) {
          double currentCompletionRate = expectedCompletionsByNow > 0 ? actualCompletions / expectedCompletionsByNow : 0.0;
          return actualCompletions >= 3 && currentCompletionRate >= 0.8;
        } else {
          // Not enough time has passed for meaningful completion rate assessment
          // Just check if it has potential to be eligible
          return expectedCompletions >= 3;
        }
      }
    }

    // Goal hasn't started yet - check if it has potential to be eligible
    return expectedCompletions >= 3;
  }

// Helper method to calculate expected completions by a specific date
  int _calculateExpectedCompletionsByDate(DateTime date) {
    if (goal == null) return 0;

    DateTime startDate = goal!.startDate;
    DateTime endDate = goal!.endDate;
    DateTime targetDate = date.isAfter(endDate) ? endDate : date;

    if (targetDate.isBefore(startDate)) return 0;

    int daysSinceStart = targetDate.difference(startDate).inDays + 1; // +1 to include start date

    switch (goal!.frequency.toLowerCase()) {
      case 'daily':
        return daysSinceStart;
      case 'weekly':
        return (daysSinceStart / 7).floor();
      case 'custom':
        int selectedDaysPerWeek = goal!.selectedDays.where((day) => day).length;
        return (daysSinceStart / 7 * selectedDaysPerWeek).floor();
      default:
        return 0;
    }
  }


  Widget _buildCompletionCalendar() {
    final DateTime now = DateTime.now();
    final int daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final int firstWeekday = DateTime(now.year, now.month, 1).weekday % 7;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Completion Calendar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('MMMM yyyy').format(now),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Weekday headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                'S', 'M', 'T', 'W', 'T', 'F', 'S'
              ].map((day) =>
                  SizedBox(
                    width: 30,
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  )).toList(),
            ),
            SizedBox(height: 8),

            // Calendar grid with REAL data (NO CHECKMARKS)
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: firstWeekday + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday) {
                  return SizedBox(); // Empty cells before the first day
                }

                final day = index - firstWeekday + 1;
                final date = DateTime(now.year, now.month, day);

                // Use real data instead of guessing
                final bool shouldComplete = _shouldCompleteOnDate(date);
                final bool wasCompleted = _wasCompletedOnDate(date);

                // Determine cell appearance based on REAL data
                Color cellColor = Colors.transparent;
                Color textColor = Colors.black;

                if (shouldComplete) {
                  DateTime today = DateTime.now();
                  DateTime todayNormalized = DateTime(
                      today.year, today.month, today.day);
                  DateTime dateNormalized = DateTime(
                      date.year, date.month, date.day);

                  if (dateNormalized.isBefore(todayNormalized) ||
                      dateNormalized.isAtSameMomentAs(todayNormalized)) {
                    // Past or today - show actual completion status
                    if (wasCompleted) {
                      cellColor = Color(0xFF5E8C43).withOpacity(
                          0.4); // Green for completed
                      textColor = Colors.green.shade800;
                    } else {
                      cellColor = Colors.red.shade100; // Red for missed
                      textColor = Colors.red.shade800;
                    }
                  } else {
                    // Future date that should be completed
                    cellColor = Colors.grey.shade200;
                    textColor = Colors.grey.shade600;
                  }
                }

                // Today's date gets a border
                final isToday = date.day == DateTime
                    .now()
                    .day &&
                    date.month == DateTime
                        .now()
                        .month &&
                    date.year == DateTime
                        .now()
                        .year;

                return Container(
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(4),
                    border: isToday
                        ? Border.all(color: Color(0xFF5E8C43), width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: isToday ? FontWeight.bold : FontWeight
                            .normal,
                      ),
                    ),
                  ),
                );
              },
            ),

            SizedBox(height: 16),

            // Updated legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCalendarLegendItem(
                    Color(0xFF5E8C43).withOpacity(0.4), "Completed"),
                SizedBox(width: 12),
                _buildCalendarLegendItem(Colors.red.shade100, "Missed"),
                SizedBox(width: 12),
                _buildCalendarLegendItem(Colors.grey.shade200, "Scheduled"),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildGoalDetails() {
    if (goal == null) return SizedBox();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Goal Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Serif',
                letterSpacing: 0.5,
              ),
            ),
            SizedBox(height: 16),
            _buildDetailRow('Target', '${goal!.targetAmount} ${goal!
                .unit} per ${_getFrequencyLabel()}'),
            _buildDetailRow('Total Expected',
                '${_calculateTotalExpectedAmount().toStringAsFixed(1)} ${goal!
                    .unit}'),
            _buildDetailRow(
                'Current Progress', '${goal!.progress} ${goal!.unit}'),
            _buildDetailRow('Frequency', goal!.frequency),
            if (goal!.frequency.toLowerCase() == 'custom')
              _buildSelectedDaysRow(goal!.selectedDays),
            _buildDetailRow('Start Date',
                DateFormat('MMMM d, yyyy').format(goal!.startDate)),
            _buildDetailRow(
                'End Date', DateFormat('MMMM d, yyyy').format(goal!.endDate)),
            _buildDetailRow('Completed Actions', '${goal!.completedActions}'),
            _buildDetailRow(
                'Status', goal!.completed ? 'Completed' : 'In Progress'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDaysRow(List<bool> selectedDays) {
    final List<String> dayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              'Active Days',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 4.0, // Horizontal spacing between items
              runSpacing: 4.0, // Vertical spacing between lines
              children: List.generate(7, (index) {
                return Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selectedDays[index]
                        ? Color(0xFF5E8C43)
                        : Colors.grey[200],
                  ),
                  child: Center(
                    child: Text(
                      dayLabels[index],
                      style: TextStyle(
                        color: selectedDays[index]
                            ? Colors.white
                            : Colors.grey[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Delete Goal'),
          content: Text(
              'Are you sure you want to delete this goal? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Close the dialog first
                Navigator.of(dialogContext).pop();

                // CHECK MOUNTED before proceeding
                if (!mounted) return;

                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext loadingContext) {
                    return AlertDialog(
                      content: Row(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(width: 20),
                          Text('Deleting goal...'),
                        ],
                      ),
                    );
                  },
                );

                try {
                  //  Cancel all scheduled notifications for this goal
                  NotificationService notificationService = NotificationService();
                  await notificationService.cancelGoalReminders(goal!.id);

                  // THEN: Delete the goal from Firebase
                  await _goalRepository.deleteRecyclingGoal(goal!.id);

                  // CHECK MOUNTED after async operation - CRUCIAL!
                  if (!mounted) return;

                  // Close loading dialog
                  Navigator.of(context).pop();

                  // Go back to previous screen
                  Navigator.of(context).pop();

                  // Show success message on the previous screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Goal and reminders deleted successfully'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      duration: Duration(seconds: 3),
                    ),
                  );
                } catch (e) {
                  // CHECK MOUNTED in error handling too - CRUCIAL!
                  if (!mounted) return;

                  // Close loading dialog
                  Navigator.of(context).pop();

                  // Show error message on current screen
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.error, color: Colors.white),
                          SizedBox(width: 8),
                          Expanded(child: Text('Error deleting goal: $e')),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              },
              child: Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

}

// EditGoalScreen
class EditGoalScreen extends StatefulWidget {
  final String userId;
  final RecyclingGoal goal;

  const EditGoalScreen({
    super.key,
    required this.userId,
    required this.goal,
  });

  @override
  _EditGoalScreenState createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends State<EditGoalScreen> {
  final GoalRepository _goalRepository = GoalRepository();
  final _formKey = GlobalKey<FormState>();

  // Controllers - Only for editable fields
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;

  // Form values - Only for editable fields
  late bool _reminderEnabled;
  late TimeOfDay _reminderTime;

  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _initializeWithGoalData();
  }

  void _initializeWithGoalData() {
    // Initialize controllers with existing data
    _titleController = TextEditingController(text: widget.goal.title);
    _descriptionController = TextEditingController(text: widget.goal.description);

    // Initialize only editable form values
    _reminderEnabled = widget.goal.reminderEnabled;
    _reminderTime = widget.goal.reminderTime != null
        ? TimeOfDay.fromDateTime(widget.goal.reminderTime!)
        : TimeOfDay(hour: 9, minute: 0);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Goal',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _isUpdating ? null : _updateGoal,
              child: _isUpdating
                  ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5E8C43)),
                ),
              )
                  : Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFF5E8C43),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title input
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: 'Enter goal title',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
              ),

              SizedBox(height: 16),

              // Note about editing limitations
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue.shade700, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'You can edit the title, description, and reminder settings. Target amount, dates, and frequency cannot be changed.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Description
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        hintText: 'Add a description for your goal...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(0),
                      ),
                      minLines: 3,
                      maxLines: 5,
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16),

              // Reminder Settings
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.notifications, color: Color(0xFF5E8C43), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Reminder Settings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),

                    // Reminder toggle
                    SwitchListTile(
                      title: Text('Enable Reminders'),
                      value: _reminderEnabled,
                      activeThumbColor: Color(0xFF5E8C43),
                      onChanged: (value) {
                        setState(() {
                          _reminderEnabled = value;
                        });
                      },
                      contentPadding: EdgeInsets.all(0),
                    ),

                    if (_reminderEnabled) ...[
                      SizedBox(height: 8),
                      ListTile(
                        leading: Icon(Icons.schedule, color: Color(0xFF5E8C43)),
                        title: Text('Reminder Time'),
                        subtitle: Text(_reminderTime.format(context)),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16),
                        contentPadding: EdgeInsets.all(0),
                        onTap: _selectReminderTime,
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 24),

              // Current goal information (read-only)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Goal Settings (Read-only)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    SizedBox(height: 12),
                    _buildReadOnlyRow('Target Amount', '${widget.goal.targetAmount} ${widget.goal.unit}'),
                    _buildReadOnlyRow('Frequency', widget.goal.frequency),
                    _buildReadOnlyRow('Start Date', DateFormat('MMM d, yyyy').format(widget.goal.startDate)),
                    _buildReadOnlyRow('End Date', DateFormat('MMM d, yyyy').format(widget.goal.endDate)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );

    if (picked != null && picked != _reminderTime) {
      setState(() {
        _reminderTime = picked;
      });
    }
  }

  void _updateGoal() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUpdating = true;
      });

      try {
        // Create updated goal object
        RecyclingGoal updatedGoal = RecyclingGoal(
          id: widget.goal.id,
          userId: widget.goal.userId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          startDate: widget.goal.startDate, // Keep original
          endDate: widget.goal.endDate, // Keep original
          targetAmount: widget.goal.targetAmount, // Keep original
          unit: widget.goal.unit, // Keep original
          frequency: widget.goal.frequency, // Keep original
          completed: widget.goal.completed,
          progress: widget.goal.progress,
          selectedDays: widget.goal.selectedDays, // Keep original
          completedActions: widget.goal.completedActions,
          pointsAwarded: widget.goal.pointsAwarded,
          checkInDates: widget.goal.checkInDates,
          dailyProgress: widget.goal.dailyProgress,
          reminderEnabled: _reminderEnabled,
          reminderTime: _reminderEnabled ? DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            _reminderTime.hour,
            _reminderTime.minute,
          ) : null,
        );

        // Update the goal first
        await _goalRepository.updateRecyclingGoal(updatedGoal);

        // Then update reminders separately
        NotificationService notificationService = NotificationService();
        await notificationService.updateGoalReminders(
          widget.goal.id,
          updatedGoal,
          reminderEnabled: _reminderEnabled,
          reminderTime: _reminderEnabled ? DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
            _reminderTime.hour,
            _reminderTime.minute,
          ) : null,
        );

        if (!mounted) return;
        Navigator.pop(context, true); // Return true to indicate success

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Goal updated successfully!'),
            backgroundColor: Color(0xFF5E8C43),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update goal: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      } finally {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }
}