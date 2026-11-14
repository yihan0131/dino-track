class RecyclingGuide {
  final String id;
  final String title;
  final String category;
  final String description;
  final List<String> steps;
  final List<String> imageUrls;
  final List<String> assetImages;
  final List<String> materialTypes;
  final int difficultyLevel;
  final bool useLocalAssets;

  // Constructor
  RecyclingGuide({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.steps,
    this.imageUrls = const [],
    this.assetImages = const [],
    this.useLocalAssets = false,
    required this.materialTypes,
    this.difficultyLevel = 1,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'description': description,
      'steps': steps,
      'imageUrls': imageUrls,
      'assetImages': assetImages,
      'useLocalAssets': useLocalAssets,
      'materialTypes': materialTypes,
      'difficultyLevel': difficultyLevel,
    };
  }

  // Create from Map (from Firestore)
  factory RecyclingGuide.fromMap(Map<String, dynamic> map) {
    return RecyclingGuide(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      steps: List<String>.from(map['steps'] ?? []),
      imageUrls: List<String>.from(map['imageUrls'] ?? []),
      assetImages: List<String>.from(map['assetImages'] ?? []),
      useLocalAssets: map['useLocalAssets'] ?? false,
      materialTypes: List<String>.from(map['materialTypes'] ?? []),
      difficultyLevel: map['difficultyLevel'] ?? 1,
    );
  }
}