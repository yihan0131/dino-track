import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import '../models/recycling_goal.dart';


class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

// Initialize notifications (call this in your app startup)
  Future<void> initializeNotifications() async {
    if (kIsWeb) return;
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

// Request notification permissions
  Future<bool> requestNotificationPermissions() async {
    if (kIsWeb) return false;
    try {
      // Request permission
      PermissionStatus status = await Permission.notification.request();

      if (status.isGranted) {
        // Also request permission from the local notifications plugin for iOS
        if (Platform.isIOS) {
          final bool? result = await _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return result ?? false;
        }
        return true;
      }

      return false;
    } catch (e) {
      print("Error requesting notification permissions: $e");
      return false;
    }
  }


// Schedule reminders for a goal
  Future<void> scheduleGoalReminders(String goalId, RecyclingGoal goal, DateTime reminderTime) async {
    if (kIsWeb) return;
    try {
      DateTime startDate = goal.startDate;
      DateTime endDate = goal.endDate;

      List<DateTime> reminderDates = [];

      // Calculate reminder dates based on frequency
      switch (goal.frequency.toLowerCase()) {
        case 'daily':
        // Schedule daily reminders
          DateTime currentDate = startDate;
          while (currentDate.isBefore(endDate) ||
              currentDate.isAtSameMomentAs(endDate)) {
            DateTime scheduledTime = DateTime(
              currentDate.year,
              currentDate.month,
              currentDate.day,
              reminderTime.hour,
              reminderTime.minute,
            );

            if (scheduledTime.isAfter(DateTime.now())) {
              reminderDates.add(scheduledTime);
            }

            currentDate = currentDate.add(Duration(days: 1));
          }
          break;

        case 'weekly':
        // FIXED: Schedule weekly reminders for the selected day
        // Find which day is selected (should be only one for weekly)
          int selectedDayIndex = -1;
          for (int i = 0; i < goal.selectedDays.length; i++) {
            if (goal.selectedDays[i]) {
              selectedDayIndex = i;
              break;
            }
          }

          if (selectedDayIndex != -1) {
            // Iterate through each day and find occurrences of the selected weekday
            DateTime currentDate = startDate;
            while (currentDate.isBefore(endDate) ||
                currentDate.isAtSameMomentAs(endDate)) {
              int weekday = currentDate.weekday;
              // Convert to 0-based index (Monday = 0, Sunday = 6)
              int dayIndex = weekday == 7 ? 6 : weekday - 1;

              // If this day matches the selected day, schedule a reminder
              if (dayIndex == selectedDayIndex) {
                DateTime scheduledTime = DateTime(
                  currentDate.year,
                  currentDate.month,
                  currentDate.day,
                  reminderTime.hour,
                  reminderTime.minute,
                );

                if (scheduledTime.isAfter(DateTime.now())) {
                  reminderDates.add(scheduledTime);
                }
              }

              currentDate = currentDate.add(Duration(days: 1));
            }
          }
          break;

        case 'custom':
        // Schedule reminders for selected days (this logic was already correct)
          DateTime currentDate = startDate;
          while (currentDate.isBefore(endDate) ||
              currentDate.isAtSameMomentAs(endDate)) {
            int weekday = currentDate.weekday;
            // Convert to 0-based index (Monday = 0, Sunday = 6)
            int dayIndex = weekday == 7 ? 6 : weekday - 1;

            if (goal.selectedDays[dayIndex]) {
              DateTime scheduledTime = DateTime(
                currentDate.year,
                currentDate.month,
                currentDate.day,
                reminderTime.hour,
                reminderTime.minute,
              );

              if (scheduledTime.isAfter(DateTime.now())) {
                reminderDates.add(scheduledTime);
              }
            }

            currentDate = currentDate.add(Duration(days: 1));
          }
          break;
      }

      // Schedule notifications for all reminder dates
      for (int i = 0; i < reminderDates.length; i++) {
        await _scheduleNotification(
          id: goalId.hashCode + i,
          // Unique ID for each notification
          title: 'Recycling Goal Reminder',
          body: 'Don\'t forget: ${goal.title}',
          scheduledDate: reminderDates[i],
          payload: goalId,
        );
      }

      print("Scheduled ${reminderDates.length} reminders for goal: ${goal
          .title}");
      print("Reminder dates: ${reminderDates.map((d) =>
          DateFormat('MMM d, yyyy HH:mm').format(d)).join(', ')}");
    } catch (e) {
      print("Error scheduling goal reminders: $e");
    }
  }

// Schedule a single notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'recycling_goals',
        'Recycling Goal Reminders',
        channelDescription: 'Notifications for recycling goal reminders',
        importance: Importance.high,
        priority: Priority.high,
      );

      const DarwinNotificationDetails iOSPlatformChannelSpecifics =
      DarwinNotificationDetails();

      const NotificationDetails platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics,
      );

      await _flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        payload: payload,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,

      );
    } catch (e) {
      print("Error scheduling notification: $e");
    }
  }

// Cancel all notifications for a goal
  Future<void> cancelGoalReminders(String goalId) async {
    if (kIsWeb) return;
    try {
      // Cancel notifications with IDs based on goalId
      // Since we used goalId.hashCode + i, we need to cancel a range
      for (int i = 0; i < 100; i++) { // Assuming max 100 reminders per goal
        await _flutterLocalNotificationsPlugin.cancel(goalId.hashCode + i);
      }
    } catch (e) {
      print("Error canceling goal reminders: $e");
    }
  }

// Update reminders for an existing goal
  Future<void> updateGoalReminders(String goalId, RecyclingGoal goal, {
    required bool reminderEnabled,
    DateTime? reminderTime,
  }) async {
    if (kIsWeb) return;
    try {
      // First, cancel all existing reminders for this goal
      await cancelGoalReminders(goalId);

      // If reminders are enabled, schedule new ones
      if (reminderEnabled && reminderTime != null) {
        await scheduleGoalReminders(goalId, goal, reminderTime);
      }

      // Update the goal in Firestore with new reminder settings
      await _firestore.collection('recycling_goals').doc(goalId).update({
        'reminderEnabled': reminderEnabled,
        'reminderTime': reminderEnabled
            ? reminderTime?.millisecondsSinceEpoch
            : null,
      });
    } catch (e) {
      print("Error updating goal reminders: $e");
      rethrow;
    }
  }

}