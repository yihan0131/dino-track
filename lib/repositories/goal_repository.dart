import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/recycling_goal.dart';
import '../service/notification_service.dart';
import 'user_repository.dart';

class GoalRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  final UserRepository _userRepository = UserRepository();

  String? _currentUserId() =>
      auth.FirebaseAuth.instance.currentUser?.uid;

  Future<String> createRecyclingGoal(RecyclingGoal goal) async {
    try {
      final String goalId = goal.id.isEmpty ? _uuid.v4() : goal.id;
      final Map<String, dynamic> data = {
        ...goal.toMap(),
        'checkInDates': <dynamic>[],
        'dailyProgress': <String, dynamic>{},
      };

      await _firestore
          .collection('recycling_goals')
          .doc(goalId)
          .set(data)
          .timeout(const Duration(seconds: 15));
      return goalId;
    } catch (e) {
      debugPrint("Error creating recycling goal: $e");
      rethrow;
    }
  }

  Future<String> createRecyclingGoalWithReminder(
    RecyclingGoal goal, {
    required bool reminderEnabled,
    DateTime? reminderTime,
  }) async {
    try {
      String goalId = await createRecyclingGoal(goal);

      if (reminderEnabled && reminderTime != null) {
        final notificationService = NotificationService();
        await notificationService.scheduleGoalReminders(
            goalId, goal, reminderTime);
      }

      return goalId;
    } catch (e) {
      debugPrint("Error creating recycling goal with reminder: $e");
      rethrow;
    }
  }

  Future<List<RecyclingGoal>> getUserRecyclingGoals(String userId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('recycling_goals')
          .where('userId', isEqualTo: userId)
          .get();

      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return RecyclingGoal.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint("Error getting user recycling goals: $e");
      return [];
    }
  }

  Future<bool> isGoalCompletedOnDate(String goalId, DateTime date) async {
    try {
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay =
          DateTime(date.year, date.month, date.day, 23, 59, 59);

      QuerySnapshot query = await _firestore
          .collection('goal_actions')
          .where('goalId', isEqualTo: goalId)
          .where('date',
              isGreaterThanOrEqualTo: startOfDay.millisecondsSinceEpoch)
          .where('date',
              isLessThanOrEqualTo: endOfDay.millisecondsSinceEpoch)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint("Error checking goal completion date: $e");
      return false;
    }
  }

  bool doesGoalQualifyForPoints(RecyclingGoal goal) {
    final durationDays =
        goal.endDate.difference(goal.startDate).inDays + 1;
    if (durationDays < 7) return false;
    if (goal.completedActions < 3) return false;

    int expectedActions = _calculateExpectedActions(goal);
    double completionRate = expectedActions > 0
        ? (goal.completedActions / expectedActions) * 100
        : 0;

    return completionRate >= 80;
  }

  int _calculateExpectedActions(RecyclingGoal goal) {
    final durationDays =
        goal.endDate.difference(goal.startDate).inDays + 1;

    switch (goal.frequency.toLowerCase()) {
      case 'daily':
        return durationDays;
      case 'weekly':
        return (durationDays / 7).floor();
      case 'custom':
        int selectedDaysPerWeek =
            goal.selectedDays.where((selected) => selected).length;
        return ((durationDays / 7) * selectedDaysPerWeek).floor();
      default:
        return 0;
    }
  }

  Future<Map<String, dynamic>> checkGoalEligibility(RecyclingGoal goal) async {
    final durationDays =
        goal.endDate.difference(goal.startDate).inDays + 1;
    int expectedActions = _calculateExpectedActions(goal);
    bool canEarnPoints = durationDays >= 7 && expectedActions >= 3;

    return {
      'canEarnPoints': canEarnPoints,
      'durationDays': durationDays,
      'expectedActions': expectedActions,
      'minimumDays': 7,
      'minimumActions': 3,
      'reason': !canEarnPoints
          ? (durationDays < 7
              ? 'Goal duration must be at least 7 days'
              : 'Goal must allow at least 3 completions based on frequency')
          : null,
    };
  }

  Future<Map<String, dynamic>> previewGoalEligibility(
      RecyclingGoal goal) async {
    final result = await checkGoalEligibility(goal);

    if (!result['canEarnPoints']) {
      return {
        'canEarnPoints': false,
        'warningMessage':
            "Warning: With your current settings, this goal won't be eligible for points. ${result['reason']}.",
        'details': result,
      };
    }

    return {
      'canEarnPoints': true,
      'message': "This goal is eligible for 10 points upon successful completion.",
      'details': result,
    };
  }

  Future<void> recordGoalAction(String goalId, int additionalProgress) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference goalRef =
            _firestore.collection('recycling_goals').doc(goalId);
        DocumentSnapshot goalDoc = await transaction.get(goalRef);

        if (goalDoc.exists) {
          Map<String, dynamic> data =
              goalDoc.data() as Map<String, dynamic>;
          int currentProgress = data['progress'] ?? 0;
          int completedActions = data['completedActions'] ?? 0;
          int targetAmount = data['targetAmount'] ?? 0;
          int newProgress = currentProgress + additionalProgress;

          if (newProgress >= targetAmount && currentProgress < targetAmount) {
            completedActions++;
          }

          transaction.update(goalRef, {
            'progress': newProgress,
            'completedActions': completedActions,
          });
        }
      });
    } catch (e) {
      debugPrint("Error updating goal action: $e");
      rethrow;
    }
  }

  Future<void> evaluateAndRewardCompletedGoals() async {
    try {
      final userId = _currentUserId();
      if (userId == null) return;

      QuerySnapshot querySnapshot = await _firestore
          .collection('recycling_goals')
          .where('userId', isEqualTo: userId)
          .where('completed', isEqualTo: true)
          .where('pointsAwarded', isEqualTo: false)
          .get();

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        RecyclingGoal goal =
            RecyclingGoal.fromMap({...data, 'id': doc.id});

        if (doesGoalQualifyForPoints(goal)) {
          await _userRepository.updateEcoPoints(userId, 10);
        }

        await _firestore
            .collection('recycling_goals')
            .doc(goal.id)
            .update({'pointsAwarded': true});
      }
    } catch (e) {
      debugPrint("Error evaluating completed goals: $e");
    }
  }

  Future<void> checkExpiredGoals() async {
    try {
      final userId = _currentUserId();
      if (userId == null) return;

      final now = DateTime.now();

      QuerySnapshot querySnapshot = await _firestore
          .collection('recycling_goals')
          .where('userId', isEqualTo: userId)
          .where('completed', isEqualTo: false)
          .where('endDate', isLessThan: now.millisecondsSinceEpoch)
          .get();

      for (var doc in querySnapshot.docs) {
        await _firestore
            .collection('recycling_goals')
            .doc(doc.id)
            .update({'completed': true});
      }

      await evaluateAndRewardCompletedGoals();
    } catch (e) {
      debugPrint("Error checking expired goals: $e");
    }
  }

  Future<void> updateRecyclingGoal(RecyclingGoal goal) async {
    try {
      await _firestore
          .collection('recycling_goals')
          .doc(goal.id)
          .update(goal.toMap());
    } catch (e) {
      debugPrint("Error updating recycling goal: $e");
      rethrow;
    }
  }

  Future<void> recordDailyCheckIn(String goalId, double progressAmount) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference goalRef =
            _firestore.collection('recycling_goals').doc(goalId);
        DocumentSnapshot goalDoc = await transaction.get(goalRef);

        if (goalDoc.exists) {
          Map<String, dynamic> data =
              goalDoc.data() as Map<String, dynamic>;
          int currentProgress = data['progress'] ?? 0;
          double targetAmount = (data['targetAmount'] ?? 0).toDouble();
          int completedActions = data['completedActions'] ?? 0;

          List<dynamic> existingCheckIns = data['checkInDates'] ?? [];
          List<DateTime> checkInDates = existingCheckIns.map((timestamp) {
            if (timestamp is Timestamp) return timestamp.toDate();
            if (timestamp is int) {
              return DateTime.fromMillisecondsSinceEpoch(timestamp);
            }
            return DateTime.now();
          }).toList();

          Map<String, dynamic> existingDailyProgress =
              Map<String, dynamic>.from(data['dailyProgress'] ?? {});

          DateTime today = DateTime.now();
          DateTime todayNormalized =
              DateTime(today.year, today.month, today.day);

          bool alreadyCheckedInToday = checkInDates.any((date) {
            DateTime dateNormalized =
                DateTime(date.year, date.month, date.day);
            return dateNormalized.isAtSameMomentAs(todayNormalized);
          });

          if (alreadyCheckedInToday) {
            throw Exception('Already checked in today');
          }

          checkInDates.add(todayNormalized);

          String todayKey =
              '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
          existingDailyProgress[todayKey] = progressAmount;

          int newProgress = currentProgress + progressAmount.toInt();

          if (progressAmount >= targetAmount) {
            completedActions++;
          }

          DateTime endDate =
              DateTime.fromMillisecondsSinceEpoch(data['endDate']);
          bool shouldMarkCompleted = DateTime.now().isAfter(endDate);

          transaction.update(goalRef, {
            'progress': newProgress,
            'completedActions': completedActions,
            'checkInDates': checkInDates
                .map((date) => date.millisecondsSinceEpoch)
                .toList(),
            'dailyProgress': existingDailyProgress,
            'completed': shouldMarkCompleted || data['completed'],
          });
        }
      });
    } catch (e) {
      debugPrint("Error recording daily check-in: $e");
      rethrow;
    }
  }

  Future<void> recordGoalCompletion(
      String goalId, double progressAmount) async {
    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference goalRef =
            _firestore.collection('recycling_goals').doc(goalId);
        DocumentSnapshot goalDoc = await transaction.get(goalRef);

        if (goalDoc.exists) {
          Map<String, dynamic> data =
              goalDoc.data() as Map<String, dynamic>;
          int currentProgress = data['progress'] ?? 0;
          double targetAmount = (data['targetAmount'] ?? 0).toDouble();
          int completedActions = data['completedActions'] ?? 0;
          int newProgress = currentProgress + progressAmount.toInt();

          if (progressAmount >= targetAmount) {
            completedActions++;
          }

          int endDateTimestamp = data['endDate'];
          DateTime endDate =
              DateTime.fromMillisecondsSinceEpoch(endDateTimestamp);
          bool isCompleted = DateTime.now().isAfter(endDate);

          transaction.update(goalRef, {
            'progress': newProgress,
            'completedActions': completedActions,
            'completed': isCompleted || data['completed'],
          });
        }
      });
    } catch (e) {
      debugPrint("Error recording goal completion: $e");
      rethrow;
    }
  }

  Future<bool> hasCheckedInToday(String goalId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('recycling_goals')
          .doc(goalId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<dynamic> checkInList = data['checkInDates'] ?? [];

        DateTime today = DateTime.now();
        DateTime todayNormalized =
            DateTime(today.year, today.month, today.day);

        for (var timestamp in checkInList) {
          DateTime checkInDate;
          if (timestamp is Timestamp) {
            checkInDate = timestamp.toDate();
          } else if (timestamp is int) {
            checkInDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          } else {
            continue;
          }

          DateTime checkInNormalized = DateTime(
              checkInDate.year, checkInDate.month, checkInDate.day);
          if (checkInNormalized.isAtSameMomentAs(todayNormalized)) {
            return true;
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint("Error checking today's check-in: $e");
      return false;
    }
  }

  Future<Map<DateTime, bool>> getGoalCompletionCalendar(
      String goalId, DateTime startDate, DateTime endDate) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('recycling_goals')
          .doc(goalId)
          .get();

      if (doc.exists) {
        RecyclingGoal goal = RecyclingGoal.fromMap({
          ...doc.data() as Map<String, dynamic>,
          'id': doc.id,
        });
        return goal.getCompletionStatusForRange(startDate, endDate);
      }

      return {};
    } catch (e) {
      debugPrint("Error getting completion calendar: $e");
      return {};
    }
  }

  Future<void> updateGoalProgress(
      String goalId, double additionalProgress) async {
    await recordDailyCheckIn(goalId, additionalProgress);
  }

  Future<void> deleteRecyclingGoal(String goalId) async {
    try {
      final notificationService = NotificationService();
      await notificationService.cancelGoalReminders(goalId);
      await _firestore.collection('recycling_goals').doc(goalId).delete();
    } catch (e) {
      debugPrint("Error deleting recycling goal: $e");
      rethrow;
    }
  }
}
