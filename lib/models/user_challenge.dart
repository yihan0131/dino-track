import 'package:cloud_firestore/cloud_firestore.dart';

class UserChallenge {
  final String id;
  final String userId;
  final String challengeId;
  final DateTime joinDate;
  int currentStreak;
  int highestStreak;
  List<DateTime> checkInDates;
  bool completed;
  final List<Map<String, dynamic>> checkInPhotos;

  // Constructor
  UserChallenge({
    required this.id,
    required this.userId,
    required this.challengeId,
    required this.joinDate,
    this.currentStreak = 0,
    this.highestStreak = 0,
    required this.checkInDates,
    this.completed = false,
    this.checkInPhotos = const [],
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'challengeId': challengeId,
      'joinDate': joinDate.millisecondsSinceEpoch,
      'currentStreak': currentStreak,
      'highestStreak': highestStreak,
      'checkInDates': checkInDates.map((date) => date.millisecondsSinceEpoch)
          .toList(),
      'completed': completed,
      'checkInPhotos': checkInPhotos,
    };
  }

  // Create from Map (from Firestore)
  factory UserChallenge.fromMap(Map<String, dynamic> map) {
    List<DateTime> dates = [];
    if (map['checkInDates'] != null) {
      dates = (map['checkInDates'] as List).map((item) {
        // Handle both Timestamp and int types
        if (item is Timestamp) {
          return item.toDate();
        } else if (item is int) {
          return DateTime.fromMillisecondsSinceEpoch(item);
        } else {
          // Default fallback
          return DateTime.now();
        }
      }).toList();
    }

    return UserChallenge(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      challengeId: map['challengeId'] ?? '',
      // Handle both Timestamp and int for joinDate
      joinDate: map['joinDate'] is Timestamp
          ? (map['joinDate'] as Timestamp).toDate()
          : (map['joinDate'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['joinDate'])
          : DateTime.now()),
      currentStreak: map['currentStreak'] ?? 0,
      highestStreak: map['highestStreak'] ?? 0,
      checkInDates: dates,
      completed: map['completed'] ?? false,
      checkInPhotos: List<Map<String, dynamic>>.from(
          map['checkInPhotos'] ?? []),
    );
  }
}