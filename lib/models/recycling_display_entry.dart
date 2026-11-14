import 'package:flutter/material.dart';
import 'recycling_record.dart';

class RecyclingDisplayEntry {
  final String materialType;
  final String unit;
  double totalAmount;
  final Color color;
  List<RecyclingRecord> records;

  RecyclingDisplayEntry({
    required this.materialType,
    required this.unit,
    required this.totalAmount,
    required this.color,
    required this.records,
  });
}