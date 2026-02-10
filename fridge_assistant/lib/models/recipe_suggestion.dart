/// Model cho gợi ý món ăn từ AI
class RecipeSuggestion {
  final String id;
  final String name;
  final String? imageUrl;
  final String description;
  final List<String> ingredientsUsed;
  final int cookTimeMinutes;
  final String difficulty;
  final int matchPercentage;
  final int ingredientsExpiringCount;

  RecipeSuggestion({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.description,
    required this.ingredientsUsed,
    required this.cookTimeMinutes,
    required this.difficulty,
    required this.matchPercentage,
    this.ingredientsExpiringCount = 0,
  });

  /// Text hiển thị thời gian nấu
  String get cookTimeText {
    if (cookTimeMinutes < 60) {
      return '$cookTimeMinutes phút';
    } else {
      final hours = cookTimeMinutes ~/ 60;
      final mins = cookTimeMinutes % 60;
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
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      imageUrl: json['image_url'],
      description: json['description'] ?? '',
      ingredientsUsed: List<String>.from(json['ingredients_used'] ?? []),
      cookTimeMinutes: json['cook_time_minutes'] ?? 0,
      difficulty: json['difficulty'] ?? 'Trung bình',
      matchPercentage: json['match_percentage'] ?? 0,
      ingredientsExpiringCount: json['ingredients_expiring_count'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'description': description,
      'ingredients_used': ingredientsUsed,
      'cook_time_minutes': cookTimeMinutes,
      'difficulty': difficulty,
      'match_percentage': matchPercentage,
      'ingredients_expiring_count': ingredientsExpiringCount,
    };
  }
}
