import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'region_preference_service.dart';
import '../models/recipe_suggestion.dart';

class PantryItem {
  final int id;
  final String name;
  final double quantity;
  final String unit;
  final String category;
  final int? categoryId;
  final String location;
  final DateTime? expiryDate;
  final String? imageUrl;
  final String status;

  PantryItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
    this.categoryId,
    required this.location,
    this.expiryDate,
    this.imageUrl,
    required this.status,
  });

  factory PantryItem.fromJson(Map<String, dynamic> json) {
    DateTime? expiry;
    if (json['expiry_date'] != null) {
      try {
        expiry = DateTime.parse(json['expiry_date'].toString());
      } catch (_) {}
    }
    return PantryItem(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      quantity: (json['quantity'] ?? 1).toDouble(),
      unit: json['unit'] ?? '',
      category: json['category'] ?? 'Khác',
      categoryId: json['category_id'],
      location: json['location'] ?? 'fridge',
      expiryDate: expiry,
      imageUrl: json['image_url'],
      status: json['status'] ?? 'active',
    );
  }

  /// Số ngày còn lại trước khi hết hạn
  int get daysUntilExpiry {
    if (expiryDate == null) return 999;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  bool get isExpired => daysUntilExpiry < 0;
  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 3;

  String get expiryText {
    if (expiryDate == null) return '';
    if (isExpired) return 'Đã hết hạn';
    if (daysUntilExpiry == 0) return 'Hết hạn: hôm nay';
    if (daysUntilExpiry == 1) return 'Hết hạn: mai';
    return 'Hết hạn: ${daysUntilExpiry} ngày';
  }
}

class PantryStats {
  final int totalItems;
  final int expiringSoon;
  final List<CategoryStat> byCategory;

  PantryStats({
    required this.totalItems,
    required this.expiringSoon,
    required this.byCategory,
  });

  factory PantryStats.fromJson(Map<String, dynamic> json) {
    final cats = (json['by_category'] as List? ?? [])
        .map((c) => CategoryStat.fromJson(c))
        .toList();
    return PantryStats(
      totalItems: json['total_items'] ?? 0,
      expiringSoon: json['expiring_soon'] ?? 0,
      byCategory: cats,
    );
  }
}

class CategoryStat {
  final String category;
  final int count;

  CategoryStat({required this.category, required this.count});

  factory CategoryStat.fromJson(Map<String, dynamic> json) {
    return CategoryStat(
      category: json['category'] ?? 'Khác',
      count: json['count'] ?? 0,
    );
  }
}

class PantryService {
  static const String _aiSuggestionsCachePrefix = 'pantry_ai_suggestions_v1_';
  static List<PantryItem> _cachedExpiringItems = [];
  static PantryStats? _cachedStats;
  static List<RecipeSuggestion> _cachedAiSuggestions = [];
  static Map<int, List<RecipeSuggestion>> _pageCache = {};
  static String? _pageCacheRegionKey;

  static void _syncPageCacheRegion(String regionCacheKey) {
    if (_pageCacheRegionKey == regionCacheKey) return;
    _pageCacheRegionKey = regionCacheKey;
    _pageCache = {};
  }

  static Future<String> _getUserCacheSuffix() async {
    final authService = AuthService();
    final user = await authService.getUser();

    if (user == null) return 'guest';

    final raw =
        user['id']?.toString() ??
        user['email']?.toString() ??
        user['display_name']?.toString() ??
        'guest';

    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9@._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
  }

  static Future<String> _getAiSuggestionsCacheKey({
    String regionCacheKey = 'all',
  }) async {
    final suffix = await _getUserCacheSuffix();
    return '$_aiSuggestionsCachePrefix$suffix-$regionCacheKey';
  }

