import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'fridge_service.dart';
import 'region_preference_service.dart';
import '../models/recipe_suggestion.dart';

enum RecipeSuggestionMode { pantry, region }

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
  final int? fridgeId;

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
    this.fridgeId,
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
      fridgeId: json['fridge_id'],
    );
  }

  /// Số ngày còn lại trước khi hết hạn
  int get daysUntilExpiry {
    if (expiryDate == null) return 999;
    return expiryDate!.difference(DateTime.now()).inDays;
  }

  bool get isExpired => daysUntilExpiry <= 0;
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

  static String _modeCacheCode(RecipeSuggestionMode mode) {
    return mode == RecipeSuggestionMode.region ? 'region' : 'pantry';
  }

  static Future<String> _getAiSuggestionsCacheKey({
    RecipeSuggestionMode mode = RecipeSuggestionMode.pantry,
    int? fridgeId,
    String? region,
  }) async {
    final suffix = await _getUserCacheSuffix();
    final modeSuffix = '_m${_modeCacheCode(mode)}';
    final regionSuffix = (region != null && region.isNotEmpty)
        ? '_r${_normalizeRegionCode(region)}'
        : '';
    final fridgeSuffix = fridgeId != null ? '_f$fridgeId' : '';
    return '$_aiSuggestionsCachePrefix${suffix}$modeSuffix$regionSuffix$fridgeSuffix';
  }

  static Future<void> _persistAiSuggestions(
    List<RecipeSuggestion> suggestions, {
    RecipeSuggestionMode mode = RecipeSuggestionMode.pantry,
    int? fridgeId,
    String? region,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = await _getAiSuggestionsCacheKey(
        mode: mode,
        fridgeId: fridgeId,
        region: region,
      );
      final payload = jsonEncode(suggestions.map((e) => e.toJson()).toList());
      await prefs.setString(cacheKey, payload);
    } catch (e) {
      debugPrint('PantryService._persistAiSuggestions error: $e');
    }
  }

  static Future<List<RecipeSuggestion>> _loadPersistedAiSuggestions({
    RecipeSuggestionMode mode = RecipeSuggestionMode.pantry,
    int? fridgeId,
    String? region,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = await _getAiSuggestionsCacheKey(
        mode: mode,
        fridgeId: fridgeId,
        region: region,
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
    RecipeSuggestionMode mode = RecipeSuggestionMode.pantry,
    int? fridgeId,
    String? region,
  }) async {
    final persisted = await _loadPersistedAiSuggestions(
      mode: mode,
      fridgeId: fridgeId,
      region: region,
    );
    if (persisted.isNotEmpty) {
      _cachedAiSuggestions = persisted;
    }

    return persisted;
  }

  static Future<void> clearCache({bool clearPersistent = false}) async {
    _cachedExpiringItems = [];
    _cachedStats = null;
    _cachedAiSuggestions = [];

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
  static Future<List<PantryItem>> getItems({int? fridgeId}) async {
    try {
      final effectiveFridgeId = fridgeId ?? await FridgeService.getActiveFridgeId();
      final queryParams = effectiveFridgeId != null ? '&fridgeId=$effectiveFridgeId' : '';
      
      final resp = await ApiService.get(
        '/api/v1/pantry?status=active$queryParams',
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

  /// Lấy sản phẩm theo fridge ID cụ thể
  static Future<List<PantryItem>> getItemsForFridge(int fridgeId) async {
    try {
      final resp = await ApiService.get(
        '/api/v1/pantry?status=active&fridgeId=$fridgeId',
        withAuth: true,
      );
      if (resp.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list.map((e) => PantryItem.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint('PantryService.getItemsForFridge error: $e');
    }
    return [];
  }

  /// Lấy sản phẩm sắp hết hạn
  static Future<List<PantryItem>> getExpiringItems({int days = 7}) async {
    try {
      final fridgeId = await FridgeService.getActiveFridgeId();
      final queryParams = fridgeId != null ? '&fridgeId=$fridgeId' : '';

      final resp = await ApiService.get(
        '/api/v1/pantry/expiring?days=$days$queryParams',
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
      final fridgeId = await FridgeService.getActiveFridgeId();
      final queryParams = fridgeId != null ? '?fridgeId=$fridgeId' : '';
      
      final resp = await ApiService.get('/api/v1/pantry/stats$queryParams', withAuth: true);
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
    int? fridgeId, // Optional: override active fridge
  }) async {
    try {
      final effectiveFridgeId = fridgeId ?? await FridgeService.getActiveFridgeId();
      
      // Check if fridge is paused
      if (effectiveFridgeId != null) {
        final fridges = await FridgeService().getFridges();
        final targetFridge = fridges.firstWhere(
          (f) => f.fridgeId == effectiveFridgeId,
          orElse: () => throw Exception('Không tìm thấy tủ lạnh'),
        );
        
        if (targetFridge.status == 'paused') {
          debugPrint('Tủ lạnh ${targetFridge.name} đang tạm ngưng');
          return false;
        }
      }
      
      final body = {
        'name_vi': nameVi,
        'quantity': quantity,
        'unit': unit,
        if (categoryId != null) 'category_id': categoryId,
        if (effectiveFridgeId != null) 'fridge_id': effectiveFridgeId,
        'location': location,
        if (expiryDate != null)
          'expiry_date': expiryDate.toIso8601String().split('T').first,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'add_method': 'manual',
      };
      final resp = await ApiService.post('/api/v1/pantry', body, withAuth: true);
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('PantryService.addItem error: $e');
      return false;
    }
  }

  /// Xóa sản phẩm (soft delete)
  static Future<bool> deleteItem(int id) async {
    try {
      final resp = await ApiService.delete('/api/v1/pantry/$id');
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('PantryService.deleteItem error: $e');
      return false;
    }
  }

  /// Lấy gợi ý món ăn từ AI
  static Future<List<RecipeSuggestion>> getAiSuggestions({
    RecipeSuggestionMode mode = RecipeSuggestionMode.pantry,
    int? fridgeId,
    String? region,
    int limit = 15,
    String? refreshToken,
    List<String>? excludeRecipeNames,
    String? dietaryPreference,
  }) async {
    try {
      final regionCode = await _resolveRegionCode(region);
      final endpoint = mode == RecipeSuggestionMode.region
          ? '/api/v1/recipes/suggest-by-region'
          : '/api/v1/recipes/suggest-from-pantry';

      var url = '$endpoint?limit=$limit&region=$regionCode';
      if (mode == RecipeSuggestionMode.pantry && fridgeId != null) {
        url += '&fridgeId=$fridgeId';
      }
      if (refreshToken != null && refreshToken.isNotEmpty) {
        url += '&refreshToken=${Uri.encodeQueryComponent(refreshToken)}';
      }
      if (excludeRecipeNames != null && excludeRecipeNames.isNotEmpty) {
        final cleaned = excludeRecipeNames
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList();
        if (cleaned.isNotEmpty) {
          final raw = cleaned.join(',');
          url += '&excludeRecipeNames=${Uri.encodeQueryComponent(raw)}';
        }
      }
      if (dietaryPreference != null && dietaryPreference.isNotEmpty) {
        url += '&dietary=${Uri.encodeQueryComponent(dietaryPreference)}';
      }
      
      final resp = await ApiService.get(
        url,
        withAuth: true,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        if (data['success'] == true && data['recipes'] != null) {
          final List list = data['recipes'];
          final suggestions = list
              .map((e) => RecipeSuggestion.fromJson(e))
              .toList();
          _cachedAiSuggestions = suggestions;
          await _persistAiSuggestions(
            suggestions,
            mode: mode,
            fridgeId: fridgeId,
            region: regionCode,
          );
          return suggestions;
        }
      }
    } catch (e) {
      debugPrint('PantryService.getAiSuggestions error: $e');
    }
    final regionCode = await _resolveRegionCode(region);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      if (mode == RecipeSuggestionMode.region) {
        return _regionFallbackRecipes(regionCode, limit, dietaryPreference);
      }
      return _pantryRefreshFallback(limit, refreshToken, dietaryPreference);
    }
    final cached = await getCachedAiSuggestions(
      mode: mode,
      fridgeId: fridgeId,
      region: region,
    );
    if (cached.isNotEmpty) return cached;

    if (mode == RecipeSuggestionMode.region) {
      return _regionFallbackRecipes(regionCode, limit, dietaryPreference);
    }
    return [];
  }

  static Future<String> _resolveRegionCode(String? region) async {
    if (region != null && region.trim().isNotEmpty) {
      return _normalizeRegionCode(region);
    }

    final profile = await RegionPreferenceService.getProfile();
    switch (profile.region) {
      case VietnamRegion.north:
        return 'north';
      case VietnamRegion.central:
        return 'central';
      case VietnamRegion.south:
        return 'south';
    }
  }

  static String _normalizeRegionCode(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'bac') return 'north';
    if (value == 'trung') return 'central';
    if (value == 'nam') return 'south';
    return value;
  }

  static List<RecipeSuggestion> _regionFallbackRecipes(
    String regionCode,
    int limit, [
    String? dietaryPreference,
  ]) {
    final fallback = <String, List<RecipeSuggestion>>{
      'north': [
        RecipeSuggestion(
          id: 'north_1',
          name: 'Bún thang Hà Nội',
          description: 'Món bún thanh vị, hợp bữa sáng hoặc trưa nhẹ.',
          ingredientsUsed: const ['bún', 'trứng', 'gà'],
          cookTimeMinutes: 30,
          difficulty: 'medium',
          matchScore: 0.82,
        ),
        RecipeSuggestion(
          id: 'north_2',
          name: 'Cá rô kho tộ',
          description: 'Món kho đậm đà miền Bắc, ăn cùng cơm rất hợp.',
          ingredientsUsed: const ['cá', 'hành', 'nước mắm'],
          cookTimeMinutes: 28,
          difficulty: 'easy',
          matchScore: 0.8,
        ),
      ],
      'central': [
        RecipeSuggestion(
          id: 'central_1',
          name: 'Mì Quảng gà',
          description: 'Sợi mì dai thơm, nước dùng đậm vừa phải đúng chất miền Trung.',
          ingredientsUsed: const ['mì quảng', 'gà', 'đậu phộng'],
          cookTimeMinutes: 35,
          difficulty: 'medium',
          matchScore: 0.83,
        ),
        RecipeSuggestion(
          id: 'central_2',
          name: 'Bún bò Huế',
          description: 'Nước dùng thơm sả, vị đậm và cay nhẹ rất cuốn.',
          ingredientsUsed: const ['bún', 'bò', 'sả'],
          cookTimeMinutes: 40,
          difficulty: 'medium',
          matchScore: 0.81,
        ),
      ],
      'south': [
        RecipeSuggestion(
          id: 'south_1',
          name: 'Canh chua cá',
          description: 'Canh chua ngọt hài hòa kiểu miền Nam, ăn là mát người.',
          ingredientsUsed: const ['cá', 'dứa', 'cà chua'],
          cookTimeMinutes: 25,
          difficulty: 'easy',
          matchScore: 0.82,
        ),
        RecipeSuggestion(
          id: 'south_2',
          name: 'Thịt kho tàu',
          description: 'Món kho mặn ngọt đặc trưng miền Nam, hợp cơm gia đình.',
          ingredientsUsed: const ['thịt ba chỉ', 'trứng', 'nước dừa'],
          cookTimeMinutes: 40,
          difficulty: 'easy',
          matchScore: 0.84,
        ),
      ],
    };

    final dietaryFallback = _dietaryFallbackRecipes(dietaryPreference);
    final recipes = dietaryFallback.isNotEmpty
        ? dietaryFallback
        : (fallback[regionCode] ?? fallback['south']!);
    if (limit <= 0) return recipes;
    if (recipes.length <= limit) return recipes;
    return recipes.take(limit).toList();
  }

  static List<RecipeSuggestion> _pantryRefreshFallback(
    int limit,
    String refreshToken, [
    String? dietaryPreference,
  ]) {
    final dietaryFallback = _dietaryFallbackRecipes(dietaryPreference);
    final pool = dietaryFallback.isNotEmpty ? dietaryFallback : <RecipeSuggestion>[
      RecipeSuggestion(
        id: 'p_f_1',
        name: 'Gà kho gừng',
        description: 'Thơm ấm vị gừng, hợp bữa cơm gia đình.',
        ingredientsUsed: const ['gà', 'gừng', 'hành tím'],
        cookTimeMinutes: 28,
        difficulty: 'easy',
        matchScore: 0.78,
      ),
      RecipeSuggestion(
        id: 'p_f_2',
        name: 'Canh rau ngót thịt bằm',
        description: 'Món canh thanh mát, nấu nhanh và dễ ăn.',
        ingredientsUsed: const ['rau ngót', 'thịt bằm'],
        cookTimeMinutes: 15,
        difficulty: 'easy',
        matchScore: 0.76,
      ),
      RecipeSuggestion(
        id: 'p_f_3',
        name: 'Cà tím xào thịt bằm',
        description: 'Món xào mềm thơm, đậm vị, rất đưa cơm.',
        ingredientsUsed: const ['cà tím', 'thịt bằm', 'tỏi'],
        cookTimeMinutes: 18,
        difficulty: 'easy',
        matchScore: 0.74,
      ),
      RecipeSuggestion(
        id: 'p_f_4',
        name: 'Bò lúc lắc',
        description: 'Thịt bò mềm thơm, có thể ăn với cơm hoặc salad.',
        ingredientsUsed: const ['thịt bò', 'ớt chuông'],
        cookTimeMinutes: 20,
        difficulty: 'medium',
        matchScore: 0.75,
      ),
      RecipeSuggestion(
        id: 'p_f_5',
        name: 'Mướp xào trứng',
        description: 'Món dân dã nhanh gọn, vị ngọt tự nhiên.',
        ingredientsUsed: const ['mướp', 'trứng'],
        cookTimeMinutes: 12,
        difficulty: 'easy',
        matchScore: 0.73,
      ),
      RecipeSuggestion(
        id: 'p_f_6',
        name: 'Đậu que xào tỏi',
        description: 'Rau giòn xanh, phù hợp bữa ăn nhẹ nhàng.',
        ingredientsUsed: const ['đậu que', 'tỏi'],
        cookTimeMinutes: 10,
        difficulty: 'easy',
        matchScore: 0.72,
      ),
    ];

    final list = List<RecipeSuggestion>.from(pool);
    final seed = refreshToken.hashCode;
    final random = DateTime.fromMillisecondsSinceEpoch(seed.abs() % 2147483647)
        .millisecondsSinceEpoch;
    list.sort((a, b) => (a.id.hashCode ^ random).compareTo(b.id.hashCode ^ random));
    final take = limit <= 0 ? 5 : limit;
    if (list.length <= take) return list;
    return list.take(take).toList();
  }

  static List<RecipeSuggestion> _dietaryFallbackRecipes(String? dietaryPreference) {
    final normalized = dietaryPreference?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) return const [];

    if (normalized == 'vegetarian' || normalized == 'an_chay') {
      return const [
        RecipeSuggestion(
          id: 'diet_veg_1',
          name: 'Đậu hũ sốt nấm',
          description: 'Món chay thanh vị, dễ nấu cho bữa hằng ngày.',
          ingredientsUsed: ['đậu hũ', 'nấm', 'hành boa rô'],
          cookTimeMinutes: 18,
          difficulty: 'easy',
          matchScore: 0.84,
        ),
        RecipeSuggestion(
          id: 'diet_veg_2',
          name: 'Canh bí đỏ đậu hũ',
          description: 'Canh nhẹ bụng, ngọt tự nhiên và hợp bữa tối.',
          ingredientsUsed: ['bí đỏ', 'đậu hũ'],
          cookTimeMinutes: 20,
          difficulty: 'easy',
          matchScore: 0.82,
        ),
        RecipeSuggestion(
          id: 'diet_veg_3',
          name: 'Rau củ hấp chấm mè rang',
          description: 'Ít dầu mỡ, giữ trọn vị ngọt tự nhiên của rau củ.',
          ingredientsUsed: ['bông cải', 'cà rốt', 'bí ngòi'],
          cookTimeMinutes: 15,
          difficulty: 'easy',
          matchScore: 0.8,
        ),
      ];
    }

    if (normalized == 'weight_loss' || normalized == 'giam_can') {
      return const [
        RecipeSuggestion(
          id: 'diet_fit_1',
          name: 'Ức gà áp chảo rau củ',
          description: 'Món ít dầu, giàu đạm và phù hợp chế độ giảm cân.',
          ingredientsUsed: ['ức gà', 'rau củ'],
          cookTimeMinutes: 20,
          difficulty: 'easy',
          matchScore: 0.85,
        ),
        RecipeSuggestion(
          id: 'diet_fit_2',
          name: 'Salad cá ngừ trứng luộc',
          description: 'Nhẹ bụng, đủ chất và làm rất nhanh.',
          ingredientsUsed: ['cá ngừ', 'xà lách', 'trứng'],
          cookTimeMinutes: 15,
          difficulty: 'easy',
          matchScore: 0.83,
        ),
        RecipeSuggestion(
          id: 'diet_fit_3',
          name: 'Canh nấm ức gà',
          description: 'Món canh thanh, ít calo, hợp bữa tối.',
          ingredientsUsed: ['nấm', 'ức gà'],
          cookTimeMinutes: 18,
          difficulty: 'easy',
          matchScore: 0.81,
        ),
      ];
    }

    if (normalized == 'eat_clean') {
      return const [
        RecipeSuggestion(
          id: 'diet_clean_1',
          name: 'Cá hồi áp chảo măng tây',
          description: 'Bữa ăn Eat Clean đủ đạm, rau và chất béo tốt.',
          ingredientsUsed: ['cá hồi', 'măng tây'],
          cookTimeMinutes: 18,
          difficulty: 'easy',
          matchScore: 0.85,
        ),
        RecipeSuggestion(
          id: 'diet_clean_2',
          name: 'Cơm gạo lứt bò xào rau',
          description: 'Món Eat Clean cân bằng, phù hợp bữa trưa.',
          ingredientsUsed: ['gạo lứt', 'thịt bò', 'rau củ'],
          cookTimeMinutes: 25,
          difficulty: 'medium',
          matchScore: 0.83,
        ),
        RecipeSuggestion(
          id: 'diet_clean_3',
          name: 'Tôm hấp bí ngòi',
          description: 'Thanh nhẹ, ít dầu mỡ và giữ vị tự nhiên.',
          ingredientsUsed: ['tôm', 'bí ngòi'],
          cookTimeMinutes: 16,
          difficulty: 'easy',
          matchScore: 0.8,
        ),
      ];
    }

    return const [];
  }

  /// Tự động cleanup sản phẩm hết hạn
  static Future<List<String>> cleanupExpiredItems() async {
    try {
      final resp = await ApiService.post(
        '/api/v1/pantry/cleanup-expired',
        {},
        withAuth: true,
      );
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        final int count = data['cleaned_count'] ?? 0;
        if (count > 0) {
          final List items = data['items'] ?? [];
          return items.map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      debugPrint('PantryService.cleanupExpiredItems error: $e');
    }
    return [];
  }

  /// Toggle preference key for showing/hiding expired items
  static const String _showExpiredKey = 'show_expired_items';

  static Future<bool> getShowExpiredPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showExpiredKey) ?? true;
  }

  static Future<void> setShowExpiredPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showExpiredKey, value);
  }

  /// Toggle preference key for showing/hiding AI suggestions
  static const String _showAiSuggestionsKey = 'show_ai_suggestions';

  static Future<bool> getShowAiSuggestionsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showAiSuggestionsKey) ?? true;
  }

  static Future<void> setShowAiSuggestionsPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showAiSuggestionsKey, value);
  }
}
