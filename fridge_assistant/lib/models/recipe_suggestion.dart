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
      imageUrl: _normalizeImageUrl(
        json['image_url'],
        recipeName,
        ingredientsUsed,
      ),
      description: json['description'] ?? '',
      ingredientsUsed: ingredientsUsed,
      ingredientsMissing: List<String>.from(json['ingredients_missing'] ?? []),
      prepTimeMinutes: json['prep_time'] ?? 0,
      cookTimeMinutes: json['cook_time'] ?? 0,
      difficulty: json['difficulty'] ?? 'easy',
      matchScore: (json['match_score'] ?? 0.0).toDouble(),
      ingredientsExpiringCount: json['ingredients_expiring_count'] ?? 0,
      instructions: List<String>.from(json['instructions'] ?? []),
      tips: json['tips'],
      status: json['status'],
    );
  }

  static String fallbackImageForName(String recipeName) {
    return _fallbackImageUrl(recipeName, const []);
  }

  static String fallbackImageForRecipe(RecipeSuggestion recipe) {
    return _fallbackImageUrl(recipe.name, recipe.ingredientsUsed);
  }

  static String _fallbackImageUrl(
    String recipeName,
    List<String> ingredientsUsed,
  ) {
    final normalized = _normalizeText(
      '$recipeName ${ingredientsUsed.join(' ')}',
    );

    const exactDishImages = <String, String>{
      'bò xào cà chua':
          'https://cdn.tgdd.vn/2022/01/CookDish/cach-lam-mon-thit-bam-xao-ca-chua-thom-ngon-la-mieng-cho-bua-avt-1200x676.jpg',
      'thịt bò lúc lắc':
          'https://i.ytimg.com/vi/0X5m98q3Pn0/maxresdefault.jpg',
      'gà kho gừng':
          'https://i.ytimg.com/vi/xFzQdCIrgko/maxresdefault.jpg',
      'thịt kho tàu':
          'https://i.ytimg.com/vi/Q5V0uEkdTPg/maxresdefault.jpg',
      'canh chua cá lóc':
          'https://i.ytimg.com/vi/Q5V0uEkdTPg/maxresdefault.jpg',
      'cá kho tộ':
          'https://i.ytimg.com/vi/zvlct2ZXhj8/maxresdefault.jpg',
      'phở bò':
          'https://cdn.tgdd.vn/2020/11/CookProduct/pho-bo-thumbnail-1200x676.jpg',
      'bún bò huế':
          'https://i.ytimg.com/vi/Q5V0uEkdTPg/maxresdefault.jpg',
      'bún riêu cua':
          'https://i.ytimg.com/vi/Q5V0uEkdTPg/maxresdefault.jpg',
      'mì xào bò rau cải':
          'https://i.ytimg.com/vi/Q5V0uEkdTPg/maxresdefault.jpg',
      'cơm chiên dương châu':
          'https://i.ytimg.com/vi/Q5V0uEkdTPg/maxresdefault.jpg',
      'gỏi cuốn tôm thịt':
          'https://images.pexels.com/photos/2097090/pexels-photo-2097090.jpeg?auto=compress&cs=tinysrgb&w=1200',
      'lẩu thái hải sản':
          'https://images.pexels.com/photos/699953/pexels-photo-699953.jpeg?auto=compress&cs=tinysrgb&w=1200',
      'salad úc gà và bò':
          'https://images.pexels.com/photos/1213710/pexels-photo-1213710.jpeg?auto=compress&cs=tinysrgb&w=1200',
      'bò né chảo gang':
          'https://images.pexels.com/photos/361184/asparagus-steak-veal-steak-veal-361184.jpeg?auto=compress&cs=tinysrgb&w=1200',
      'bánh xèo miền tây':
          'https://images.pexels.com/photos/5560763/pexels-photo-5560763.jpeg?auto=compress&cs=tinysrgb&w=1200',
      'mì quảng gà':
          'https://images.pexels.com/photos/1437267/pexels-photo-1437267.jpeg?auto=compress&cs=tinysrgb&w=1200',
    };

    for (final entry in exactDishImages.entries) {
      if (normalized.contains(entry.key)) return entry.value;
    }
    const imageByKeyword = <String, List<String>>{
      'bo': [
        'https://images.pexels.com/photos/1860204/pexels-photo-1860204.jpeg?auto=compress&cs=tinysrgb&w=1200',
        'https://images.pexels.com/photos/361184/asparagus-steak-veal-steak-veal-361184.jpeg?auto=compress&cs=tinysrgb&w=1200',
        'https://images.pexels.com/photos/769289/pexels-photo-769289.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
      'ga': [
        'https://images.pexels.com/photos/616354/pexels-photo-616354.jpeg?auto=compress&cs=tinysrgb&w=1200',
        'https://images.pexels.com/photos/2338407/pexels-photo-2338407.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
      'ca': [
        'https://images.pexels.com/photos/262959/pexels-photo-262959.jpeg?auto=compress&cs=tinysrgb&w=1200',
        'https://images.pexels.com/photos/1516415/pexels-photo-1516415.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
      'tom': [
        'https://images.pexels.com/photos/3296277/pexels-photo-3296277.jpeg?auto=compress&cs=tinysrgb&w=1200',
        'https://images.pexels.com/photos/725991/pexels-photo-725991.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
      'pho': [
        'https://images.pexels.com/photos/6646035/pexels-photo-6646035.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
      'bun': [
        'https://images.pexels.com/photos/884600/pexels-photo-884600.jpeg?auto=compress&cs=tinysrgb&w=1200',
        'https://images.pexels.com/photos/723198/pexels-photo-723198.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
      'mi': [
        'https://images.pexels.com/photos/1279330/pexels-photo-1279330.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
      'lau': [
        'https://images.pexels.com/photos/699953/pexels-photo-699953.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
      'salad': [
        'https://images.pexels.com/photos/1213710/pexels-photo-1213710.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
      'canh': [
        'https://images.pexels.com/photos/539451/pexels-photo-539451.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
      'com': [
        'https://images.pexels.com/photos/723198/pexels-photo-723198.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
      'xao': [
        'https://images.pexels.com/photos/1437267/pexels-photo-1437267.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
      'chay': [
        'https://images.pexels.com/photos/1640774/pexels-photo-1640774.jpeg?auto=compress&cs=tinysrgb&w=1200',
      ],
    };

    for (final entry in imageByKeyword.entries) {
      if (normalized.contains(entry.key)) {
        final options = entry.value;
        return options[recipeName.hashCode.abs() % options.length];
      }
    }

    const generic = [
      'https://images.pexels.com/photos/1640774/pexels-photo-1640774.jpeg?auto=compress&cs=tinysrgb&w=1200',
      'https://images.pexels.com/photos/958545/pexels-photo-958545.jpeg?auto=compress&cs=tinysrgb&w=1200',
      'https://images.pexels.com/photos/958547/pexels-photo-958547.jpeg?auto=compress&cs=tinysrgb&w=1200',
    ];
    return generic[recipeName.hashCode.abs() % generic.length];
  }

  static String _normalizeText(String input) {
    var text = input.toLowerCase().trim();
    const vietnameseMap = {
      'à': 'a',
      'á': 'a',
      'ạ': 'a',
      'ả': 'a',
      'ã': 'a',
      'â': 'a',
      'ầ': 'a',
      'ấ': 'a',
      'ậ': 'a',
      'ẩ': 'a',
      'ẫ': 'a',
      'ă': 'a',
      'ằ': 'a',
      'ắ': 'a',
      'ặ': 'a',
      'ẳ': 'a',
      'ẵ': 'a',
      'è': 'e',
      'é': 'e',
      'ẹ': 'e',
      'ẻ': 'e',
      'ẽ': 'e',
      'ê': 'e',
      'ề': 'e',
      'ế': 'e',
      'ệ': 'e',
      'ể': 'e',
      'ễ': 'e',
      'ì': 'i',
      'í': 'i',
      'ị': 'i',
      'ỉ': 'i',
      'ĩ': 'i',
      'ò': 'o',
      'ó': 'o',
      'ọ': 'o',
      'ỏ': 'o',
      'õ': 'o',
      'ô': 'o',
      'ồ': 'o',
      'ố': 'o',
      'ộ': 'o',
      'ổ': 'o',
      'ỗ': 'o',
      'ơ': 'o',
      'ờ': 'o',
      'ớ': 'o',
      'ợ': 'o',
      'ở': 'o',
      'ỡ': 'o',
      'ù': 'u',
      'ú': 'u',
      'ụ': 'u',
      'ủ': 'u',
      'ũ': 'u',
      'ư': 'u',
      'ừ': 'u',
      'ứ': 'u',
      'ự': 'u',
      'ử': 'u',
      'ữ': 'u',
      'ỳ': 'y',
      'ý': 'y',
      'ỵ': 'y',
      'ỷ': 'y',
      'ỹ': 'y',
      'đ': 'd',
    };

    vietnameseMap.forEach((key, value) {
      text = text.replaceAll(key, value);
    });

    return text.replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _normalizeImageUrl(
    dynamic rawUrl,
    String recipeName,
    List<String> ingredientsUsed,
  ) {
    final url = rawUrl?.toString().trim();
    if (url == null || url.isEmpty) {
      return _fallbackImageUrl(recipeName, ingredientsUsed);
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return _fallbackImageUrl(recipeName, ingredientsUsed);
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
      return _fallbackImageUrl(recipeName, ingredientsUsed);
    }

    // Replace weak/random providers with curated food photos.
    if (url.contains('source.unsplash.com') ||
        url.contains('picsum.photos') ||
        url.contains('loremflickr.com') ||
        url.contains('imgur.com')) {
      return _fallbackImageUrl(recipeName, ingredientsUsed);
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