  static Future<void> _persistAiSuggestions(
    List<RecipeSuggestion> suggestions,
    String regionCacheKey,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = await _getAiSuggestionsCacheKey(
        regionCacheKey: regionCacheKey,
      );
      final payload = jsonEncode(suggestions.map((e) => e.toJson()).toList());
      await prefs.setString(cacheKey, payload);
    } catch (e) {
      debugPrint('PantryService._persistAiSuggestions error: $e');
    }
  }

  static Future<List<RecipeSuggestion>> _loadPersistedAiSuggestions(
    String regionCacheKey,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = await _getAiSuggestionsCacheKey(
        regionCacheKey: regionCacheKey,
      );
      final raw = prefs.getString(cacheKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((e) => RecipeSuggestion.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('PantryService._loadPersistedAiSuggestions error: $e');
      return [];
    }
  }

  static Future<List<PantryItem>> getCachedExpiringItems() async {
    return _cachedExpiringItems;
  }

  static Future<PantryStats?> getCachedStats() async {
    return _cachedStats;
  }

  static Future<List<RecipeSuggestion>> getCachedAiSuggestions({
    String regionCacheKey = 'all',
  }) async {
    if (_cachedAiSuggestions.isNotEmpty) {
      return _cachedAiSuggestions;
    }

    final persisted = await _loadPersistedAiSuggestions(regionCacheKey);
    if (persisted.isNotEmpty) {
      _cachedAiSuggestions = persisted;
    }

    return _cachedAiSuggestions;
  }

  static Future<void> clearCache({bool clearPersistent = false}) async {
    _cachedExpiringItems = [];
    _cachedStats = null;
    _cachedAiSuggestions = [];
    _pageCache = {};
    _pageCacheRegionKey = null;

    if (!clearPersistent) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = prefs
          .getKeys()
          .where((k) => k.startsWith(_aiSuggestionsCachePrefix))
          .toList();
      for (final key in keysToRemove) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('PantryService.clearCache persistent error: $e');
    }
  }

  /// Lấy tất cả sản phẩm active
  static Future<List<PantryItem>> getItems() async {
    try {
      final resp = await ApiService.get(
        '/api/pantry?status=active',
        withAuth: true,
      );
      if (resp.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list.map((e) => PantryItem.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('PantryService.getItems error: $e');
    }
    return [];
  }

  /// Lấy sản phẩm sắp hết hạn
  static Future<List<PantryItem>> getExpiringItems({int days = 7}) async {
    try {
      final resp = await ApiService.get(
        '/api/pantry/expiring?days=$days',
        withAuth: true,
      );
      if (resp.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(resp.bodyBytes));
        final items = list.map((e) => PantryItem.fromJson(e)).toList();
        _cachedExpiringItems = items;
        return items;
      }
    } catch (e) {
      debugPrint('PantryService.getExpiringItems error: $e');
    }
    return [];
  }

  /// Lấy stats cho dashboard
  static Future<PantryStats?> getStats() async {
    try {
      final resp = await ApiService.get('/api/pantry/stats', withAuth: true);
      if (resp.statusCode == 200) {
        final json = jsonDecode(utf8.decode(resp.bodyBytes));
        final stats = PantryStats.fromJson(json);
        _cachedStats = stats;
        return stats;
      }
    } catch (e) {
      debugPrint('PantryService.getStats error: $e');
    }
    return null;
  }

  /// Thêm sản phẩm mới
  static Future<bool> addItem({
    required String nameVi,
    double quantity = 1,
    String unit = 'cái',
    int? categoryId,
    String location = 'fridge',
    DateTime? expiryDate,
    String? notes,
  }) async {
    try {
      final body = {
        'name_vi': nameVi,
        'quantity': quantity,
        'unit': unit,
        if (categoryId != null) 'category_id': categoryId,
        'location': location,
        if (expiryDate != null)
          'expiry_date': expiryDate.toIso8601String().split('T').first,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'add_method': 'manual',
      };
      final resp = await ApiService.post('/api/pantry', body, withAuth: true);
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('PantryService.addItem error: $e');
      return false;
    }
  }

  /// Xóa sản phẩm (soft delete)
  static Future<bool> deleteItem(int id) async {
    try {
      final resp = await ApiService.delete('/api/pantry/$id');
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('PantryService.deleteItem error: $e');
      return false;
    }
  }

  /// Trừ nguyên liệu theo danh sách tên khi bắt đầu nấu.
  /// - Nguyên liệu chính: trừ 1 đơn vị.
  /// - Gia vị dùng nhiều lần (nước mắm, tiêu, đường...): trừ lượng nhỏ.
  static Future<int> consumeIngredientsByNames(
    List<String> ingredientNames,
  ) async {
    final normalizedNames = ingredientNames
        .map(_normalizeIngredientText)
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (normalizedNames.isEmpty) return 0;

    final items = await getItems();
    if (items.isEmpty) return 0;

    var consumedCount = 0;

    for (final ingredient in normalizedNames) {
      PantryItem? matched;
      for (final item in items) {
        final itemName = _normalizeIngredientText(item.name);
        if (_isIngredientLikelyMatch(ingredient, itemName)) {
          matched = item;
          break;
        }
      }

      if (matched == null) continue;

      final deductionAmount = _estimateConsumptionAmount(ingredient, matched);
      if (deductionAmount <= 0) continue;

      final remaining = matched.quantity - deductionAmount;
      final ok = await _applyConsumption(matched, remaining);
      if (ok) consumedCount += 1;
    }

    if (consumedCount > 0) {
      await clearCache();
    }

    return consumedCount;
  }

  static Future<bool> _applyConsumption(
    PantryItem item,
    double remaining,
  ) async {
    try {
      if (remaining > 0) {
        final resp = await ApiService.put('/api/pantry/${item.id}', {
          'quantity': remaining,
          'status': 'active',
        }, withAuth: true);
        return resp.statusCode == 200;
      }

      // Hết nguyên liệu: chuyển trạng thái used để không còn xuất hiện ở danh sách active.
      final resp = await ApiService.put('/api/pantry/${item.id}', {
        'status': 'used',
      }, withAuth: true);
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('PantryService._applyConsumption error: $e');
      return false;
    }
  }

  static String _normalizeIngredientText(String input) {
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

    return text
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _isIngredientLikelyMatch(String ingredient, String pantryName) {
    if (ingredient.isEmpty || pantryName.isEmpty) return false;
    if (ingredient == pantryName) return true;

    final ingredientTokens = ingredient
        .split(' ')
        .where((t) => t.length >= 3)
        .toList();
    final pantryTokens = pantryName
        .split(' ')
        .where((t) => t.length >= 3)
        .toList();

    final overlap = ingredientTokens.where(pantryTokens.contains).length;
    if (overlap >= 2) return true;

    if (ingredient.length >= 4 && pantryName.contains(ingredient)) return true;
    if (pantryName.length >= 4 && ingredient.contains(pantryName)) return true;

    return false;
  }

  /// Gợi ý lượng dùng và quy cách mua cho nguyên liệu thường gặp.
  static IngredientGuidance? getIngredientGuidance(String ingredientName) {
    final normalized = _normalizeIngredientText(ingredientName);
    if (normalized.isEmpty) return null;

    if (normalized.contains('nuoc mam')) {
      return const IngredientGuidance(
        usageHint: 'Dùng ~1 thìa cà phê (5 ml) mỗi lần nấu.',
        purchaseHint: 'Gợi ý mua: 1 chai 1L.',
      );
    }
    if (normalized.contains('duong')) {
      return const IngredientGuidance(
        usageHint: 'Dùng ~1 thìa cà phê (4-5 g) mỗi lần nấu.',
        purchaseHint: 'Gợi ý mua: 1 gói 500 g.',
      );
    }
    if (normalized.contains('muoi')) {
      return const IngredientGuidance(
        usageHint: 'Dùng ~1/2 thìa cà phê (2-3 g) mỗi lần nấu.',
        purchaseHint: 'Gợi ý mua: 1 gói/hũ 500 g.',
      );
    }
    if (normalized.contains('tieu')) {
      return const IngredientGuidance(
        usageHint: 'Dùng ~1/4 thìa cà phê (0.5-1 g) mỗi lần nấu.',
        purchaseHint: 'Gợi ý mua: 1 hũ 100 g.',
      );
    }
    if (normalized.contains('dau an')) {
      return const IngredientGuidance(
        usageHint: 'Dùng ~1 thìa canh (10-15 ml) mỗi lần nấu.',
        purchaseHint: 'Gợi ý mua: 1 chai 1L.',
      );
    }
    if (normalized.contains('hat nem') || normalized.contains('bot ngot')) {
      return const IngredientGuidance(
        usageHint: 'Dùng ~1/2 thìa cà phê (2-3 g) mỗi lần nấu.',
        purchaseHint: 'Gợi ý mua: 1 gói 400-500 g.',
      );
    }
    if (normalized.contains('nuoc tuong') || normalized.contains('xi dau')) {
      return const IngredientGuidance(
        usageHint: 'Dùng ~1 thìa cà phê (5 ml) mỗi lần nấu.',
        purchaseHint: 'Gợi ý mua: 1 chai 500 ml.',
      );
    }
    return null;
  }

  static double _estimateConsumptionAmount(
    String normalizedIngredient,
    PantryItem item,
  ) {
    if (_isReusableIngredient(normalizedIngredient)) {
      if (normalizedIngredient.contains('tieu')) return 1;
      if (normalizedIngredient.contains('duong') ||
          normalizedIngredient.contains('muoi') ||
          normalizedIngredient.contains('hat nem') ||
          normalizedIngredient.contains('bot ngot')) {
        return item.unit.toLowerCase().contains('kg') ? 0.005 : 5;
      }

      final unit = _normalizeIngredientText(item.unit);

      if (unit.contains('ml')) return 10;
      if (unit == 'l' || unit.contains('lit')) return 0.01;
      if (unit == 'g' || unit == 'gram') return 5;
      if (unit == 'kg') return 0.005;
      if (unit.contains('muong') || unit.contains('thia')) return 0.5;

      // Với đơn vị khó suy luận (chai/hũ/gói...), trừ nhẹ 0.1 đơn vị.
      return 0.1;
    }

    return 1;
  }

  static bool _isReusableIngredient(String normalizedIngredient) {
    const reusableKeywords = <String>[
      'nuoc mam',
      'nuoc tuong',
      'xi dau',
      'dau hao',
      'tuong ot',
      'tuong ca',
      'muoi',
      'duong',
      'hat nem',
      'bot ngot',
      'tieu',
      'ot bot',
      'bot canh',
      'dau an',
      'dau me',
      'giam',
      'ruou nau',
      'sa te',
      'gia vi',
    ];

    return reusableKeywords.any(normalizedIngredient.contains);
  }

  // Chuẩn hóa tên món để so khớp trùng lặp ổn định hơn (không phân biệt dấu, ký tự đặc biệt).
  static String normalizeRecipeName(String name) {
    var text = _normalizeIngredientText(name);

    final replacements = <MapEntry<String, String>>[
      const MapEntry('thit bo', 'bo'),
      const MapEntry('thit heo', 'heo'),
      const MapEntry('thit lon', 'heo'),
      const MapEntry('thit ga', 'ga'),
      const MapEntry('hai san', 'haisan'),
      const MapEntry('xao ', 'xao '),
      const MapEntry('chien ', 'chien '),
      const MapEntry('hap ', 'hap '),
      const MapEntry('nuong ', 'nuong '),
    ];

    for (final r in replacements) {
      text = text.replaceAll(r.key, r.value);
    }

    const ignoredTokens = <String>{
      'mon',
      'kieu',
      'phien',
      'ban',
      'dac',
      'biet',
      'ngon',
      'hom',
      'nay',
    };

    final tokens = text
        .split(' ')
        .where((t) => t.isNotEmpty)
        .where((t) => !ignoredTokens.contains(t))
        .toList();

    return tokens.join(' ').trim();
  }

  static bool isSimilar(String a, String b) {
    final na = normalizeRecipeName(a);
    final nb = normalizeRecipeName(b);

    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;

    final ta = na.split(' ').where((e) => e.isNotEmpty).toSet();
    final tb = nb.split(' ').where((e) => e.isNotEmpty).toSet();
    if (ta.isEmpty || tb.isEmpty) return false;

    final intersection = ta.intersection(tb).length;
    final union = ta.union(tb).length;
    if (union == 0) return false;

    final jaccard = intersection / union;
    final containRatio =
        intersection / (ta.length < tb.length ? ta.length : tb.length);

    return jaccard >= 0.72 || containRatio >= 0.85;
  }

  static bool _isDuplicateRecipe(
    RecipeSuggestion incoming,
    List<RecipeSuggestion> existing,
  ) {
    for (final current in existing) {
      if (incoming.id.isNotEmpty &&
          current.id.isNotEmpty &&
          incoming.id == current.id) {
        return true;
      }

      if (isSimilar(incoming.name, current.name)) {
        return true;
      }
    }

    return false;
  }

  static List<RecipeSuggestion> _dedupeRecipeSuggestions(
    List<RecipeSuggestion> items,
  ) {
    final result = <RecipeSuggestion>[];
    for (final item in items) {
      if (_isDuplicateRecipe(item, result)) continue;
      result.add(item);
    }
    return result;
  }

  static int _countPantryMatches(
    RecipeSuggestion recipe,
    List<PantryItem> pantry,
  ) {
    if (pantry.isEmpty) return 0;

    final pantryNames = pantry
        .map((e) => _normalizeIngredientText(e.name))
        .where((e) => e.isNotEmpty)
        .toList();

    final ingredientCandidates = <String>{
      ...recipe.ingredientsUsed,
      ...recipe.ingredientsMissing.take(2),
    }.map(_normalizeIngredientText).where((e) => e.isNotEmpty).toList();

    var matchCount = 0;
    for (final ing in ingredientCandidates) {
      final matched = pantryNames.any(
        (p) =>
            _isIngredientLikelyMatch(ing, p) ||
            _isIngredientLikelyMatch(p, ing),
      );
      if (matched) {
        matchCount++;
      }
    }

    return matchCount;
  }

  static bool isRelevantRecipe(
    RecipeSuggestion recipe,
    List<PantryItem> pantry,
  ) {
    if (pantry.isEmpty) return true;

    final matchCount = _countPantryMatches(recipe, pantry);
    final requiredMatches = pantry.length >= 4 ? 2 : 1;
    return matchCount >= requiredMatches;
  }

  /// Lấy gợi ý món ăn từ AI
  static Future<AiSuggestionPage> getAiSuggestionsPage({
    int limit = 15,
    int offset = 0,
    RegionalProfile? regionalProfile,
  }) async {
    try {
      final profile =
          regionalProfile ?? await RegionPreferenceService.getProfile();
      _syncPageCacheRegion(profile.cacheKey);

      // Check cache theo page trước.
      if (_pageCache.containsKey(offset)) {
        final cachedPage = _pageCache[offset]!;
        return AiSuggestionPage(
          suggestions: cachedPage,
          limit: limit,
          offset: offset,
          nextOffset: offset + cachedPage.length,
          hasMore: true,
          totalCandidates: cachedPage.length,
        );
      }

      final preferences = <String, dynamic>{
        'cuisine': profile.cuisinePreference,
        'regional_seasoning': profile.seasoningPreference,
        'region_code': profile.cacheKey,
      };
      final detected = profile.detectedLocation?.trim();
      if (detected != null && detected.isNotEmpty) {
        preferences['detected_location'] = detected;
      }

      final resp = await ApiService.post('/api/recipes/suggest-from-pantry', {
        'limit': limit,
        'offset': offset,
        'preferences': preferences,
      }, withAuth: true);

      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        if (data['success'] == true && data['recipes'] != null) {
          final List list = data['recipes'];
          final suggestions = _dedupeRecipeSuggestions(
            list.map((e) => RecipeSuggestion.fromJson(e)).toList(),
          );

          final items = await getItems();

          // Filter relevance
          final filtered = suggestions
              .where((r) => isRelevantRecipe(r, items))
              .toList();

          final safeLimit = (data['limit'] as num?)?.toInt() ?? limit;
          final safeOffset = (data['offset'] as num?)?.toInt() ?? offset;
          final safeNextOffset =
              (data['next_offset'] as num?)?.toInt() ??
              (safeOffset + filtered.length);
          final hasMore =
              (data['has_more'] as bool?) ??
              (filtered.length >= safeLimit && filtered.isNotEmpty);
          final totalCandidates =
              (data['total_candidates'] as num?)?.toInt() ?? 0;

          // Deduplicate nâng cao
          final merged = offset <= 0
              ? <RecipeSuggestion>[]
              : List<RecipeSuggestion>.from(_cachedAiSuggestions);
          final existingKeys = merged
              .map((e) => normalizeRecipeName(e.name))
              .toSet();

          for (final item in filtered) {
            final key = normalizeRecipeName(item.name);
            final isDup = existingKeys.any((k) => isSimilar(k, key));
            if (isDup) continue;

            merged.add(item);
            existingKeys.add(key);
          }

          // update cache
          _cachedAiSuggestions = merged;
          _pageCache[offset] = filtered;
          await _persistAiSuggestions(_cachedAiSuggestions, profile.cacheKey);

          return AiSuggestionPage(
            suggestions: filtered,
            limit: safeLimit,
            offset: safeOffset,
            nextOffset: safeNextOffset,
            hasMore: hasMore,
            totalCandidates: totalCandidates,
          );
        }
      }
    } catch (e) {
      debugPrint('PantryService.getAiSuggestionsPage error: $e');
    }

    if (offset > 0) {
      return AiSuggestionPage.empty(limit: limit, offset: offset);
    }

    final profile =
        regionalProfile ?? await RegionPreferenceService.getProfile();
    final cached = await getCachedAiSuggestions(
      regionCacheKey: profile.cacheKey,
    );
    return AiSuggestionPage(
      suggestions: cached,
      limit: limit,
      offset: 0,
      nextOffset: cached.length,
      hasMore: false,
      totalCandidates: cached.length,
    );
  }

  /// Lấy gợi ý món ăn từ AI
  static Future<List<RecipeSuggestion>> getAiSuggestions({
    int limit = 15,
    int offset = 0,
    RegionalProfile? regionalProfile,
  }) async {
    final page = await getAiSuggestionsPage(
      limit: limit,
      offset: offset,
      regionalProfile: regionalProfile,
    );
    return page.suggestions;
  }
}

class AiSuggestionPage {
  final List<RecipeSuggestion> suggestions;
  final int limit;
  final int offset;
  final int nextOffset;
  final bool hasMore;
  final int totalCandidates;

  const AiSuggestionPage({
    required this.suggestions,
    required this.limit,
    required this.offset,
    required this.nextOffset,
    required this.hasMore,
    required this.totalCandidates,
  });

  factory AiSuggestionPage.empty({required int limit, required int offset}) {
    return AiSuggestionPage(
      suggestions: const [],
      limit: limit,
      offset: offset,
      nextOffset: offset,
      hasMore: false,
      totalCandidates: 0,
    );
  }
}

class IngredientGuidance {
  final String usageHint;
  final String purchaseHint;

  const IngredientGuidance({
    required this.usageHint,
    required this.purchaseHint,
  });
}
