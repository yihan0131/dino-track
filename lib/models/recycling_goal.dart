import 'package:cloud_firestore/cloud_firestore.dart';

class RecyclingGoal {
  final String id;
  final String userId;
  final String title;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final double targetAmount;
  final String unit;
  final String frequency;
  final List<bool> selectedDays;
  bool completed;
  int progress;
  int completedActions; // Track actual completed actions
  bool pointsAwarded; // Track if points were awarded
  final List<DateTime> checkInDates;
  final Map<String, int> dailyProgress;

  // Add the reminder fields properly
  final bool reminderEnabled;
  final DateTime? reminderTime;

  // Constructor
  RecyclingGoal({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.targetAmount,
    required this.unit,
    required this.frequency,
    required this.selectedDays,
    this.completed = false,
    this.progress = 0,
    this.completedActions = 0,
    this.pointsAwarded = false,
    this.checkInDates = const [],
    this.dailyProgress = const {},
    this.reminderEnabled = false,
    this.reminderTime,
  });

  //  Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'targetAmount': targetAmount,
      'unit': unit,
      'frequency': frequency,
      'completed': completed,
      'progress': progress,
      'selectedDays': selectedDays,
      'completedActions': completedActions,
      'pointsAwarded': pointsAwarded,
      'checkInDates': checkInDates.map((date) => date.millisecondsSinceEpoch).toList(),
      'dailyProgress': dailyProgress,
      'reminderEnabled': reminderEnabled,
      'reminderTime': reminderTime?.millisecondsSinceEpoch,
    };
  }

  // Create from Map (including new fields and proper Timestamp handling)
  factory RecyclingGoal.fromMap(Map<String, dynamic> map) {
    try {
      // Handle checkInDates conversion from Firestore
      List<DateTime> checkIns = [];
      if (map['checkInDates'] != null) {
        List<dynamic> checkInList = map['checkInDates'] as List<dynamic>;
        checkIns = checkInList.map((timestamp) {
          if (timestamp is Timestamp) {
            return timestamp.toDate();
          } else if (timestamp is int) {
            return DateTime.fromMillisecondsSinceEpoch(timestamp);
          }
          return DateTime.now(); // Fallback
        }).toList();
      }

      // Handle dailyProgress conversion from Firestore
      Map<String, int> dailyProg = {};
      if (map['dailyProgress'] != null) {
        Map<String, dynamic> progMap = Map<String, dynamic>.from(map['dailyProgress']);
        dailyProg = progMap.map((key, value) => MapEntry(key, (value as num).toInt()));
      }

      return RecyclingGoal(
        id: map['id'] ?? '',
        userId: map['userId'] ?? '',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        //  Handle both Timestamp and int for dates
        startDate: map['startDate'] is Timestamp
            ? (map['startDate'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(map['startDate'] ?? 0),
        endDate: map['endDate'] is Timestamp
            ? (map['endDate'] as Timestamp).toDate()
            : DateTime.fromMillisecondsSinceEpoch(map['endDate'] ?? 0),
        // 🔧 FIXED: targetAmount should remain as double, not converted to int
        targetAmount: (map['targetAmount'] ?? 0.0).toDouble(),
        unit: map['unit'] ?? '',
        frequency: map['frequency'] ?? '',
        completed: map['completed'] ?? false,
        progress: (map['progress'] ?? 0).toInt(),
        selectedDays: map['selectedDays'] != null
            ? List<bool>.from(map['selectedDays'])
            : List.generate(7, (index) => false),
        completedActions: (map['completedActions'] ?? 0).toInt(),
        pointsAwarded: map['pointsAwarded'] ?? false,
        checkInDates: checkIns,
        dailyProgress: dailyProg,
        // Add reminder fields from map
        reminderEnabled: map['reminderEnabled'] ?? false,
        reminderTime: map['reminderTime'] != null
            ? DateTime.fromMillisecondsSinceEpoch(map['reminderTime'])
            : null,
      );
    } catch (e) {
      print("Error parsing RecyclingGoal from map: $e");
      print("Map data: $map");
      rethrow; // This will help you see the exact error
    }
  }

  // Check if goal was completed on specific date
  bool wasCompletedOnDate(DateTime date) {
    DateTime normalizedDate = DateTime(date.year, date.month, date.day);

    return checkInDates.any((checkInDate) {
      DateTime normalizedCheckIn = DateTime(checkInDate.year, checkInDate.month, checkInDate.day);
      return normalizedCheckIn.isAtSameMomentAs(normalizedDate);
    });
  }

  // Get progress for specific date
  int getProgressForDate(DateTime date) {
    String dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    return dailyProgress[dateKey] ?? 0;
  }

  //  Check if user should complete goal on specific date
  bool shouldCompleteOnDate(DateTime date) {
    DateTime normalizedDate = DateTime(date.year, date.month, date.day);
    DateTime normalizedStartDate = DateTime(startDate.year, startDate.month, startDate.day);
    DateTime normalizedEndDate = DateTime(endDate.year, endDate.month, endDate.day);

    // Check if date is within goal period
    if (normalizedDate.isBefore(normalizedStartDate) || normalizedDate.isAfter(normalizedEndDate)) {
      return false;
    }

    switch (frequency.toLowerCase()) {
      case 'daily':
        return true;
      case 'weekly':
        return date.weekday == startDate.weekday;
      case 'custom':
        return selectedDays[date.weekday % 7];
      default:
        return false;
    }
  }

  // Get completion status for a date range (useful for calendar views)
  Map<DateTime, bool> getCompletionStatusForRange(DateTime start, DateTime end) {
    Map<DateTime, bool> status = {};

    DateTime current = DateTime(start.year, start.month, start.day);
    DateTime endNormalized = DateTime(end.year, end.month, end.day);

    while (current.isBefore(endNormalized) || current.isAtSameMomentAs(endNormalized)) {
      if (shouldCompleteOnDate(current)) {
        status[current] = wasCompletedOnDate(current);
      }
      current = current.add(Duration(days: 1));
    }

    return status;
  }

  //  Get total days that should be completed (for progress calculation)
  int getTotalExpectedCompletions() {
    int totalDays = endDate.difference(startDate).inDays + 1;

    switch (frequency.toLowerCase()) {
      case 'daily':
        return totalDays;
      case 'weekly':
        return (totalDays / 7).ceil();
      case 'custom':
        int selectedDaysPerWeek = selectedDays.where((selected) => selected).length;
        return ((totalDays / 7) * selectedDaysPerWeek).ceil();
      default:
        return 0;
    }
  }

  // Calculate total expected amount based on frequency
  double getTotalExpectedAmount() {
    int totalExpectedCompletions = getTotalExpectedCompletions();
    return targetAmount.toDouble() * totalExpectedCompletions;
  }

  //  Get completion rate as percentage
  double getCompletionRate() {
    double totalExpectedAmount = getTotalExpectedAmount();
    if (totalExpectedAmount <= 0) return 0.0;
    return (progress / totalExpectedAmount).clamp(0.0, 1.0);
  }

  //  Check if goal is eligible for points (useful for UI warnings)
  bool isEligibleForPoints() {
    // Check duration - at least 7 days
    final durationDays = endDate.difference(startDate).inDays;
    if (durationDays < 7) return false;

    // Check if can have at least 3 completions
    int expectedCompletions = getTotalExpectedCompletions();
    return expectedCompletions >= 3;
  }

  // Get days until goal ends
  int getDaysUntilEnd() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime goalEnd = DateTime(endDate.year, endDate.month, endDate.day);

    if (goalEnd.isBefore(today)) return 0;
    return goalEnd.difference(today).inDays;
  }

  // Check if goal is active (within date range and not completed)
  bool isActive() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime goalStart = DateTime(startDate.year, startDate.month, startDate.day);
    DateTime goalEnd = DateTime(endDate.year, endDate.month, endDate.day);

    return !completed &&
        (today.isAtSameMomentAs(goalStart) || today.isAfter(goalStart)) &&
        (today.isAtSameMomentAs(goalEnd) || today.isBefore(goalEnd));
  }
}