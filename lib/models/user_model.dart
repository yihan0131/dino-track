class User {
  final String id;
  final String username;
  final String email;
  int ecoPoints;
  String dinoName;
  String dinoStage;
  List<String> processedReports;
  final String? profileImageUrl;
  bool hasUnseenLevelUp;
  final bool isAdmin;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.ecoPoints = 0,
    this.dinoName = "Eco Dino",
    this.dinoStage = "Egg",
    this.processedReports = const [],
    this.profileImageUrl,
    this.hasUnseenLevelUp = false,
    this.isAdmin = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'ecoPoints': ecoPoints,
      'dinoName': dinoName,
      'dinoStage': dinoStage,
      'processedReports': processedReports,
      'profileImageUrl': profileImageUrl,
      'hasUnseenLevelUp': hasUnseenLevelUp,
      'isAdmin': isAdmin,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      ecoPoints: map['ecoPoints'] ?? 0,
      dinoName: map['dinoName'] ?? 'Eco Dino',
      dinoStage: map['dinoStage'] ?? 'Egg',
      processedReports: List<String>.from(map['processedReports'] ?? []),
      profileImageUrl: map['profileImageUrl'],
      hasUnseenLevelUp: map['hasUnseenLevelUp'] ?? false,
      isAdmin: map['isAdmin'] ?? false,
    );
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    int? ecoPoints,
    String? dinoName,
    String? dinoStage,
    List<String>? processedReports,
    String? profileImageUrl,
    bool? hasUnseenLevelUp,
    bool? isAdmin,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      ecoPoints: ecoPoints ?? this.ecoPoints,
      dinoName: dinoName ?? this.dinoName,
      dinoStage: dinoStage ?? this.dinoStage,
      processedReports: processedReports ?? this.processedReports,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      hasUnseenLevelUp: hasUnseenLevelUp ?? this.hasUnseenLevelUp,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
}
