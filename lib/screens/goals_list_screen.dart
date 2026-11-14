import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/recycling_goal.dart';
import '../repositories/goal_repository.dart';
import 'goal_detail_screen.dart';
import 'set_goal_screen.dart';
import 'dart:math';

class GoalsListScreen extends StatefulWidget {
  final String userId;

  const GoalsListScreen({super.key, required this.userId});

  @override
  _GoalsListScreenState createState() => _GoalsListScreenState();
}

class _GoalsListScreenState extends State<GoalsListScreen> {
  final GoalRepository _goalRepository = GoalRepository();
  List<RecyclingGoal> userGoals = [];
  bool isLoading = true;
  DateTime selectedDate = DateTime.now();
  List<DateTime> dateList = [];
  final ScrollController _dateScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _generateDateList();
    loadGoalsScreen();

    Future.delayed(Duration(milliseconds: 200), () {
      _scrollToSelectedDate();
    });
  }

  void _scrollToSelectedDate() {
    // Calculate today's position in the date list
    final today = DateTime.now();
    int todayIndex = 0;

    for (int i = 0; i < dateList.length; i++) {
      if (dateList[i].day == today.day &&
          dateList[i].month == today.month &&
          dateList[i].year == today.year) {
        todayIndex = i;
        break;
      }
    }

    // Calculate scroll offset (each date tile is about 40-48 width plus margins)
    // This centers today's date in the horizontal list
    double dateItemWidth = 48.0; // Width + margins
    double screenWidth = MediaQuery.of(context).size.width;
    double offset = (todayIndex * dateItemWidth) - (screenWidth / 2) + (dateItemWidth / 2);

    // Make sure offset is not negative
    offset = offset < 0 ? 0 : offset;

    // Only animate if the controller is attached and the day isn't already visible
    if (_dateScrollController.hasClients) {
      // Use a try-catch to handle any potential issues
      try {
        _dateScrollController.animateTo(
          offset,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } catch (e) {
        print("Error scrolling to date: $e");
      }
    } else {
      // If controller isn't attached yet, try again after a short delay
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollToSelectedDate();
      });
    }
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> loadGoalsScreen() async {
    setState(() {
      isLoading = true;
    });

    try {
      // First check for expired goals and award points if applicable
      await _goalRepository.checkExpiredGoals();

      // Then load the user's goals
      List<RecyclingGoal> goals = await _goalRepository.getUserRecyclingGoals(widget.userId);

      setState(() {
        userGoals = goals;
        isLoading = false;
      });
    } catch (e) {
      print("Error loading goals: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> refreshGoals() async {
    await loadGoalsScreen();
  }

//  Proper check for whether goal should be completed
  bool _shouldCompleteOnDate(RecyclingGoal goal, DateTime date) {
    return goal.shouldCompleteOnDate(date);
  }

  Future<bool> _hasCheckedInToday(RecyclingGoal goal) async {
    return await _goalRepository.hasCheckedInToday(goal.id);
  }

  // Modified to check if goal was completed on the specified date
  bool _wasCompletedOnDate(RecyclingGoal goal, DateTime date) {
    // Use the goal's actual check-in data
    return goal.wasCompletedOnDate(date);
  }

  // Calculate total expected amount based on frequency and duration
  double _calculateTotalExpectedAmount(RecyclingGoal goal) {
    int totalDays = goal.endDate.difference(goal.startDate).inDays + 1;
    double targetAmount = goal.targetAmount.toDouble();

    switch (goal.frequency.toLowerCase()) {
      case 'daily':
        return targetAmount * totalDays;
      case 'weekly':
        return targetAmount * (totalDays / 7).ceil();
      case 'custom':
        int selectedDaysPerWeek = goal.selectedDays.where((selected) => selected).length;
        return targetAmount * ((totalDays / 7) * selectedDaysPerWeek).ceil();
      default:
        return 0.0;
    }
  }

  // Calculate completion rate for a goal using the new formula
  double _getCompletionRate(RecyclingGoal goal) {
    double totalExpectedAmount = _calculateTotalExpectedAmount(goal);
    if (totalExpectedAmount <= 0) return 0.0;
    return (goal.progress / totalExpectedAmount).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Goals'),
        backgroundColor: Color(0xFF5E8C43),
        actions: [
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SetGoalScreen(
                    userId: widget.userId,
                    initialDate: DateTime.now(),
                  ),
                ),
              ).then((_) {
                // Reset to current date when returning from set goal screen
                setState(() {
                  selectedDate = DateTime.now(); // Reset to today
                  _generateDateList(); // Regenerate the date list
                });
                refreshGoals(); // Refresh the goals
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: refreshGoals,
        child: Column(
          children: [
            _buildDateSelector(),
            Expanded(
              child: userGoals.isEmpty
                  ? _buildEmptyState()
                  : _buildGoalsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    // Get current month for header
    final currentMonth = DateTime(selectedDate.year, selectedDate.month);

    return Column(
      children: [
        // Month header with navigation buttons
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Color(0xFF5E8C43).withOpacity(0.9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous month button
              IconButton(
                icon: Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () {
                  setState(() {
                    // Go to previous month and update date list
                    DateTime prevMonth = DateTime(selectedDate.year, selectedDate.month - 1);
                    selectedDate = DateTime(prevMonth.year, prevMonth.month,
                        min(selectedDate.day, DateTime(prevMonth.year, prevMonth.month + 1, 0).day));
                    _generateDateList();
                  });
                },
              ),

              // Month and year display
              GestureDetector(
                onTap: () {
                  // Show month picker when tapped
                  _showMonthYearPicker(context);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(currentMonth),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down, color: Colors.white),
                  ],
                ),
              ),

              // Next month button
              IconButton(
                icon: Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () {
                  setState(() {
                    // Go to next month and update date list
                    DateTime nextMonth = DateTime(selectedDate.year, selectedDate.month + 1);
                    selectedDate = DateTime(nextMonth.year, nextMonth.month,
                        min(selectedDate.day, DateTime(nextMonth.year, nextMonth.month + 1, 0).day));
                    _generateDateList();
                  });
                },
              ),
            ],
          ),
        ),

        // Weekday headers
        Container(
          padding: EdgeInsets.symmetric(vertical: 6),
          color: Color(0xFF5E8C43).withOpacity(0.7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              'S', 'M', 'T', 'W', 'T', 'F', 'S'
            ].map((day) => SizedBox(
              width: 40,
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 12,
                ),
              ),
            )).toList(),
          ),
        ),

        // Date scrolling list
        Container(
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ListView.builder(
            controller: _dateScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: dateList.length,
            itemBuilder: (context, index) {
              final date = dateList[index];
              final isSelected = date.year == selectedDate.year &&
                  date.month == selectedDate.month &&
                  date.day == selectedDate.day;
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;

              // Count completed goals for THIS specific date (not the selected date)
              int completedCount = 0;
              int totalGoals = 0;

              for (var goal in userGoals) {
                if (_shouldCompleteOnDate(goal, date)) {
                  totalGoals++;
                  if (_wasCompletedOnDate(goal, date)) {
                    completedCount++;
                  }
                }
              }

              // Set background color for the date card
              Color bgColor;
              if (isSelected) {
                bgColor = Color(0xFF5E8C43);
              } else if (isToday) {
                bgColor = Color(0xFF5E8C43).withOpacity(0.2);
              } else {
                bgColor = Colors.white;
              }

              // Text color based on selection
              Color textColor = isSelected ? Colors.white : Colors.black87;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDate = date;
                  });
                },
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  width: 40,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: Color(0xFF5E8C43), width: 2)
                        : null,
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: Color(0xFF5E8C43).withOpacity(0.3),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Weekday
                      Text(
                        DateFormat('E').format(date).substring(0, 1), // First letter only
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(height: 4),
                      // Day number
                      Text(
                        date.day.toString(),
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 4),
                      // Completion indicator
                      if (totalGoals > 0)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.3)
                                : Color(0xFF5E8C43).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$completedCount/$totalGoals',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Color(0xFF5E8C43),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showMonthYearPicker(BuildContext context) async {
    // Get the current month and year
    int currentYear = selectedDate.year;
    int currentMonth = selectedDate.month;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Text(
                      "Select Month & Year",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5E8C43),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Year selection
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left),
                          onPressed: () {
                            setState(() {
                              currentYear--;
                            });
                          },
                        ),
                        Text(
                          currentYear.toString(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right),
                          onPressed: () {
                            setState(() {
                              currentYear++;
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 10),

                    // Month grid
                    GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        // Month is 1-based, so add 1 to index
                        final month = index + 1;
                        final isSelected = month == currentMonth;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              currentMonth = month;
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(0xFF5E8C43)
                                  : Color(0xFF5E8C43).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                DateFormat('MMM').format(DateTime(2022, month, 1)),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 20),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          child: Text("Cancel"),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF5E8C43),
                          ),
                          child: Text("Select"),
                          onPressed: () {
                            // Update selected date with new month/year

                            int lastDayOfMonth = DateTime(currentYear, currentMonth + 1, 0).day;

                            // Try to keep the same day, but adjust if the new month is shorter
                            int newDay = min(selectedDate.day, lastDayOfMonth);

                            // Set the new date and regenerate the date list
                            this.setState(() {
                              selectedDate = DateTime(currentYear, currentMonth, newDay);
                              _generateDateList();
                            });

                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _generateDateList() {
    dateList.clear();

    final lastDayOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0);

    // Generate all days in the current month
    for (int i = 1; i <= lastDayOfMonth.day; i++) {
      dateList.add(DateTime(selectedDate.year, selectedDate.month, i));
    }
  }

  Widget _buildGoalsList() {
    // Filter goals into completed and not completed for the selected date
    List<RecyclingGoal> completedGoals = [];
    List<RecyclingGoal> notCompletedGoals = [];

    for (var goal in userGoals) {
      if (_shouldCompleteOnDate(goal, selectedDate)) {
        if (_wasCompletedOnDate(goal, selectedDate)) {
          completedGoals.add(goal);
        } else {
          notCompletedGoals.add(goal);
        }
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (notCompletedGoals.isNotEmpty) ...[
            Text(
              'Not Completed Today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            SizedBox(height: 12),
            ...notCompletedGoals.map((goal) => _buildGoalCard(goal, false)),
            SizedBox(height: 20),
          ],

          if (completedGoals.isNotEmpty) ...[
            Text(
              'Completed Today',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF5E8C43),
              ),
            ),
            SizedBox(height: 12),
            ...completedGoals.map((goal) => _buildGoalCard(goal, true)),
          ],

          // Show message only when there are truly no goals scheduled
          if (completedGoals.isEmpty && notCompletedGoals.isEmpty) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Column(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 60,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No goals scheduled for this date',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalCard(RecyclingGoal goal, bool isCompleted) {
    final completionRate = _getCompletionRate(goal);
    final bool isToday = selectedDate.year == DateTime.now().year &&
        selectedDate.month == DateTime.now().month &&
        selectedDate.day == DateTime.now().day;

    // Select color for the goal
    final colors = [
      Color(0xFF5E8C43), // Green
      Colors.blue.shade700,
      Colors.amber.shade800,
      Colors.purple.shade700,
      Colors.teal.shade700,
      Colors.orange.shade800,
      Colors.indigo.shade700
    ];

    final colorIndex = goal.id.hashCode % colors.length;
    final color = colors[colorIndex.abs()];

    String frequencyLabel = '';
    switch (goal.frequency.toLowerCase()) {
      case 'daily':
        frequencyLabel = 'day';
        break;
      case 'weekly':
        frequencyLabel = 'week';
        break;
      case 'custom':
        frequencyLabel = 'occurrence';
        break;
      default:
        frequencyLabel = 'occurrence';
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => GoalDetailScreen(userId: widget.userId, goalId: goal.id),
            ),
          ).then((_) {
            setState(() {
              selectedDate = DateTime.now(); // Reset to today
              _generateDateList(); // Regenerate the date list
            });
            refreshGoals(); // Refresh the goals

            // Scroll to current date after a small delay
            Future.delayed(Duration(milliseconds: 300), () {
              _scrollToSelectedDate();
            });
          });
        },

        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Colored date banner
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.8),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${DateFormat('MMM d').format(goal.startDate)} - ${DateFormat('MMM d').format(goal.endDate)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      goal.frequency,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Goal content
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title with completion status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          goal.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCompleted)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: color,
                                size: 14,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Done',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Goal description
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Text(
                      goal.description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Target Amount Label
                  Container(
                    margin: EdgeInsets.only(bottom: 8),
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Target: ${goal.targetAmount} ${goal.unit} per $frequencyLabel',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  // Progress information
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Progress: ${goal.progress}/${_calculateTotalExpectedAmount(goal).toStringAsFixed(1)} ${goal.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${(completionRate * 100).toInt()}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: color,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: completionRate,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 8,
                    ),
                  ),

                  // Replace the check-in button section in _buildGoalCard():

// Check-in button - ALWAYS SHOW but disable for non-today dates
                  if (!isCompleted && _shouldCompleteOnDate(goal, selectedDate))
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Builder(
                            builder: (context) {
                              // Determine date relationship for messaging
                              final DateTime today = DateTime.now();
                              final DateTime todayNormalized = DateTime(today.year, today.month, today.day);
                              final DateTime selectedDateNormalized = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

                              final bool isSelectedDateFuture = selectedDateNormalized.isAfter(todayNormalized);
                              final bool isSelectedDatePast = selectedDateNormalized.isBefore(todayNormalized);

                              // Determine button state and message
                              String disabledMessage = '';
                              if (isSelectedDatePast) {
                                disabledMessage = 'Cannot check-in for past dates';
                              } else if (isSelectedDateFuture) {
                                disabledMessage = 'Cannot check-in for future dates';
                              }

                              return FutureBuilder<bool>(
                                future: _hasCheckedInToday(goal),
                                builder: (context, snapshot) {
                                  bool hasCheckedIn = snapshot.data ?? false;

                                  // Show completion status if already checked in today (and viewing today)
                                  if (hasCheckedIn && isToday) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.check_circle, color: color, size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            'Checked in today',
                                            style: TextStyle(
                                              color: color,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  // Show disabled button for non-today dates
                                  else if (!isToday) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        ElevatedButton.icon(
                                          icon: Icon(Icons.block, size: 18),
                                          label: Text('Check-in'),
                                          onPressed: null, // Disabled
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.grey.shade300,
                                            foregroundColor: Colors.grey.shade600,
                                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          disabledMessage,
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  // Show active button for today (and not already checked in)
                                  else {
                                    return ElevatedButton.icon(
                                      icon: Icon(Icons.check, size: 18),
                                      label: Text('Check-in'),
                                      onPressed: () async {
                                        try {
                                          await _goalRepository.recordDailyCheckIn(
                                              goal.id,
                                              goal.targetAmount.toDouble()
                                          );

                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('✅ Checked in successfully!'),
                                              backgroundColor: color,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );

                                          refreshGoals();
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: ${e.toString()}'),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: color,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                  // Points awarded message
                  if (goal.completed && goal.pointsAwarded)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.star,
                              size: 16,
                              color: Colors.amber.shade800,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '10 eco points awarded',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ],
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.eco,
            size: 80,
            color: Colors.grey.shade400,
          ),
          SizedBox(height: 16),
          Text(
            'No recycling goals found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Start by creating your first eco-friendly goal',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SetGoalScreen(
                    userId: widget.userId,
                    initialDate: DateTime.now(),
                  ),
                ),
              ).then((_) {
                // Reset to current date when returning from set goal screen
                setState(() {
                  selectedDate = DateTime.now(); // Reset to today
                  _generateDateList(); // Regenerate the date list
                });
                refreshGoals(); // Refresh the goals
              });
            },
            icon: Icon(Icons.add),
            label: Text('Create New Goal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF5E8C43),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}