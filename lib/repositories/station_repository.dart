import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/recycling_station.dart';
import '../service/cloudinary_service.dart';
import 'user_repository.dart';

class StationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final UserRepository _userRepository = UserRepository();

  StreamSubscription? _stationApprovalListener;
  final Set<String> _awardedStationIds = {};

  String? _currentUserId() =>
      auth.FirebaseAuth.instance.currentUser?.uid;

  void startListeningForStationApprovals() {
    final userId = _currentUserId();
    if (userId == null) return;

    _stationApprovalListener = _firestore
        .collection('recycling_stations')
        .where('submittedBy', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) {
      for (var docChange in snapshot.docChanges) {
        if (docChange.type == DocumentChangeType.modified) {
          final data = docChange.doc.data() as Map<String, dynamic>;
          final verified = data['verified'];
          final pointsAwarded = data['pointsAwarded'] ?? false;
          final docId = docChange.doc.id;

          if (verified == true &&
              pointsAwarded == false &&
              !_awardedStationIds.contains(docId)) {
            _awardedStationIds.add(docId);

            _firestore
                .collection('recycling_stations')
                .doc(docId)
                .update({'pointsAwarded': true})
                .then((_) => _userRepository.updateEcoPoints(userId, 20))
                .catchError((error) {
              debugPrint("Error awarding station points: $error");
              _awardedStationIds.remove(docId);
              _firestore
                  .collection('recycling_stations')
                  .doc(docId)
                  .update({'pointsAwarded': false});
              return <String, dynamic>{};
            });
          }
        }
      }
    }, onError: (error) {
      debugPrint("Station approval listener error: $error");
    });
  }

  void stopListeningForStationApprovals() {
    _stationApprovalListener?.cancel();
  }

  Future<String> submitRecyclingStationRequest(RecyclingStation station,
      {File? imageFile}) async {
    try {
      final stationId = station.id.isEmpty ? _uuid.v4() : station.id;
      final userId = _currentUserId();

      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await _cloudinaryService.uploadImage(
            imageFile, 'recycling_stations');
      }

      RecyclingStation stationToSave = RecyclingStation(
        id: stationId,
        name: station.name,
        address: station.address,
        latitude: station.latitude,
        longitude: station.longitude,
        acceptedMaterials: station.acceptedMaterials,
        imageUrl: imageUrl ?? station.imageUrl,
        operatingHours: station.operatingHours,
        rating: 0.0,
        verified: false,
        submittedBy: userId,
        submissionDate: DateTime.now(),
        contactInfo: station.contactInfo,
        pointsAwarded: false,
      );

      await _firestore
          .collection('recycling_stations')
          .doc(stationId)
          .set(stationToSave.toMap());
      return stationId;
    } catch (e) {
      debugPrint("Error submitting station request: $e");
      rethrow;
    }
  }

  Future<List<RecyclingStation>> getAllRecyclingStations(
      {bool? verifiedOnly}) async {
    try {
      Query query = _firestore.collection('recycling_stations');
      if (verifiedOnly != null) {
        query = query.where('verified', isEqualTo: verifiedOnly);
      }

      QuerySnapshot querySnapshot = await query.get();

      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return RecyclingStation.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint("Error getting recycling stations: $e");
      return [];
    }
  }

  Future<List<RecyclingStation>> getVerifiedRecyclingStations() async {
    return getAllRecyclingStations(verifiedOnly: true);
  }

  Future<List<RecyclingStation>> getNearbyRecyclingStations(
      double latitude, double longitude, double radiusInKm,
      {bool includeUnverified = false}) async {
    try {
      List<RecyclingStation> stations = await getAllRecyclingStations(
          verifiedOnly: includeUnverified ? null : true);

      return stations.where((station) {
        double distance = _calculateDistance(
            latitude, longitude, station.latitude, station.longitude);
        return distance <= radiusInKm;
      }).toList();
    } catch (e) {
      debugPrint("Error getting nearby recycling stations: $e");
      return [];
    }
  }

  Future<List<RecyclingStation>> getUserSubmittedStations() async {
    try {
      final userId = _currentUserId();
      if (userId == null) return [];

      QuerySnapshot querySnapshot = await _firestore
          .collection('recycling_stations')
          .where('submittedBy', isEqualTo: userId)
          .orderBy('submissionDate', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return RecyclingStation.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint("Error getting user submitted stations: $e");
      return [];
    }
  }

  Future<RecyclingStation?> getRecyclingStationById(String stationId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('recycling_stations')
          .doc(stationId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return RecyclingStation.fromMap(data);
      }

      return null;
    } catch (e) {
      debugPrint("Error getting recycling station by ID: $e");
      return null;
    }
  }

  Future<void> updateRecyclingStation(RecyclingStation station) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('recycling_stations')
          .doc(station.id)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        bool originalVerificationStatus = data['verified'] ?? false;

        Map<String, dynamic> updateData = station.toMap();
        updateData['verified'] = originalVerificationStatus;

        await _firestore
            .collection('recycling_stations')
            .doc(station.id)
            .update(updateData);
      } else {
        throw Exception("Recycling station not found");
      }
    } catch (e) {
      debugPrint("Error updating recycling station: $e");
      rethrow;
    }
  }

  Future<void> rateRecyclingStation(String stationId, double rating) async {
    try {
      rating = rating.clamp(1.0, 5.0);

      await _firestore.runTransaction((transaction) async {
        DocumentReference stationRef =
            _firestore.collection('recycling_stations').doc(stationId);
        DocumentSnapshot stationDoc = await transaction.get(stationRef);

        if (stationDoc.exists) {
          Map<String, dynamic> data =
              stationDoc.data() as Map<String, dynamic>;
          double currentRating = (data['rating'] ?? 0.0).toDouble();
          int ratingCount = data['ratingCount'] ?? 0;

          double newRating = ratingCount == 0
              ? rating
              : ((currentRating * ratingCount) + rating) / (ratingCount + 1);

          transaction.update(stationRef, {
            'rating': newRating,
            'ratingCount': ratingCount + 1,
          });
        }
      });
    } catch (e) {
      debugPrint("Error rating recycling station: $e");
      rethrow;
    }
  }

  Future<void> reportRecyclingStationIssue(
      String stationId, String issueDescription) async {
    try {
      final userId = _currentUserId();
      if (userId == null) throw Exception("User not logged in");

      await _firestore.collection('station_reports').add({
        'stationId': stationId,
        'reportedBy': userId,
        'description': issueDescription,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      debugPrint("Error reporting recycling station issue: $e");
      rethrow;
    }
  }

  Future<List<RecyclingStation>> searchRecyclingStations(String query,
      {bool verifiedOnly = true}) async {
    try {
      List<RecyclingStation> allStations =
          await getAllRecyclingStations(verifiedOnly: verifiedOnly);
      final lowercaseQuery = query.toLowerCase();

      return allStations.where((station) {
        return station.name.toLowerCase().contains(lowercaseQuery) ||
            station.address.toLowerCase().contains(lowercaseQuery);
      }).toList();
    } catch (e) {
      debugPrint("Error searching recycling stations: $e");
      return [];
    }
  }

  Future<List<RecyclingStation>> getStationsByMaterial(String materialType,
      {bool verifiedOnly = true}) async {
    try {
      List<RecyclingStation> allStations =
          await getAllRecyclingStations(verifiedOnly: verifiedOnly);

      return allStations.where((station) {
        return station.acceptedMaterials.any(
            (material) => material.toLowerCase() == materialType.toLowerCase());
      }).toList();
    } catch (e) {
      debugPrint("Error getting stations by material: $e");
      return [];
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371.0;
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRadians(double degrees) => degrees * (pi / 180.0);
}
