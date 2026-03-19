import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/recipe_suggestion.dart';
import 'api_service.dart';
import 'auth_service.dart';

class MealPlanService {
  static const String _mealPlanCachePrefix = 'meal_plan_v1_';

  static Future<List<RecipeSuggestion>> getDiscoverySuggestions({
    int limit = 12,
  }) async {
    return _suggestByIngredients(const [], limit: limit);
  }

  static Future<List<RecipeSuggestion>> getSuggestionsByIngredients(
    List<String> ingredients, {
    int limit = 8,
  }) async {
    final filtered = ingredients
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    return _suggestByIngredients(filtered, limit: limit);
  }

  static Future<List<RecipeSuggestion>> _suggestByIngredients(
    List<String> ingredients, {
    required int limit,
  }) async {
    try {
      final resp = await ApiService.post('/api/recipes/suggest', {
        'ingredients': ingredients,
        'limit': limit,
      }, withAuth: true);

      if (resp.statusCode != 200) {
        return _buildLocalFallbackRecipes(ingredients, limit: limit);
      }

      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data['success'] != true || data['recipes'] == null) {
        return _buildLocalFallbackRecipes(ingredients, limit: limit);
      }

      final list = data['recipes'] as List;
      final parsed = list.map((e) => RecipeSuggestion.fromJson(e)).toList();
      if (parsed.isEmpty) {
        return _buildLocalFallbackRecipes(ingredients, limit: limit);
      }
      return parsed;
    } catch (e) {
      debugPrint('MealPlanService._suggestByIngredients error: $e');
      return _buildLocalFallbackRecipes(ingredients, limit: limit);
    }
  }

  static List<RecipeSuggestion> _buildLocalFallbackRecipes(
    List<String> ingredients, {
    required int limit,
  }) {
    final normalized = ingredients
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    final candidates = <Map<String, dynamic>>[
      {
        'name': 'Mì xào trứng',
        'description': 'Nhanh gọn cho bữa bận rộn, đậm vị và dễ làm.',
        'difficulty': 'easy',
        'prep_time': 5,
        'cook_time': 10,
        'ingredients': ['mì tôm', 'trứng', 'hành tím', 'dầu ăn'],
        'instructions': [
          'Luộc mì tôm sơ 1 phút rồi để ráo.',
          'Phi thơm hành tím, cho trứng vào đảo tơi.',
          'Cho mì vào xào nhanh, nêm nếm vừa ăn rồi tắt bếp.',
        ],
        'tips': 'Không luộc mì quá lâu để sợi mì không bị nát.',
      },
      {
        'name': 'Cà tím áp chảo sốt mắm',
        'description': 'Món dân dã ngon cơm, mềm thơm và bắt vị.',
        'difficulty': 'easy',
        'prep_time': 8,
        'cook_time': 12,
        'ingredients': ['cà tím', 'tỏi', 'nước mắm', 'đường', 'dầu ăn'],
        'instructions': [
          'Cà tím cắt khúc, ngâm muối loãng 5 phút rồi để ráo.',
          'Áp chảo cà tím với ít dầu đến khi mềm vàng.',
          'Làm sốt mắm tỏi, rưới vào chảo đảo đều cho thấm.',
        ],
        'tips': 'Ngâm cà tím trước khi nấu giúp giảm thâm và đỡ chát.',
      },
      {
        'name': 'Trứng chiên hành',
        'description': 'Món cơ bản nhưng luôn ngon, hợp mọi bữa.',
        'difficulty': 'easy',
        'prep_time': 4,
        'cook_time': 7,
        'ingredients': ['trứng', 'hành tím', 'nước mắm', 'tiêu'],
        'instructions': [
          'Đánh đều trứng với gia vị.',
          'Phi thơm hành tím.',
          'Đổ trứng vào chiên vàng đều hai mặt.',
        ],
        'tips': 'Chiên lửa vừa để trứng mềm và không bị khô.',
      },
      {
        'name': 'Mì nước trứng hành',
        'description': 'Ấm bụng, nấu nhanh trong 10 phút.',
        'difficulty': 'easy',
        'prep_time': 3,
        'cook_time': 8,
        'ingredients': ['mì tôm', 'trứng', 'hành tím'],
        'instructions': [
          'Đun sôi nước, cho mì vào nấu theo gói.',
          'Đập trứng vào nồi và đun thêm 1-2 phút.',
          'Thêm hành tím phi hoặc hành lá rồi thưởng thức.',
        ],
        'tips': 'Có thể thêm rau xanh để cân bằng dinh dưỡng.',
      },
    ];

    final ranked =
        candidates.map((item) {
          final ing = List<String>.from(
            item['ingredients'] as List,
          ).map((e) => e.toLowerCase()).toList();
          final used = ing
              .where(
                (i) => normalized.any((h) => h.contains(i) || i.contains(h)),
              )
              .toList();
          final missing = ing.where((i) => !used.contains(i)).toList();

          final score = normalized.isEmpty
              ? 0.45
              : (used.length / ing.length).clamp(0.35, 0.98);

          return {
            ...item,
            'ingredients_used': used,
            'ingredients_missing': missing,
            'match_score': score,
          };
        }).toList()..sort(
          (a, b) => (b['match_score'] as double).compareTo(
            a['match_score'] as double,
          ),
        );

    return ranked.take(limit).map((item) {
      return RecipeSuggestion.fromJson({
        'id': '${item['name']}_${DateTime.now().millisecondsSinceEpoch}',
        'name': item['name'],
        'description': item['description'],
        'image_url': null,
        'difficulty': item['difficulty'],
        'prep_time': item['prep_time'],
        'cook_time': item['cook_time'],
        'ingredients_used': item['ingredients_used'],
        'ingredients_missing': item['ingredients_missing'],
        'match_score': item['match_score'],
        'ingredients_expiring_count': 0,
        'instructions': item['instructions'],
        'tips': item['tips'],
      });
    }).toList();
  }

  static Future<Map<String, dynamic>> loadLocalPlan() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _mealPlanCacheKey();
      final raw = prefs.getString(key);
      if (raw == null || raw.isEmpty) return <String, dynamic>{};

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String, dynamic>{};
      return decoded;
    } catch (e) {
      debugPrint('MealPlanService.loadLocalPlan error: $e');
      return <String, dynamic>{};
    }
  }

  static Future<Map<String, dynamic>> loadPlan() async {
    final remote = await _loadRemotePlan();
    if (remote.isNotEmpty) {
      await saveLocalPlan(remote);
      return remote;
    }

    return loadLocalPlan();
  }

  static Future<void> saveLocalPlan(Map<String, dynamic> plan) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _mealPlanCacheKey();
      await prefs.setString(key, jsonEncode(plan));
    } catch (e) {
      debugPrint('MealPlanService.saveLocalPlan error: $e');
    }
  }

  static Future<void> savePlan(Map<String, dynamic> plan) async {
    await saveLocalPlan(plan);
    await _saveRemotePlan(plan);
  }

  static Future<Map<String, dynamic>> _loadRemotePlan() async {
    try {
      final resp = await ApiService.get(
        '/api/meal-plan/current',
        withAuth: true,
      );
      if (resp.statusCode != 200) return <String, dynamic>{};

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is! Map<String, dynamic>) return <String, dynamic>{};

      final dynamic planData = decoded['plan_data'];
      if (planData is Map<String, dynamic>) return planData;

      if (planData is Map) {
        return Map<String, dynamic>.from(planData);
      }

      return <String, dynamic>{};
    } catch (e) {
      debugPrint('MealPlanService._loadRemotePlan error: $e');
      return <String, dynamic>{};
    }
  }

  static Future<void> _saveRemotePlan(Map<String, dynamic> plan) async {
    try {
      await ApiService.put('/api/meal-plan/current', {
        'plan_data': plan,
      }, withAuth: true);
    } catch (e) {
      debugPrint('MealPlanService._saveRemotePlan error: $e');
    }
  }

  static Future<String> _mealPlanCacheKey() async {
    final authService = AuthService();
    final user = await authService.getUser();

    final raw =
        user?['id']?.toString() ??
        user?['email']?.toString() ??
        user?['display_name']?.toString() ??
        'guest';

    final safeSuffix = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9@._-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return '$_mealPlanCachePrefix$safeSuffix';
  }
}
