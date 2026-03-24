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
  final List<String> cuisines;
  final List<String> dishTypes;
  final String? tips;
  String? status; // liked, disliked, hidden

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
    this.cuisines = const [],
    this.dishTypes = const [],
    this.tips,
    this.status,
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
    final recipeName = json['name'] ?? '';
    final ingredientsUsed = List<String>.from(json['ingredients_used'] ?? []);

    return RecipeSuggestion(
      id:
          json['id']?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: recipeName,
      imageUrl: _normalizeImageUrl(json['image_url']),
      description: json['description'] ?? '',
      ingredientsUsed: ingredientsUsed,
      ingredientsMissing: List<String>.from(json['ingredients_missing'] ?? []),
      prepTimeMinutes: json['prep_time'] ?? 0,
      cookTimeMinutes: json['cook_time'] ?? 0,
      difficulty: json['difficulty'] ?? 'easy',
      matchScore: (json['match_score'] ?? 0.0).toDouble(),
      ingredientsExpiringCount: json['ingredients_expiring_count'] ?? 0,
      instructions: List<String>.from(json['instructions'] ?? []),
      cuisines: List<String>.from(json['cuisines'] ?? []),
      dishTypes: List<String>.from(json['dish_types'] ?? []),
      tips: json['tips'],
      status: json['status'],
    );
  }

  static String? _normalizeImageUrl(dynamic rawUrl) {
    final url = rawUrl?.toString().trim();
    if (url == null || url.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return null;
    }

    final host = uri.host.toLowerCase();
    final blockedHosts = <String>{
      'imgur.com',
      'i.imgur.com',
      'm.imgur.com',
      'source.unsplash.com',
      'picsum.photos',
      'loremflickr.com',
    };

    if (blockedHosts.contains(host)) {
      return null;
    }

    if (url.contains('source.unsplash.com') ||
        url.contains('picsum.photos') ||
        url.contains('loremflickr.com') ||
        url.contains('imgur.com')) {
      return null;
    }

    return url;
  }

  RecipeSuggestion copyWith({
    String? id,
    String? name,
    String? imageUrl,
    String? description,
    List<String>? ingredientsUsed,
    List<String>? ingredientsMissing,
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    String? difficulty,
    double? matchScore,
    int? ingredientsExpiringCount,
    List<String>? instructions,
    List<String>? cuisines,
    List<String>? dishTypes,
    String? tips,
    String? status,
  }) {
    return RecipeSuggestion(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      ingredientsUsed: ingredientsUsed ?? this.ingredientsUsed,
      ingredientsMissing: ingredientsMissing ?? this.ingredientsMissing,
      prepTimeMinutes: prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes ?? this.cookTimeMinutes,
      difficulty: difficulty ?? this.difficulty,
      matchScore: matchScore ?? this.matchScore,
      ingredientsExpiringCount:
          ingredientsExpiringCount ?? this.ingredientsExpiringCount,
      instructions: instructions ?? this.instructions,
      cuisines: cuisines ?? this.cuisines,
      dishTypes: dishTypes ?? this.dishTypes,
      tips: tips ?? this.tips,
      status: status ?? this.status,
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
      'cuisines': cuisines,
      'dish_types': dishTypes,
      'tips': tips,
      'status': status,
    };
  }

  /// Tính số nguyên liệu sắp hết được sử dụng
  static int countExpiringIngredients(
    List<String> usedIngredients,
    List<String> expiringIngredients,
  ) {
    return usedIngredients.where((i) => expiringIngredients.contains(i)).length;
  }
}
