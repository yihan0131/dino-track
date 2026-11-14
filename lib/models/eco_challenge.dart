import 'package:cloud_firestore/cloud_firestore.dart';

class EcoChallenge {
  final String id;
  final String title;
  final String description;
  final int durationDays;
  final String imageUrl;
  final DateTime startDate;
  final DateTime endDate;
  final int participantsCount;
  final bool isPrivate;

  // Constructor
  EcoChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.durationDays,
    required this.imageUrl,
    required this.startDate,
    required this.endDate,
    this.participantsCount = 0,
    this.isPrivate = false,
  });

  /// 0 = active, 1 = upcoming, 2 = ended (same rules as the list's badges).
  int displayRank(DateTime now) {
    if (now.isAfter(endDate)) return 2;
    if (now.isBefore(startDate)) return 1;
    return 0;
  }

  /// Order for the challenge list: active first (ending soonest on top),
  /// then upcoming (starting soonest), then ended (most recently ended).
  static List<EcoChallenge> sortedForDisplay(
      List<EcoChallenge> challenges, DateTime now) {
    final sorted = List<EcoChallenge>.from(challenges);
    sorted.sort((a, b) {
      final rankA = a.displayRank(now);
      final rankB = b.displayRank(now);
      if (rankA != rankB) return rankA.compareTo(rankB);
      switch (rankA) {
        case 0:
          return a.endDate.compareTo(b.endDate);
        case 1:
          return a.startDate.compareTo(b.startDate);
        default:
          return b.endDate.compareTo(a.endDate);
      }
    });
    return sorted;
  }

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'durationDays': durationDays,
      'imageUrl': imageUrl,
      'startDate': startDate.millisecondsSinceEpoch,
      'endDate': endDate.millisecondsSinceEpoch,
      'participantsCount': participantsCount,
      'isPrivate': isPrivate,
    };
  }

  // Create from Map (from Firestore)
  factory EcoChallenge.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic date) {
      if (date is Timestamp) {
        return date.toDate();
      } else if (date is int) {
        return DateTime.fromMillisecondsSinceEpoch(date);
      } else {
        return DateTime.now(); // fallback
      }
    }

    return EcoChallenge(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      durationDays: map['durationDays'] ?? 0,
      imageUrl: map['imageUrl'] ?? '',
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      participantsCount: map['participantsCount'] ?? 0,
      isPrivate: map['isPrivate'] ?? false,
    );
  }
}