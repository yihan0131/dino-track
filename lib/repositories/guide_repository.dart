import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/recycling_guide.dart';

class GuideRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  Future<List<RecyclingGuide>> getRecyclingGuides(String category) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('recycling_guides')
          .where('category', isEqualTo: category)
          .get();

      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return RecyclingGuide.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint("Error getting recycling guides: $e");
      return [];
    }
  }

  Future<List<RecyclingGuide>> getAllRecyclingGuides() async {
    try {
      QuerySnapshot querySnapshot = await _firestore.collection('recycling_guides').get();

      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return RecyclingGuide.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint("Error getting all recycling guides: $e");
      return [];
    }
  }

  Future<String> addRecyclingGuide(RecyclingGuide guide) async {
    try {
      final guideId = guide.id.isEmpty ? _uuid.v4() : guide.id;

      RecyclingGuide guideToSave = RecyclingGuide(
        id: guideId,
        title: guide.title,
        category: guide.category,
        description: guide.description,
        steps: guide.steps,
        imageUrls: guide.imageUrls,
        assetImages: guide.assetImages,
        useLocalAssets: guide.useLocalAssets,
        materialTypes: guide.materialTypes,
        difficultyLevel: guide.difficultyLevel,
      );

      await _firestore.collection('recycling_guides').doc(guideId).set(guideToSave.toMap());
      return guideId;
    } catch (e) {
      debugPrint("Error adding recycling guide: $e");
      rethrow;
    }
  }

  Future<RecyclingGuide?> getRecyclingGuideById(String guideId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('recycling_guides').doc(guideId).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return RecyclingGuide.fromMap(data);
      }
    } catch (e) {
      debugPrint("Error getting recycling guide: $e");
    }
    return null;
  }
}
