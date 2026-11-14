class RecyclingRecord {
  final String id;
  final String userId;
  final String materialType;
  final double amount;
  final String unit;
  final DateTime date;
  final String? notes;
  final String? imageUrl;

  // Constructor
  RecyclingRecord({
    required this.id,
    required this.userId,
    required this.materialType,
    required this.amount,
    required this.unit,
    required this.date,
    this.notes,
    this.imageUrl,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'materialType': materialType,
      'amount': amount,
      'unit': unit,
      'date': date.millisecondsSinceEpoch,
      'notes': notes,
      'imageUrl': imageUrl,
    };
  }

  // Create from Map (from Firestore)
  factory RecyclingRecord.fromMap(Map<String, dynamic> map) {
    return RecyclingRecord(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      materialType: map['materialType'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      unit: map['unit'] ?? '',
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      notes: map['notes'],
      imageUrl: map['imageUrl'],
    );
  }
}