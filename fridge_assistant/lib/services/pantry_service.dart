import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'category': category,
      'category_id': categoryId,
      'location': location,
      'expiry_date': expiryDate?.toIso8601String(),
      'image_url': imageUrl,
      'status': status,
    };
  }

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

  Map<String, dynamic> toJson() {
    return {
      'total_items': totalItems,
      'expiring_soon': expiringSoon,
      'by_category': byCategory.map((e) => e.toJson()).toList(),
    };
  }

  factory PantryStats.fromJson(Map<String, dynamic> json) {
    final cats = (json['by_category'] as List? ?? [])
        .map((c) => CategoryStat.fromJson(c))
        .toList();
    return PantryStats(
      totalItems: json['total_items'] ?? 0,
      expiring_soon: json['expiring_soon'] ?? 0,
      byCategory: cats,
    );
  }
}

class CategoryStat {
  final String category;
  final int count;

  CategoryStat({required this.category, required this.count});

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'count': count,
    };
  }

  factory CategoryStat.fromJson(Map<String, dynamic> json) {
    return CategoryStat(
      category: json['category'] ?? 'Khác',
      count: json['count'] ?? 0,
    );
  }
}

class PantryService {
  static const String _statsKey = 'cached_pantry_stats';
  static const String _expiringItemsKey = 'cached_expiring_items';
  static const String _suggestionsKey = 'cached_ai_suggestions';

  /// Lấy tất cả sản phẩm active
  static Future<List<PantryItem>> getItems() async {
    try {
      final resp = await ApiService.get('/api/pantry?status=active', withAuth: true);
      if (resp.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(resp.bodyBytes));
        return list.map((e) => PantryItem.fromJson(e)).toList();
      }
    } catch (e) {
      print('PantryService.getItems error: $e');
    }
    return [];
  }

  /// Lấy sản phẩm sắp hết hạn
  static Future<List<PantryItem>> getExpiringItems({int days = 7}) async {
    // Return cache first if needed by the UI, but here we always fetch to refresh
    try {
      final resp = await ApiService.get('/api/pantry/expiring?days=$days', withAuth: true);
      if (resp.statusCode == 200) {
        final List list = jsonDecode(utf8.decode(resp.bodyBytes));
        final items = list.map((e) => PantryItem.fromJson(e)).toList();
        
        // Save to cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_expiringItemsKey, jsonEncode(list));
        
        return items;
      }
    } catch (e) {
      print('PantryService.getExpiringItems error: $e');
    }
    return getCachedExpiringItems();
  }

  static Future<List<PantryItem>> getCachedExpiringItems() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_expiringItemsKey);
      if (data != null) {
        final List list = jsonDecode(data);
        return list.map((e) => PantryItem.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Lấy stats cho dashboard
  static Future<PantryStats?> getStats() async {
    try {
      final resp = await ApiService.get('/api/pantry/stats', withAuth: true);
      if (resp.statusCode == 200) {
        final json = jsonDecode(utf8.decode(resp.bodyBytes));
        final stats = PantryStats.fromJson(json);
        
        // Save to cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_statsKey, jsonEncode(json));
        
        return stats;
      }
    } catch (e) {
      print('PantryService.getStats error: $e');
    }
    return getCachedStats();
  }

  static Future<PantryStats?> getCachedStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_statsKey);
      if (data != null) {
        return PantryStats.fromJson(jsonDecode(data));
      }
    } catch (_) {}
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
        if (expiryDate != null) 'expiry_date': expiryDate.toIso8601String().split('T').first,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'add_method': 'manual',
      };
      final resp = await ApiService.post('/api/pantry', body, withAuth: true);
      return resp.statusCode == 200;
    } catch (e) {
      print('PantryService.addItem error: $e');
      return false;
    }
  }

  /// Xóa sản phẩm (soft delete)
  static Future<bool> deleteItem(int id) async {
    try {
      final resp = await ApiService.delete('/api/pantry/$id');
      return resp.statusCode == 200;
    } catch (e) {
      print('PantryService.deleteItem error: $e');
      return false;
    }
  }

  /// Lấy gợi ý món ăn từ AI
  static Future<List<RecipeSuggestion>> getAiSuggestions({int limit = 10}) async {
    try {
      final resp = await ApiService.post('/api/recipes/suggest-from-pantry', 
        {'limit': limit}, withAuth: true);
      if (resp.statusCode == 200) {
        final data = jsonDecode(utf8.decode(resp.bodyBytes));
        if (data['success'] == true && data['recipes'] != null) {
          final List list = data['recipes'];
          
          // Save to cache
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_suggestionsKey, jsonEncode(list));
          
          return list.map((e) => RecipeSuggestion.fromJson(e)).toList();
        }
      }
    } catch (e) {
      print('PantryService.getAiSuggestions error: $e');
    }
    return getCachedAiSuggestions();
  }

  static Future<List<RecipeSuggestion>> getCachedAiSuggestions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_suggestionsKey);
      if (data != null) {
        final List list = jsonDecode(data);
        return list.map((e) => RecipeSuggestion.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Xóa toàn bộ cache khi đăng xuất
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_statsKey);
    await prefs.remove(_expiringItemsKey);
    await prefs.remove(_suggestionsKey);
  }
}
