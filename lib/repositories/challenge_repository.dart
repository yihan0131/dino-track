import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/eco_challenge.dart';
import '../models/user_challenge.dart';
import '../service/cloudinary_service.dart';
import 'user_repository.dart';

class ChallengeRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid = const Uuid();
  final CloudinaryService _cloudinaryService;
  final UserRepository _userRepository;

  /// The app uses the defaults; tests can pass a fake database and services.
  ChallengeRepository({
    FirebaseFirestore? firestore,
    CloudinaryService? cloudinaryService,
    UserRepository? userRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _cloudinaryService = cloudinaryService ?? CloudinaryService(),
        _userRepository =
            userRepository ?? UserRepository(firestore: firestore);

  String? _currentUserId() =>
      auth.FirebaseAuth.instance.currentUser?.uid;

  Future<List<EcoChallenge>> getAvailableEcoChallenges() async {
    try {
      String? currentUserId = _currentUserId();
      if (currentUserId == null) return [];

      QuerySnapshot querySnapshot =
          await _firestore.collection('eco_challenges').get();

      QuerySnapshot userChallengesSnapshot = await _firestore
          .collection('user_challenges')
          .where('userId', isEqualTo: currentUserId)
          .get();

      Set<String> joinedChallengeIds = userChallengesSnapshot.docs
          .map((doc) =>
              (doc.data() as Map<String, dynamic>)['challengeId'] as String)
          .toSet();

      List<EcoChallenge> challenges = [];

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;

        if (!data.containsKey('isPrivate')) {
          data['isPrivate'] = false;
          await _firestore
              .collection('eco_challenges')
              .doc(doc.id)
              .update({'isPrivate': false});
        }

        bool isPublic = data['isPrivate'] == false;
        bool isCreatedByCurrentUser = data['createdBy'] == currentUserId;
        bool isSystemCreated = data['createdBy'] == 'system';
        bool hasJoined = joinedChallengeIds.contains(doc.id);

        if (isPublic || isCreatedByCurrentUser || isSystemCreated || hasJoined) {
          challenges.add(EcoChallenge.fromMap(data));
        }
      }

      return challenges;
    } catch (e) {
      debugPrint("Error getting available eco challenges: $e");
      return [];
    }
  }

  Future<String> createEcoChallenge(EcoChallenge challenge,
      {File? imageFile}) async {
    try {
      final challengeId =
          challenge.id.isEmpty ? _uuid.v4() : challenge.id;

      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _cloudinaryService.uploadImage(
            imageFile, 'eco_challenges');
      }

      String createdBy = _currentUserId() ?? '';

      EcoChallenge challengeToSave = EcoChallenge(
        id: challengeId,
        title: challenge.title,
        description: challenge.description,
        durationDays: challenge.durationDays,
        imageUrl: imageUrl ?? challenge.imageUrl,
        startDate: challenge.startDate,
        endDate: challenge.endDate,
        participantsCount: 0,
        isPrivate: challenge.isPrivate,
      );

      Map<String, dynamic> challengeData = challengeToSave.toMap();
      challengeData['createdBy'] = createdBy;

      await _firestore
          .collection('eco_challenges')
          .doc(challengeId)
          .set(challengeData);
      return challengeId;
    } catch (e) {
      debugPrint("Error creating eco-challenge: $e");
      rethrow;
    }
  }

  Future<String> createEcoChallengeWithCode(EcoChallenge challenge,
      {File? imageFile, String? code}) async {
    try {
      final challengeId =
          challenge.id.isEmpty ? _uuid.v4() : challenge.id;

      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _cloudinaryService.uploadImage(
            imageFile, 'eco_challenges');
      }

      String createdBy = _currentUserId() ?? '';

      EcoChallenge challengeToSave = EcoChallenge(
        id: challengeId,
        title: challenge.title,
        description: challenge.description,
        durationDays: challenge.durationDays,
        imageUrl: imageUrl ?? challenge.imageUrl,
        startDate: challenge.startDate,
        endDate: challenge.endDate,
        participantsCount: 0,
        isPrivate: true,
      );

      final data = challengeToSave.toMap();
      if (code != null && code.isNotEmpty) {
        data['code'] = code;
      }
      data['createdBy'] = createdBy;

      await _firestore
          .collection('eco_challenges')
          .doc(challengeId)
          .set(data);
      return challengeId;
    } catch (e) {
      debugPrint("Error creating eco-challenge with code: $e");
      rethrow;
    }
  }

  Future<bool> isChallengeCodeUnique(String code) async {
    final query = await _firestore
        .collection('eco_challenges')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();
    return query.docs.isEmpty;
  }

  Future<EcoChallenge?> getChallengeByCode(String code) async {
    try {
      final query = await _firestore
          .collection('eco_challenges')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        data['id'] = query.docs.first.id;
        return EcoChallenge.fromMap(data);
      }
      return null;
    } catch (e) {
      debugPrint("Error getting challenge by code: $e");
      return null;
    }
  }

  Future<String?> joinChallengeByCode(String userId, String code) async {
    final challenge = await getChallengeByCode(code);
    if (challenge != null) {
      return joinChallenge(userId, challenge.id);
    }
    return null;
  }

  Future<String> joinChallenge(String userId, String challengeId) async {
    try {
      QuerySnapshot existingJoins = await _firestore
          .collection('user_challenges')
          .where('userId', isEqualTo: userId)
          .where('challengeId', isEqualTo: challengeId)
          .limit(1)
          .get();

      if (existingJoins.docs.isNotEmpty) {
        return existingJoins.docs.first.id;
      }

      final userChallengeId = _uuid.v4();

      DocumentSnapshot challengeDoc = await _firestore
          .collection('eco_challenges')
          .doc(challengeId)
          .get();

      if (!challengeDoc.exists) throw Exception("Challenge not found");

      UserChallenge userChallenge = UserChallenge(
        id: userChallengeId,
        userId: userId,
        challengeId: challengeId,
        joinDate: DateTime.now(),
        currentStreak: 0,
        highestStreak: 0,
        checkInDates: [],
        completed: false,
      );

      await _firestore
          .collection('user_challenges')
          .doc(userChallengeId)
          .set(userChallenge.toMap());

      await _firestore
          .collection('eco_challenges')
          .doc(challengeId)
          .update({'participantsCount': FieldValue.increment(1)});

      return userChallengeId;
    } catch (e) {
      debugPrint("Error joining challenge: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> checkInChallenge(String userChallengeId,
      {File? photoFile}) async {
    try {
      DocumentSnapshot userChallengeDoc = await _firestore
          .collection('user_challenges')
          .doc(userChallengeId)
          .get();

      if (!userChallengeDoc.exists) {
        throw Exception("User challenge not found");
      }

      Map<String, dynamic> userChallengeData =
          userChallengeDoc.data() as Map<String, dynamic>;
      String challengeId = userChallengeData['challengeId'];
      String userId = userChallengeData['userId'];

      bool isDefault = await isDefaultChallenge(challengeId);

      String? photoUrl;
      if (photoFile != null) {
        photoUrl = await _cloudinaryService.uploadImage(
          photoFile,
          'challenge_checkins',
          metadata: {
            'userId': userId,
            'challengeId': challengeId,
            'userChallengeId': userChallengeId,
            'isDefaultChallenge': isDefault,
            'date': DateTime.now().millisecondsSinceEpoch,
            'isReported': false,
          },
        );
      }

      bool alreadyCheckedIn = false;
      int pointsAwarded = 0;

      if (isDefault && photoUrl != null) {
        pointsAwarded = 2;
        await _userRepository.updateEcoPoints(userId, pointsAwarded);
      }

      await _firestore.runTransaction((transaction) async {
        DocumentReference userChallengeRef = _firestore
            .collection('user_challenges')
            .doc(userChallengeId);
        DocumentSnapshot doc = await transaction.get(userChallengeRef);

        if (doc.exists) {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

          List<dynamic> checkInDatesRaw = data['checkInDates'] ?? [];
          List<DateTime> checkInDates = checkInDatesRaw.map((timestamp) {
            return (timestamp is Timestamp)
                ? timestamp.toDate()
                : DateTime.fromMillisecondsSinceEpoch(timestamp);
          }).toList();

          DateTime today = DateTime.now();
          DateTime dateOnly =
              DateTime(today.year, today.month, today.day);

          alreadyCheckedIn = checkInDates.any((date) {
            return date.year == dateOnly.year &&
                date.month == dateOnly.month &&
                date.day == dateOnly.day;
          });

          if (!alreadyCheckedIn) {
            checkInDates.add(dateOnly);

            int currentStreak = data['currentStreak'] ?? 0;
            int highestStreak = data['highestStreak'] ?? 0;

            if (checkInDates.length > 1) {
              DateTime yesterday = DateTime(
                  dateOnly.year, dateOnly.month, dateOnly.day - 1);
              bool checkedInYesterday = checkInDates.any((date) {
                return date.year == yesterday.year &&
                    date.month == yesterday.month &&
                    date.day == yesterday.day;
              });
              currentStreak = checkedInYesterday ? currentStreak + 1 : 1;
            } else {
              currentStreak = 1;
            }

            if (currentStreak > highestStreak) {
              highestStreak = currentStreak;
            }

            List<Map<String, dynamic>> checkInPhotos =
                List<Map<String, dynamic>>.from(
                    data['checkInPhotos'] ?? []);

            if (photoUrl != null) {
              checkInPhotos.add({
                'date': dateOnly.millisecondsSinceEpoch,
                'photoUrl': photoUrl,
                'userId': data['userId'],
                'reported': false,
                'approved': true,
                'visible': true,
              });
            }

            transaction.update(userChallengeRef, {
              'checkInDates': checkInDates
                  .map((date) => date.millisecondsSinceEpoch)
                  .toList(),
              'currentStreak': currentStreak,
              'highestStreak': highestStreak,
              'checkInPhotos': checkInPhotos,
            });

            DocumentSnapshot challengeDoc = await _firestore
                .collection('eco_challenges')
                .doc(challengeId)
                .get();

            if (challengeDoc.exists) {
              Map<String, dynamic> challengeData =
                  challengeDoc.data() as Map<String, dynamic>;
              int durationDays = challengeData['durationDays'] ?? 0;
              if (currentStreak >= durationDays) {
                transaction
                    .update(userChallengeRef, {'completed': true});
              }
            }
          }
        }
      });

      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(userId).get();
      int currentPoints = userDoc.exists
          ? (userDoc.data() as Map<String, dynamic>)['ecoPoints'] ?? 0
          : 0;

      return {
        'success': true,
        'alreadyCheckedIn': alreadyCheckedIn,
        'photoUploaded': photoUrl != null,
        'isDefaultChallenge': isDefault,
        'pointsAwarded': pointsAwarded,
        'currentPoints': currentPoints,
      };
    } catch (e) {
      debugPrint("Error checking in challenge: $e");
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<List<Map<String, dynamic>>> getChallengeCheckInPhotos(
      String challengeId) async {
    try {
      QuerySnapshot userChallenges = await _firestore
          .collection('user_challenges')
          .where('challengeId', isEqualTo: challengeId)
          .get();

      QuerySnapshot allReports = await _firestore
          .collection('photo_reports')
          .where('challengeId', isEqualTo: challengeId)
          .get();

      Map<String, String> reportStatusMap = {};
      for (var doc in allReports.docs) {
        Map<String, dynamic> reportData =
            doc.data() as Map<String, dynamic>;
        String key =
            "${reportData['photoUrl']}|${reportData['userChallengeId']}";
        reportStatusMap[key] = reportData['status'] ?? 'pending';
      }

      List<Map<String, dynamic>> allPhotos = [];

      for (var doc in userChallenges.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String userId = data['userId'];
        String userChallengeId = doc.id;

        DocumentSnapshot userDoc =
            await _firestore.collection('users').doc(userId).get();
        String username = userDoc.exists
            ? (userDoc.data() as Map<String, dynamic>)['username'] ?? 'User'
            : 'User';

        List<Map<String, dynamic>> photos =
            List<Map<String, dynamic>>.from(data['checkInPhotos'] ?? []);

        for (var photo in photos) {
          if (photo['photoUrl'] != null &&
              (photo['photoUrl'] as String).isNotEmpty) {
            photo['username'] = username;
            photo['userId'] = userId;
            photo['userChallengeId'] = userChallengeId;

            String key = "${photo['photoUrl']}|$userChallengeId";
            if (reportStatusMap.containsKey(key)) {
              String status = reportStatusMap[key]!;
              if (status == 'pending') {
                photo['reported'] = true;
                photo['approved'] = false;
              } else if (status == 'rejected') {
                photo['rejected'] = true;
                photo['reported'] = false;
                photo['approved'] = false;
                photo['visible'] = false;
              } else if (status == 'approved') {
                photo['approved'] = true;
                photo['reported'] = false;
                photo['rejected'] = false;
              }
            }

            allPhotos.add(photo);
          }
        }
      }

      allPhotos.sort((a, b) => (b['date'] ?? 0).compareTo(a['date'] ?? 0));
      return allPhotos;
    } catch (e) {
      debugPrint("Error getting challenge check-in photos: $e");
      return [];
    }
  }

  Future<bool> isDefaultChallenge(String challengeId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('eco_challenges')
          .doc(challengeId)
          .get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>)['createdBy'] == 'system';
      }
      return false;
    } catch (e) {
      debugPrint("Error checking if challenge is default: $e");
      return false;
    }
  }

  Future<void> reportCheckInPhoto(
      String userChallengeId, String photoUrl) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('user_challenges')
          .doc(userChallengeId)
          .get();

      if (!doc.exists) throw Exception("User challenge not found");

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<Map<String, dynamic>> photos =
          List<Map<String, dynamic>>.from(data['checkInPhotos'] ?? []);

      bool photoFound = false;
      for (int i = 0; i < photos.length; i++) {
        if (photos[i]['photoUrl'] == photoUrl) {
          photoFound = true;
          photos[i]['reported'] = true;
          break;
        }
      }

      if (!photoFound) throw Exception("Photo not found in this challenge");

      await _firestore
          .collection('user_challenges')
          .doc(userChallengeId)
          .update({'checkInPhotos': photos});

      await _firestore.collection('photo_reports').add({
        'userChallengeId': userChallengeId,
        'photoUrl': photoUrl,
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'userId': data['userId'],
        'challengeId': data['challengeId'],
        'reportedBy': _currentUserId(),
        'processed': false,
      });

      await _cloudinaryService.markImageAsReported(photoUrl,
          reason: 'Reported by user');
    } catch (e) {
      debugPrint("Error reporting check-in photo: $e");
      rethrow;
    }
  }

  Future<void> approveReportedPhoto(
      String photoUrl, String userChallengeId) async {
    try {
      await _cloudinaryService.approveReportedImage(photoUrl);

      DocumentSnapshot doc = await _firestore
          .collection('user_challenges')
          .doc(userChallengeId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        List<Map<String, dynamic>> photos =
            List<Map<String, dynamic>>.from(data['checkInPhotos'] ?? []);

        for (int i = 0; i < photos.length; i++) {
          if (photos[i]['photoUrl'] == photoUrl) {
            photos[i]['reported'] = false;
            photos[i]['approved'] = true;
            photos[i]['rejected'] = false;
            photos[i]['visible'] = true;
            photos[i]['reviewedAt'] = DateTime.now().millisecondsSinceEpoch;
            break;
          }
        }

        await _firestore
            .collection('user_challenges')
            .doc(userChallengeId)
            .update({
          'checkInPhotos': photos,
          'status': 'approved',
          'reviewedAt': DateTime.now().millisecondsSinceEpoch,
        });

        QuerySnapshot reports = await _firestore
            .collection('photo_reports')
            .where('photoUrl', isEqualTo: photoUrl)
            .where('userChallengeId', isEqualTo: userChallengeId)
            .get();

        for (var report in reports.docs) {
          await report.reference.update({
            'status': 'approved',
            'processed': true,
            'reviewedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      debugPrint("Error approving reported photo: $e");
      rethrow;
    }
  }

  Future<void> rejectReportedPhoto(
      String photoUrl, String userChallengeId) async {
    try {
      await _cloudinaryService.rejectReportedImage(photoUrl);

      DocumentSnapshot doc = await _firestore
          .collection('user_challenges')
          .doc(userChallengeId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String userId = data['userId'];
        String challengeId = data['challengeId'];
        List<Map<String, dynamic>> photos =
            List<Map<String, dynamic>>.from(data['checkInPhotos'] ?? []);

        for (int i = 0; i < photos.length; i++) {
          if (photos[i]['photoUrl'] == photoUrl) {
            photos[i]['reported'] = false;
            photos[i]['approved'] = false;
            photos[i]['rejected'] = true;
            photos[i]['visible'] = false;
            photos[i]['reviewedAt'] = DateTime.now().millisecondsSinceEpoch;
            break;
          }
        }

        await _firestore
            .collection('user_challenges')
            .doc(userChallengeId)
            .update({
          'checkInPhotos': photos,
          'status': 'rejected',
          'reviewedAt': DateTime.now().millisecondsSinceEpoch,
        });

        QuerySnapshot reports = await _firestore
            .collection('photo_reports')
            .where('photoUrl', isEqualTo: photoUrl)
            .where('userChallengeId', isEqualTo: userChallengeId)
            .get();

        // Only reports not settled before can cost points, so rejecting
        // twice (or an old background job) never deducts twice.
        final newReportIds = <String>[];
        for (var report in reports.docs) {
          final reportData = report.data() as Map<String, dynamic>;
          if (reportData['processed'] != true) newReportIds.add(report.id);
          await report.reference.update({
            'status': 'rejected',
            'processed': true,
            'reviewedAt': FieldValue.serverTimestamp(),
          });
        }

        bool isDefault = await isDefaultChallenge(challengeId);
        if (isDefault && newReportIds.isNotEmpty) {
          await _userRepository.updateEcoPoints(userId, -2);
          await _firestore.collection('users').doc(userId).update({
            'processedReports': FieldValue.arrayUnion(newReportIds),
          });
        }
      }
    } catch (e) {
      debugPrint("Error rejecting reported photo: $e");
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserChallenges(String userId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('user_challenges')
          .where('userId', isEqualTo: userId)
          .get();

      List<Map<String, dynamic>> userChallenges = [];

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> userChallengeData =
            doc.data() as Map<String, dynamic>;
        userChallengeData['id'] = doc.id;

        String challengeId = userChallengeData['challengeId'];
        DocumentSnapshot challengeDoc = await _firestore
            .collection('eco_challenges')
            .doc(challengeId)
            .get();

        if (challengeDoc.exists) {
          Map<String, dynamic> challengeData =
              challengeDoc.data() as Map<String, dynamic>;
          challengeData['id'] = challengeDoc.id;

          userChallenges.add({
            'userChallenge': userChallengeData,
            'challenge': challengeData,
          });
        }
      }

      return userChallenges;
    } catch (e) {
      debugPrint("Error getting user challenges: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getChallengeLeaderboard(
      String challengeId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('user_challenges')
          .where('challengeId', isEqualTo: challengeId)
          .get();

      if (querySnapshot.docs.isEmpty) return [];

      List<Map<String, dynamic>> tempLeaderboard = [];
      List<Future<void>> userFutures = [];

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> userChallengeData =
            doc.data() as Map<String, dynamic>;
        String userId = userChallengeData['userId'];

        List<dynamic> checkInDates =
            userChallengeData['checkInDates'] ?? [];
        int totalCheckIns = checkInDates.length;
        int currentStreak = userChallengeData['currentStreak'] ?? 0;
        int highestStreak = userChallengeData['highestStreak'] ?? 0;
        bool completed = userChallengeData['completed'] ?? false;
        int score = (totalCheckIns * 10) + (currentStreak * 5);

        Map<String, dynamic> entry = {
          'userId': userId,
          'username': 'Loading...',
          'totalCheckIns': totalCheckIns,
          'currentStreak': currentStreak,
          'highestStreak': highestStreak,
          'score': score,
          'completed': completed,
          'streak': currentStreak,
        };

        tempLeaderboard.add(entry);

        userFutures.add(() async {
          try {
            DocumentSnapshot userDoc =
                await _firestore.collection('users').doc(userId).get();
            if (userDoc.exists) {
              Map<String, dynamic> userData =
                  userDoc.data() as Map<String, dynamic>;
              entry['username'] = userData['username'] ??
                  userData['displayName'] ??
                  'User';
            } else {
              entry['username'] = 'Unknown User';
            }
          } catch (e) {
            entry['username'] = 'User';
          }
        }());
      }

      await Future.wait(userFutures);
      tempLeaderboard.sort((a, b) => b['score'].compareTo(a['score']));
      return tempLeaderboard;
    } catch (e) {
      debugPrint("Error getting challenge leaderboard: $e");
      return [];
    }
  }

  Future<String> getChallengeCreator(String challengeId) async {
    try {
      final challengeDoc = await _firestore
          .collection('eco_challenges')
          .doc(challengeId)
          .get();

      if (!challengeDoc.exists ||
          !challengeDoc.data()!.containsKey('createdBy')) {
        return "";
      }

      final createdById = challengeDoc.data()!['createdBy'];
      final userDoc =
          await _firestore.collection('users').doc(createdById).get();

      if (!userDoc.exists) return "";

      return userDoc.data()!['username'] ??
          userDoc.data()!['displayName'] ??
          "";
    } catch (e) {
      debugPrint("Error getting challenge creator: $e");
      return "";
    }
  }

  Future<void> leaveChallenge(String userChallengeId) async {
    try {
      final userChallengeDoc = await _firestore
          .collection('user_challenges')
          .doc(userChallengeId)
          .get();

      if (userChallengeDoc.exists) {
        final challengeId = userChallengeDoc.data()!['challengeId'];
        await _firestore
            .collection('user_challenges')
            .doc(userChallengeId)
            .delete();
        await _firestore
            .collection('eco_challenges')
            .doc(challengeId)
            .update({'participantsCount': FieldValue.increment(-1)});
      }
    } catch (e) {
      debugPrint("Error leaving challenge: $e");
      rethrow;
    }
  }

  Future<String> getPhotoStatus(
      String photoUrl, String userChallengeId) async {
    try {
      QuerySnapshot reports = await _firestore
          .collection('photo_reports')
          .where('photoUrl', isEqualTo: photoUrl)
          .where('userChallengeId', isEqualTo: userChallengeId)
          .get();

      if (reports.docs.isNotEmpty) {
        return (reports.docs.first.data()
                as Map<String, dynamic>)['status'] ??
            'pending';
      }

      DocumentSnapshot userChallengeDoc = await _firestore
          .collection('user_challenges')
          .doc(userChallengeId)
          .get();

      if (userChallengeDoc.exists) {
        final data = userChallengeDoc.data() as Map<String, dynamic>;
        final photos =
            List<Map<String, dynamic>>.from(data['checkInPhotos'] ?? []);

        for (var photo in photos) {
          if (photo['photoUrl'] == photoUrl) {
            if (photo['rejected'] == true) return 'rejected';
            if (photo['approved'] == true) return 'approved';
            if (photo['reported'] == true) return 'pending';
            return 'active';
          }
        }
      }

      return 'active';
    } catch (e) {
      debugPrint("Error getting photo status: $e");
      return 'active';
    }
  }

  Future<List<Map<String, dynamic>>> getPendingReports() async {
    final snapshot = await _firestore
        .collection('photo_reports')
        .where('status', isEqualTo: 'pending')
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'reportId': doc.id,
        'photoUrl': data['photoUrl'] ?? '',
        'userChallengeId': data['userChallengeId'] ?? '',
        'userId': data['userId'] ?? '',
        'challengeId': data['challengeId'] ?? '',
        'reportedBy': data['reportedBy'] ?? '',
        'reportedAt': data['reportedAt'],
        'status': data['status'] ?? 'pending',
      };
    }).toList();
  }

  Future<void> initializeDatabase() async {
    try {
      await updateDefaultChallenges();
    } catch (e) {
      debugPrint("Error in initializeDatabase: $e");
      rethrow;
    }
  }

  /// The monthly window system challenges run in: the 1st of [now]'s month
  /// up to the 1st of the next month (December rolls over into January).
  static ({DateTime start, DateTime end}) monthlyCycle(DateTime now) {
    return (
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 1),
    );
  }

  Future<void> updateDefaultChallenges() async {
    try {
      // System challenges run on a monthly cycle so they never go stale.
      // They used to be hard-coded to mid-2025 and showed as ended afterwards.
      final cycle = monthlyCycle(DateTime.now());
      final cycleStart = cycle.start;
      final cycleEnd = cycle.end;

      List<Map<String, dynamic>> defaultChallenges = [
        {
          'title': 'Bring Your Own Bottle',
          'description':
              'Use a reusable water bottle every day instead of buying bottled drinks.',
          'durationDays': 30,
          'pointsReward': 150,
          'startDate': cycleStart,
          'endDate': cycleEnd,
          'imageUrl': 'eco_challenge1',
          'isPrivate': false,
        },
        {
          'title': 'Say No to Plastic Bags',
          'description': 'Avoid using plastic bags when shopping.',
          'durationDays': 30,
          'pointsReward': 120,
          'startDate': cycleStart,
          'endDate': cycleEnd,
          'imageUrl': 'eco_challenge2',
          'isPrivate': false,
        },
        {
          'title': 'Recycle at Home',
          'description': 'Sort your household waste for recycling.',
          'durationDays': 30,
          'pointsReward': 250,
          'startDate': cycleStart,
          'endDate': cycleEnd,
          'imageUrl': 'eco_challenge3',
          'isPrivate': false,
        },
      ];

      QuerySnapshot systemChallengesSnapshot = await _firestore
          .collection('eco_challenges')
          .where('createdBy', isEqualTo: 'system')
          .get();

      List<DocumentSnapshot> existingChallenges =
          systemChallengesSnapshot.docs;

      Map<String, DocumentSnapshot> existingByTitle = {};
      for (var doc in existingChallenges) {
        String title =
            (doc.data() as Map<String, dynamic>)['title'];
        existingByTitle[title] = doc;
      }

      for (var challengeData in defaultChallenges) {
        String title = challengeData['title'];

        if (existingByTitle.containsKey(title)) {
          DocumentSnapshot existingDoc = existingByTitle[title]!;
          await _firestore
              .collection('eco_challenges')
              .doc(existingDoc.id)
              .update({
            'description': challengeData['description'],
            'durationDays': challengeData['durationDays'],
            'pointsReward': challengeData['pointsReward'],
            'startDate': challengeData['startDate'],
            'endDate': challengeData['endDate'],
            'imageUrl': challengeData['imageUrl'],
            'isPrivate': challengeData['isPrivate'],
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          EcoChallenge newChallenge = EcoChallenge(
            id: '',
            title: challengeData['title'],
            description: challengeData['description'],
            durationDays: challengeData['durationDays'],
            imageUrl: challengeData['imageUrl'],
            startDate: challengeData['startDate'],
            endDate: challengeData['endDate'],
            participantsCount: 0,
            isPrivate: challengeData['isPrivate'],
          );

          final challengeId = await createEcoChallenge(newChallenge);
          await _firestore
              .collection('eco_challenges')
              .doc(challengeId)
              .update({'createdBy': 'system'});
        }
      }

      Set<String> currentDefaultTitles =
          defaultChallenges.map((c) => c['title'] as String).toSet();
      for (var doc in existingChallenges) {
        String title =
            (doc.data() as Map<String, dynamic>)['title'];
        if (!currentDefaultTitles.contains(title)) {
          await _firestore
              .collection('eco_challenges')
              .doc(doc.id)
              .delete();
        }
      }
    } catch (e) {
      debugPrint("Error updating default challenges: $e");
      rethrow;
    }
  }
}
