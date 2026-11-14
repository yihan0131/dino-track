class RecyclingStation {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final List<String> acceptedMaterials;
  final String? imageUrl;
  final Map<String, dynamic> operatingHours;
  final double rating;

  // New fields
  bool verified;
  final String? submittedBy;
  final DateTime? submissionDate;
  String status;
  final Map<String, String>? contactInfo;
  final String? originalStationId;
  final bool pointsAwarded; // 添加这个字段

  // Constructor
  RecyclingStation({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.acceptedMaterials,
    this.imageUrl,
    Map<String, dynamic>? operatingHours,
    this.rating = 0.0,
    this.verified = false,
    this.submittedBy,
    DateTime? submissionDate,
    this.status = 'pending',
    this.contactInfo,
    this.originalStationId,
    this.pointsAwarded = false, // 添加这个参数
  }) :
        operatingHours = operatingHours ?? {},
        submissionDate = submissionDate ?? DateTime.now();

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'acceptedMaterials': acceptedMaterials,
      'imageUrl': imageUrl,
      'operatingHours': operatingHours,
      'rating': rating,
      'verified': verified,
      'submittedBy': submittedBy,
      'submissionDate': submissionDate?.toIso8601String(),
      'contactInfo': contactInfo,
      'status': status,
      'originalStationId': originalStationId,
      'pointsAwarded': pointsAwarded, // 添加这个
    };
  }

  // Create from Map (from Firestore)
  factory RecyclingStation.fromMap(Map<String, dynamic> map) {
    return RecyclingStation(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      acceptedMaterials: List<String>.from(map['acceptedMaterials'] ?? []),
      imageUrl: map['imageUrl'],
      operatingHours: map['operatingHours'] is String
          ? {'default': map['operatingHours']}
          : (map['operatingHours'] is Map ? Map<String, dynamic>.from(map['operatingHours']) : {}),
      rating: map['rating']?.toDouble() ?? 0.0,
      verified: map['verified'] ?? false,
      submittedBy: map['submittedBy'],
      submissionDate: map['submissionDate'] != null
          ? DateTime.parse(map['submissionDate'])
          : null,
      contactInfo: Map<String, String>.from(map['contactInfo'] ?? {}),
      status: map['status'] ?? 'pending',
      originalStationId: map['originalStationId'],
      pointsAwarded: map['pointsAwarded'] ?? false, // 添加这个
    );
  }

  // Add copyWith method
  RecyclingStation copyWith({
    String? id,
    String? name,
    String? address,
    double? latitude,
    double? longitude,
    List<String>? acceptedMaterials,
    String? imageUrl,
    Map<String, dynamic>? operatingHours,
    double? rating,
    bool? verified,
    String? submittedBy,
    DateTime? submissionDate,
    Map<String, String>? contactInfo,
    String? status,
    String? originalStationId,
    bool? pointsAwarded, // 添加这个参数
  }) {
    return RecyclingStation(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      acceptedMaterials: acceptedMaterials ?? this.acceptedMaterials,
      imageUrl: imageUrl ?? this.imageUrl,
      operatingHours: operatingHours ?? this.operatingHours,
      rating: rating ?? this.rating,
      verified: verified ?? this.verified,
      submittedBy: submittedBy ?? this.submittedBy,
      submissionDate: submissionDate ?? this.submissionDate,
      contactInfo: contactInfo ?? this.contactInfo,
      status: status ?? this.status,
      originalStationId: originalStationId ?? this.originalStationId,
      pointsAwarded: pointsAwarded ?? this.pointsAwarded, // 添加这个
    );
  }
}