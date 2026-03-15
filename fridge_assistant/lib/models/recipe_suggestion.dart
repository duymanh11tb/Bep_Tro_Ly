class RecipeSuggestion {
  final String id;
  final String name;
  final String? imageUrl;
  final String description;
  final List<String> ingredientsUsed;
  final List<String> ingredientsMissing;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final String difficulty;
  final double matchScore;
  final int ingredientsExpiringCount;
  final List<String> instructions;
  final String? tips;

  RecipeSuggestion({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.description,
    required this.ingredientsUsed,
    this.ingredientsMissing = const [],
    this.prepTimeMinutes = 0,
    required this.cookTimeMinutes,
    required this.difficulty,
    this.matchScore = 0.0,
    this.ingredientsExpiringCount = 0,
    this.instructions = const [],
    this.tips,
  });

  /// Điểm tương thích (%)
  int get matchPercentage => (matchScore * 100).toInt();

  /// Tổng thời gian thực hiện
  int get totalTimeMinutes => prepTimeMinutes + cookTimeMinutes;

  /// Text hiển thị thời gian nấu
  String get cookTimeText {
    final total = totalTimeMinutes;
    if (total == 0) return 'Dưới 15 phút';
    if (total < 60) {
      return '$total phút';
    } else {
      final hours = total ~/ 60;
      final mins = total % 60;
      return mins > 0 ? '$hours giờ $mins phút' : '$hours giờ';
    }
  }

  /// Text badge nguyên liệu sắp hết
  String get expiringBadgeText {
    if (ingredientsExpiringCount > 0) {
      return 'Dùng $ingredientsExpiringCount nguyên liệu sắp hết';
    }
    return '';
  }

  factory RecipeSuggestion.fromJson(Map<String, dynamic> json) {
    return RecipeSuggestion(
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
      description: json['description'] ?? '',
      ingredientsUsed: List<String>.from(json['ingredients_used'] ?? []),
      ingredientsMissing: List<String>.from(json['ingredients_missing'] ?? []),
      prepTimeMinutes: json['prep_time'] ?? 0,
      cookTimeMinutes: json['cook_time'] ?? 0,
      difficulty: json['difficulty'] ?? 'easy',
      matchScore: (json['match_score'] ?? 0.0).toDouble(),
      ingredientsExpiringCount: json['ingredients_expiring_count'] ?? 0,
      instructions: List<String>.from(json['instructions'] ?? []),
      tips: json['tips'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'description': description,
      'ingredients_used': ingredientsUsed,
      'ingredients_missing': ingredientsMissing,
      'prep_time': prepTimeMinutes,
      'cook_time': cookTimeMinutes,
      'difficulty': difficulty,
      'match_score': matchScore,
      'ingredients_expiring_count': ingredientsExpiringCount,
      'instructions': instructions,
      'tips': tips,
    };
  }
}
