import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/recycling_record.dart';
import '../service/cloudinary_service.dart';
import 'user_repository.dart';

class RecordRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final UserRepository _userRepository = UserRepository();

  Future<String> uploadImage(File imageFile, String folder,
      {Map<String, dynamic>? metadata}) async {
    try {
      return await _cloudinaryService.uploadImage(imageFile, folder,
          metadata: metadata);
    } catch (e) {
      debugPrint("Error uploading image: $e");
      rethrow;
    }
  }

  Future<String> addRecyclingRecord(RecyclingRecord record,
      {File? imageFile}) async {
    try {
      final recordId = record.id.isEmpty ? _uuid.v4() : record.id;

      String? imageUrl;
      if (imageFile != null) {
        imageUrl = await uploadImage(
          imageFile,
          'recycling_records',
          metadata: {
            'userId': record.userId,
            'materialType': record.materialType,
            'amount': record.amount,
            'unit': record.unit,
            'date': record.date.millisecondsSinceEpoch,
            'recordId': recordId,
          },
        );
      }

      RecyclingRecord recordToSave = RecyclingRecord(
        id: recordId,
        userId: record.userId,
        materialType: record.materialType,
        amount: record.amount,
        unit: record.unit,
        date: record.date,
        notes: record.notes,
        imageUrl: imageUrl ?? record.imageUrl,
      );

      await _firestore
          .collection('recycling_records')
          .doc(recordId)
          .set(recordToSave.toMap());

      await _awardDailyRecyclingPoints(record.userId, record.date);
      return recordId;
    } catch (e) {
      debugPrint("Error adding recycling record: $e");
      rethrow;
    }
  }

  Future<void> _awardDailyRecyclingPoints(
      String userId, DateTime recordDate) async {
    try {
      String dateString =
          '${recordDate.year}-${recordDate.month.toString().padLeft(2, '0')}-${recordDate.day.toString().padLeft(2, '0')}';
      String documentId = '${userId}_$dateString';

      DocumentSnapshot pointsDoc = await _firestore
          .collection('daily_recycling_points')
          .doc(documentId)
          .get();

      if (!pointsDoc.exists) {
        await _userRepository.updateEcoPoints(userId, 2);

        await _firestore
            .collection('daily_recycling_points')
            .doc(documentId)
            .set({
          'userId': userId,
          'dateString': dateString,
          'timestamp': DateTime(recordDate.year, recordDate.month,
                  recordDate.day)
              .millisecondsSinceEpoch,
          'pointsAwarded': 2,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint("Error awarding daily recycling points: $e");
    }
  }

  Future<Map<String, List<RecyclingRecord>>> getUserRecyclingRecordsByDate(
      String userId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('recycling_records')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      Map<String, List<RecyclingRecord>> groupedRecords = {};

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        RecyclingRecord record = RecyclingRecord.fromMap(data);

        String dateKey =
            '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}';

        groupedRecords.putIfAbsent(dateKey, () => []).add(record);
      }

      return groupedRecords;
    } catch (e) {
      debugPrint("Error getting user recycling records by date: $e");
      return {};
    }
  }

  Future<bool> wasFirstRecordOfDay(
      List<RecyclingRecord> entryRecords, String dateString,
      {required String userId}) async {
    try {
      String documentId = '${userId}_$dateString';

      DocumentSnapshot pointsDoc = await _firestore
          .collection('daily_recycling_points')
          .doc(documentId)
          .get();

      if (!pointsDoc.exists) return false;

      Map<String, List<RecyclingRecord>> allRecordsForDate =
          await getUserRecyclingRecordsByDate(userId);

      List<RecyclingRecord>? dayRecords = allRecordsForDate[dateString];
      if (dayRecords == null) return false;

      dayRecords.sort((a, b) => a.date.compareTo(b.date));

      if (dayRecords.isNotEmpty) {
        RecyclingRecord earliestRecord = dayRecords.first;
        return entryRecords.any((record) => record.id == earliestRecord.id);
      }

      return false;
    } catch (e) {
      debugPrint("Error checking if first record of day: $e");
      return false;
    }
  }

  String formatDateForPoints(String displayDate) {
    List<String> parts = displayDate.split('/');
    if (parts.length == 2) {
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = DateTime.now().year;
      return '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    }
    return displayDate;
  }

  Future<List<RecyclingRecord>> getUserRecyclingRecords(String userId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('recycling_records')
          .where('userId', isEqualTo: userId)
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return RecyclingRecord.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint("Error getting user recycling records: $e");
      return [];
    }
  }

  Future<Map<String, dynamic>> getUserRecyclingStats(String userId, {int? year}) async {
    try {
      List<RecyclingRecord> allRecords = await getUserRecyclingRecords(userId);
      List<RecyclingRecord> records = year != null
          ? allRecords.where((r) => r.date.year == year).toList()
          : allRecords;

      if (records.isEmpty) {
        return {
          'totalRecords': 0,
          'totalDays': 0,
          'materialTotals': <String, Map<String, double>>{},
          'lastRecordDate': null,
        };
      }

      Map<String, Map<String, double>> materialTotals = {};
      Set<String> uniqueDates = {};

      for (var record in records) {
        String dateKey =
            '${record.date.year}-${record.date.month.toString().padLeft(2, '0')}-${record.date.day.toString().padLeft(2, '0')}';
        uniqueDates.add(dateKey);

        String materialKey = record.materialType.toLowerCase();
        materialTotals.putIfAbsent(materialKey, () => {});

        String unitKey = record.unit.toLowerCase();
        materialTotals[materialKey]![unitKey] =
            (materialTotals[materialKey]![unitKey] ?? 0) + record.amount;
      }

      return {
        'totalRecords': records.length,
        'totalDays': uniqueDates.length,
        'materialTotals': materialTotals,
        'lastRecordDate': records.first.date,
      };
    } catch (e) {
      debugPrint("Error getting user recycling stats: $e");
      return {};
    }
  }

  Future<Map<String, double>> getMaterialDistribution(String userId, {int? year}) async {
    try {
      List<RecyclingRecord> allRecords = await getUserRecyclingRecords(userId);
      List<RecyclingRecord> records = year != null
          ? allRecords.where((r) => r.date.year == year).toList()
          : allRecords;
      Map<String, double> distribution = {};

      for (var record in records) {
        String materialType = record.materialType.toLowerCase();
        distribution[materialType] = (distribution[materialType] ?? 0) + 1;
      }

      return distribution;
    } catch (e) {
      debugPrint("Error getting material distribution: $e");
      return {};
    }
  }

  Future<void> deleteRecyclingRecord(String recordId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('recycling_records')
          .doc(recordId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String? imageUrl = data['imageUrl'];

        await _firestore.collection('recycling_records').doc(recordId).delete();

        if (imageUrl != null && imageUrl.isNotEmpty) {
          try {
            await _cloudinaryService.deleteImage(imageUrl);
          } catch (e) {
            debugPrint("Error deleting image: $e");
          }
        }
      }
    } catch (e) {
      debugPrint("Error deleting recycling record: $e");
      rethrow;
    }
  }
}
