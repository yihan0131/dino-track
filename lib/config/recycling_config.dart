import 'package:flutter/material.dart';

class RecyclingConfig {
  static const List<String> materialTypes = [
    'Plastic',
    'Paper',
    'Glass',
    'Metal',
    'Electronics',
    'Cardboard',
    'Batteries',
    'Textiles',
    'Organic',
    'Other'
  ];

  static const Map<String, List<String>> unitsByMaterial = {
    'Plastic': ['pieces', 'bottles', 'bags', 'containers', 'kg', 'g'],
    'Paper': ['sheets', 'newspapers', 'magazines', 'kg', 'g'],
    'Glass': ['bottles', 'jars', 'pieces', 'kg', 'g'],
    'Metal': ['cans', 'pieces', 'kg', 'g'],
    'Electronics': ['pieces', 'devices', 'kg'],
    'Cardboard': ['boxes', 'sheets', 'kg', 'g'],
    'Batteries': ['pieces', 'sets', 'kg'],
    'Textiles': ['pieces', 'items', 'kg', 'g'],
    'Organic': ['kg', 'g', 'bags'],
    'Other': ['pieces', 'items', 'kg', 'g']
  };

  static List<String> getUnitsForMaterial(String materialType) {
    return unitsByMaterial[materialType] ?? ['pieces', 'kg', 'g'];
  }

  static Color getColorForMaterial(String materialType) {
    switch (materialType.toLowerCase()) {
      case 'plastic':
        return Colors.blue;
      case 'paper':
        return Colors.green;
      case 'glass':
        return Colors.purple;
      case 'metal':
        return Colors.orange;
      case 'cardboard':
        return Colors.brown;
      case 'electronics':
        return Colors.red;
      case 'batteries':
        return Colors.yellow[700]!;
      case 'textiles':
        return Colors.pink;
      case 'organic':
        return Colors.lightGreen;
      default:
        return Colors.grey;
    }
  }
}