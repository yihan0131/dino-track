import 'package:cloud_firestore/cloud_firestore.dart';

class StationReport {
  final String id;
  final String stationId;
  final String reportedBy;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> acceptedMaterials;
  final String status;
  final DateTime reportDate;

  StationReport({
    required this.id,
    required this.stationId,
    required this.reportedBy,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.acceptedMaterials,
    this.status = 'pending',
    required this.reportDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'stationId': stationId,
      'reportedBy': reportedBy,
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'acceptedMaterials': acceptedMaterials,
      'status': status,
      'reportDate': Timestamp.fromDate(reportDate),
    };
  }

  factory StationReport.fromMap(String id, Map<String, dynamic> map) {
    return StationReport(
      id: id,
      stationId: map['stationId'] ?? '',
      reportedBy: map['reportedBy'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      acceptedMaterials: List<String>.from(map['acceptedMaterials'] ?? []),
      status: map['status'] ?? 'pending',
      reportDate: (map['reportDate'] as Timestamp).toDate(),
    );
  }
} 