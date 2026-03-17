import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'auth_service.dart';
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

  static Future<String> _getAiSuggestionsCacheKey() async {
    final suffix = await _getUserCacheSuffix();
    return '$_aiSuggestionsCachePrefix$suffix';
  }

  static Future<void> _persistAiSuggestions(
    List<RecipeSuggestion> suggestions,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = await _getAiSuggestionsCacheKey();
      final payload = jsonEncode(suggestions.map((e) => e.toJson()).toList());
      await prefs.setString(cacheKey, payload);
    } catch (e) {
      debugPrint('PantryService._persistAiSuggestions error: $e');
    }
  }

  static Future<List<RecipeSuggestion>> _loadPersistedAiSuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = await _getAiSuggestionsCacheKey();
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

  static Future<List<RecipeSuggestion>> getCachedAiSuggestions() async {
    if (_cachedAiSuggestions.isNotEmpty) {
      return _cachedAiSuggestions;
    }

    final persisted = await _loadPersistedAiSuggestions();
    if (persisted.isNotEmpty) {
      _cachedAiSuggestions = persisted;
    }

    return _cachedAiSuggestions;
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

  /// Lấy gợi ý món ăn từ AI
  static Future<List<RecipeSuggestion>> getAiSuggestions({
    int limit = 15,
  }) async {
    try {
      final resp = await ApiService.post('/api/recipes/suggest-from-pantry', {
        'limit': limit,
      }, withAuth: true);
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        if (data['success'] == true && data['recipes'] != null) {
          final List list = data['recipes'];
          final suggestions = list
              .map((e) => RecipeSuggestion.fromJson(e))
              .toList();
          _cachedAiSuggestions = suggestions;
          await _persistAiSuggestions(suggestions);
          return suggestions;
        }
      }
    } catch (e) {
      debugPrint('PantryService.getAiSuggestions error: $e');
    }
    return getCachedAiSuggestions();
  }
}
