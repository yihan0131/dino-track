import '../models/recycling_record.dart';

class DailyRecyclingSummary {
  final DateTime date;
  final List<RecyclingRecord> records;
  final int totalRecords;
  final Map<String, int> materialCounts;

  DailyRecyclingSummary({
    required this.date,
    required this.records,
    required this.totalRecords,
    required this.materialCounts,
  });

  factory DailyRecyclingSummary.fromRecords(DateTime date, List<RecyclingRecord> records) {
    Map<String, int> materialCounts = {};
    for (var record in records) {
      String key = '${record.materialType} (${record.unit})';
      materialCounts[key] = (materialCounts[key] ?? 0) + record.amount.toInt();
    }

    return DailyRecyclingSummary(
      date: date,
      records: records,
      totalRecords: records.length,
      materialCounts: materialCounts,
    );
  }

  // Format date as "17/5" style
  String get formattedDate {
    return '${date.day}/${date.month}';
  }

  // Get material summary lines for display
  List<String> get materialSummary {
    return materialCounts.entries
        .map((entry) => '${entry.key} – ${entry.value}')
        .toList();
  }

  // Check if this day earned points (any records = points earned)
  bool get earnedPoints {
    return records.isNotEmpty;
  }
}

