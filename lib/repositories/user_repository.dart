import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final auth.FirebaseAuth? _authOverride;

  /// The app uses the defaults; tests can pass a fake database.
  UserRepository({FirebaseFirestore? firestore, auth.FirebaseAuth? authInstance})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _authOverride = authInstance;

  // Looked up lazily so tests that never sign in don't need Firebase Auth.
  String? _currentUserId() =>
      (_authOverride ?? auth.FirebaseAuth.instance).currentUser?.uid;

  Future<void> createUserProfile(String userId, String username, String email) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) return;

      User newUser = User(
        id: userId,
        username: username,
        email: email,
        ecoPoints: 0,
        dinoName: "Eco Dino",
        dinoStage: "Egg",
        profileImageUrl: null,
      );

      await _firestore.collection('users').doc(userId).set(newUser.toMap());
    } catch (e) {
      debugPrint("Error creating user profile: $e");
      rethrow;
    }
  }

  Future<User?> getUserData(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return User.fromMap(doc.data() as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint("Error getting user data: $e");
    }
    return null;
  }

  Future<User?> getCurrentUserData() async {
    final userId = _currentUserId();
    if (userId != null) return getUserData(userId);
    return null;
  }

  Future<void> updateUserData(User user) async {
    try {
      await _firestore.collection('users').doc(user.id).update(user.toMap());
    } catch (e) {
      debugPrint("Error updating user data: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateEcoPoints(String userId, int pointsToAdd) async {
    bool leveledUp = false;
    String oldStage = "";
    String newStage = "";
    int newPoints = 0;

    try {
      await _firestore.runTransaction((transaction) async {
        DocumentReference userRef = _firestore.collection('users').doc(userId);
        DocumentSnapshot userDoc = await transaction.get(userRef);

        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          int currentPoints = userData['ecoPoints'] ?? 0;
          oldStage = userData['dinoStage'] ?? "Egg";
          newStage = oldStage;

          newPoints = currentPoints + pointsToAdd;

          if (newPoints >= 500 && oldStage != "Eco Dino Warrior") {
            newStage = "Eco Dino Warrior";
            leveledUp = true;
          } else if (newPoints >= 300 && oldStage != "Teen Dino" && newPoints < 500) {
            newStage = "Teen Dino";
            leveledUp = true;
          } else if (newPoints >= 150 && oldStage != "Baby Dino" && newPoints < 300) {
            newStage = "Baby Dino";
            leveledUp = true;
          } else if (newPoints >= 50 && oldStage != "Cracked Egg" && newPoints < 150) {
            newStage = "Cracked Egg";
            leveledUp = true;
          }

          Map<String, dynamic> updateData = {
            'ecoPoints': newPoints,
            'dinoStage': newStage,
          };

          if (leveledUp) {
            updateData['hasUnseenLevelUp'] = true;
          }

          transaction.update(userRef, updateData);
        }
      });

      return {
        'leveledUp': leveledUp,
        'oldStage': oldStage,
        'newStage': newStage,
        'newPoints': newPoints,
      };
    } catch (e) {
      debugPrint("Error updating eco points: $e");
      rethrow;
    }
  }

  Future<void> clearLevelUpFlag(String userId) async {
    await _firestore.collection('users').doc(userId).update({'hasUnseenLevelUp': false});
  }
}
