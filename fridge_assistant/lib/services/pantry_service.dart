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
  static const String _recipeSuggestionsCachePrefix =
      'pantry_recipe_suggestions_v3_';
  static const String _legacyAiSuggestionsCachePrefix =
      'pantry_ai_suggestions_v2_';
  static List<PantryItem> _cachedExpiringItems = [];
  static PantryStats? _cachedStats;
  static List<RecipeSuggestion> _cachedRecipeSuggestions = [];
  static DateTime? _catalogCooldownUntil;

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

  static Future<String> _getRecipeSuggestionsCacheKey({
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
    return '$_recipeSuggestionsCachePrefix${suffix}$modeSuffix$regionSuffix$fridgeSuffix';
  }

  static Future<void> _persistRecipeSuggestions(
    List<RecipeSuggestion> suggestions, {
    RecipeSuggestionMode mode = RecipeSuggestionMode.pantry,
    int? fridgeId,
    String? region,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = await _getRecipeSuggestionsCacheKey(
        mode: mode,
        fridgeId: fridgeId,
        region: region,
      );
      final payload = jsonEncode(suggestions.map((e) => e.toJson()).toList());
      await prefs.setString(cacheKey, payload);
    } catch (e) {
      debugPrint('PantryService._persistRecipeSuggestions error: $e');
    }
  }

  static Future<List<RecipeSuggestion>> _loadPersistedRecipeSuggestions({
    RecipeSuggestionMode mode = RecipeSuggestionMode.pantry,
    int? fridgeId,
    String? region,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = await _getRecipeSuggestionsCacheKey(
        mode: mode,
        fridgeId: fridgeId,
        region: region,
      );
      final legacyCacheKey = cacheKey.replaceFirst(
        _recipeSuggestionsCachePrefix,
        _legacyAiSuggestionsCachePrefix,
      );
      final raw = prefs.getString(cacheKey) ?? prefs.getString(legacyCacheKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      return decoded
          .whereType<Map>()
          .map((e) => RecipeSuggestion.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('PantryService._loadPersistedRecipeSuggestions error: $e');
      return [];
    }
  }

  static Future<List<PantryItem>> getCachedExpiringItems() async {
    return _cachedExpiringItems;
  }

  static Future<PantryStats?> getCachedStats() async {
    return _cachedStats;
  }

  static Future<List<RecipeSuggestion>> getCachedRecipeSuggestions({
    RecipeSuggestionMode mode = RecipeSuggestionMode.pantry,
    int? fridgeId,
    String? region,
  }) async {
    final persisted = await _loadPersistedRecipeSuggestions(
      mode: mode,
      fridgeId: fridgeId,
      region: region,
    );
    if (persisted.isNotEmpty) {
      _cachedRecipeSuggestions = persisted;
    }

    return persisted;
  }

  static Future<List<RecipeSuggestion>> getCachedAiSuggestions({
    RecipeSuggestionMode mode = RecipeSuggestionMode.pantry,
    int? fridgeId,
    String? region,
  }) {
    return getCachedRecipeSuggestions(
      mode: mode,
      fridgeId: fridgeId,
      region: region,
    );
  }

  static Future<void> clearCache({bool clearPersistent = false}) async {
    _cachedExpiringItems = [];
    _cachedStats = null;
    _cachedRecipeSuggestions = [];
    _catalogCooldownUntil = null;

    if (!clearPersistent) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = prefs
          .getKeys()
          .where(
            (k) =>
                k.startsWith(_recipeSuggestionsCachePrefix) ||
                k.startsWith(_legacyAiSuggestionsCachePrefix),
          )
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
      final success = resp.statusCode == 200;
      if (success) {
        await clearCache(clearPersistent: true);
      }
      return success;
    } catch (e) {
      debugPrint('PantryService.addItem error: $e');
      return false;
    }
  }

  /// Xóa sản phẩm (soft delete)
  static Future<bool> deleteItem(int id) async {
    try {
      final resp = await ApiService.delete('/api/v1/pantry/$id');
      final success = resp.statusCode == 200;
      if (success) {
        await clearCache(clearPersistent: true);
      }
      return success;
    } catch (e) {
      debugPrint('PantryService.deleteItem error: $e');
      return false;
    }
  }

  /// Lấy gợi ý công thức theo luồng: recipe catalog -> cache fallback
  static Future<List<RecipeSuggestion>> getRecipeSuggestions({
    RecipeSuggestionMode mode = RecipeSuggestionMode.pantry,
    int? fridgeId,
    String? region,
    int limit = 15,
    String? refreshToken,
    List<String>? excludeRecipeNames,
    String? dietaryPreference,
  }) async {
    final regionCode = await _resolveRegionCode(region);
    final canUseCachedFallback =
        (refreshToken == null || refreshToken.isEmpty) &&
        (excludeRecipeNames == null || excludeRecipeNames.isEmpty);

    final cooldownMessage = _currentCatalogCooldownMessage();
    if (cooldownMessage != null) {
      if (canUseCachedFallback) {
        final cached = await getCachedRecipeSuggestions(
          mode: mode,
          fridgeId: fridgeId,
          region: regionCode,
        );
        if (cached.isNotEmpty) return cached;
      }
      throw Exception(cooldownMessage);
    }

    try {
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

      final responseText = utf8.decode(resp.bodyBytes);
      Map<String, dynamic>? data;
      if (responseText.isNotEmpty) {
        try {
          final decoded = jsonDecode(responseText);
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          } else if (decoded is Map) {
            data = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }

      if (resp.statusCode == 200 && data != null && data['success'] == true) {
        final rawRecipes = data['recipes'];
        if (rawRecipes is List) {
          final suggestions = rawRecipes
              .map((e) => RecipeSuggestion.fromJson(Map<String, dynamic>.from(e)))
              .toList();

          _cachedRecipeSuggestions = suggestions;
          await _persistRecipeSuggestions(
            suggestions,
            mode: mode,
            fridgeId: fridgeId,
            region: regionCode,
          );

          return suggestions;
        }
      }

      final message =
          data?['error']?.toString() ??
          data?['message']?.toString() ??
          'Không lấy được gợi ý công thức lúc này.';
      _applyCatalogCooldownFromMessage(message);
      throw Exception(message);
    } catch (e) {
      debugPrint('PantryService.getRecipeSuggestions error: $e');

      final cleanedMessage = e.toString().replaceFirst('Exception: ', '').trim().isEmpty
          ? 'Không lấy được gợi ý công thức lúc này.'
          : e.toString().replaceFirst('Exception: ', '');
      _applyCatalogCooldownFromMessage(cleanedMessage);

      if (canUseCachedFallback) {
        final cached = await getCachedRecipeSuggestions(
          mode: mode,
          fridgeId: fridgeId,
          region: regionCode,
        );
        if (cached.isNotEmpty) return cached;
      }

      throw Exception(cleanedMessage);
    }
  }

  static Future<List<RecipeSuggestion>> getAiSuggestions({
    RecipeSuggestionMode mode = RecipeSuggestionMode.pantry,
    int? fridgeId,
    String? region,
    int limit = 15,
    String? refreshToken,
    List<String>? excludeRecipeNames,
    String? dietaryPreference,
  }) {
    return getRecipeSuggestions(
      mode: mode,
      fridgeId: fridgeId,
      region: region,
      limit: limit,
      refreshToken: refreshToken,
      excludeRecipeNames: excludeRecipeNames,
      dietaryPreference: dietaryPreference,
    );
  }

  static bool get hasActiveRecipeCooldown =>
      _catalogCooldownUntil != null &&
      _catalogCooldownUntil!.isAfter(DateTime.now());

  static int get recipeCooldownRemainingSeconds {
    if (!hasActiveRecipeCooldown) return 0;
    final remaining =
        _catalogCooldownUntil!.difference(DateTime.now()).inSeconds;
    return remaining <= 0 ? 1 : remaining;
  }

  static String? get currentRecipeCooldownMessage =>
      _currentCatalogCooldownMessage();

  static bool get hasActiveAiCooldown => hasActiveRecipeCooldown;

  static int get aiCooldownRemainingSeconds => recipeCooldownRemainingSeconds;

  static String? get currentAiCooldownMessage => currentRecipeCooldownMessage;

  static String? _currentCatalogCooldownMessage() {
    if (!hasActiveRecipeCooldown) return null;
    return 'Nguồn công thức đang tạm nghỉ để tránh vượt quota. Vui lòng thử lại sau $recipeCooldownRemainingSeconds giây.';
  }

  static void _applyCatalogCooldownFromMessage(String message) {
    final retryMatch = RegExp(
      r'thử lại sau\s+(\d+)\s*giây',
      caseSensitive: false,
    ).firstMatch(message);
    if (retryMatch == null) return;

    final retrySeconds = int.tryParse(retryMatch.group(1) ?? '');
    if (retrySeconds == null || retrySeconds <= 0) return;

    final retryUntil = DateTime.now().add(Duration(seconds: retrySeconds));
    if (_catalogCooldownUntil == null ||
        retryUntil.isAfter(_catalogCooldownUntil!)) {
      _catalogCooldownUntil = retryUntil;
    }
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
          await clearCache(clearPersistent: true);
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

  /// Ghi nhận feedback cho gợi ý (Like/Dislike)
  static Future<bool> recordSuggestionFeedback({
    required String recipeName,
    required String feedback,
  }) async {
    try {
      final body = {
        'recipeName': recipeName,
        'feedback': feedback,
      };
      final resp = await ApiService.post(
        '/api/v1/recipes/suggestion-feedback',
        body,
        withAuth: true,
      );
      return resp.statusCode == 200;
    } catch (e) {
      debugPrint('PantryService.recordSuggestionFeedback error: $e');
      return false;
    }
  }
}
