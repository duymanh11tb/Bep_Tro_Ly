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
    String? dietaryPreference,
  }) async {
    return _suggestByIngredients(
      const [],
      limit: limit,
      dietaryPreference: dietaryPreference,
    );
  }

  static Future<List<RecipeSuggestion>> getSuggestionsByIngredients(
    List<String> ingredients, {
    int limit = 8,
    String? dietaryPreference,
  }) async {
    final filtered = ingredients
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    return _suggestByIngredients(
      filtered,
      limit: limit,
      dietaryPreference: dietaryPreference,
    );
  }

  static Future<List<RecipeSuggestion>> _suggestByIngredients(
    List<String> ingredients, {
    required int limit,
    String? dietaryPreference,
  }) async {
    try {
      final preferences = await _buildPreferences(dietaryPreference);
      final resp = await ApiService.post('/api/v1/recipes/suggest', {
        'ingredients': ingredients,
        'limit': limit,
        if (preferences.isNotEmpty) 'preferences': preferences,
      }, withAuth: true);

      if (resp.statusCode != 200) {
        return _buildLocalFallbackRecipes(
          ingredients,
          limit: limit,
          dietaryPreference: dietaryPreference,
        );
      }

      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data['success'] != true || data['recipes'] == null) {
        return _buildLocalFallbackRecipes(
          ingredients,
          limit: limit,
          dietaryPreference: dietaryPreference,
        );
      }

      final list = data['recipes'] as List;
      final parsed = list.map((e) => RecipeSuggestion.fromJson(e)).toList();
      if (parsed.isEmpty) {
        return _buildLocalFallbackRecipes(
          ingredients,
          limit: limit,
          dietaryPreference: dietaryPreference,
        );
      }
      return parsed;
    } catch (e) {
      debugPrint('MealPlanService._suggestByIngredients error: $e');
      return _buildLocalFallbackRecipes(
        ingredients,
        limit: limit,
        dietaryPreference: dietaryPreference,
      );
    }
  }

  static List<RecipeSuggestion> _buildLocalFallbackRecipes(
    List<String> ingredients, {
    required int limit,
    String? dietaryPreference,
  }) {
    final normalized = ingredients
        .map((e) => e.trim().toLowerCase())
        .where((e) => e.isNotEmpty)
        .toSet();

    final candidates = _fallbackCandidatesForDietary(dietaryPreference);

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

  static List<Map<String, dynamic>> _fallbackCandidatesForDietary(
    String? dietaryPreference,
  ) {
    final normalized = dietaryPreference?.trim().toLowerCase();
    if (normalized == 'vegetarian') {
      return <Map<String, dynamic>>[
        {
          'name': 'Đậu hũ hấp nấm',
          'description': 'Món chay thanh nhẹ, mềm và rất dễ ăn.',
          'difficulty': 'easy',
          'prep_time': 8,
          'cook_time': 12,
          'ingredients': ['đậu hũ', 'nấm', 'hành boa rô'],
          'instructions': [
            'Cắt đậu hũ vừa ăn, nấm rửa sạch.',
            'Xếp đậu hũ và nấm vào đĩa sâu lòng.',
            'Hấp chín rồi rắc boa rô phi lên trên.',
          ],
          'tips': 'Thêm ít nước tương nhạt để món đậm đà hơn.',
        },
        {
          'name': 'Canh bí đỏ rau củ',
          'description': 'Canh ngọt tự nhiên, hợp bữa tối nhẹ bụng.',
          'difficulty': 'easy',
          'prep_time': 10,
          'cook_time': 15,
          'ingredients': ['bí đỏ', 'cà rốt', 'nấm'],
          'instructions': [
            'Sơ chế rau củ thành miếng vừa ăn.',
            'Nấu bí đỏ và cà rốt đến khi mềm.',
            'Thêm nấm vào sau cùng và nêm nhạt.',
          ],
          'tips': 'Giữ vị ngọt rau củ bằng cách không nêm quá tay.',
        },
      ];
    }

    if (normalized == 'weight_loss') {
      return <Map<String, dynamic>>[
        {
          'name': 'Ức gà áp chảo salad',
          'description': 'Giàu đạm, ít dầu và hợp chế độ giảm cân.',
          'difficulty': 'easy',
          'prep_time': 8,
          'cook_time': 12,
          'ingredients': ['ức gà', 'xà lách', 'cà chua'],
          'instructions': [
            'Ướp ức gà nhẹ với muối tiêu.',
            'Áp chảo gà đến khi chín vàng hai mặt.',
            'Ăn cùng salad rau tươi và cà chua.',
          ],
          'tips': 'Dùng chảo chống dính để giảm lượng dầu.',
        },
        {
          'name': 'Canh nấm rau cải',
          'description': 'Thanh nhẹ, ít calo và làm nhanh trong ngày bận.',
          'difficulty': 'easy',
          'prep_time': 6,
          'cook_time': 10,
          'ingredients': ['nấm', 'rau cải', 'gừng'],
          'instructions': [
            'Nấu nước với vài lát gừng.',
            'Cho nấm vào trước rồi đến rau cải.',
            'Nêm nhạt và tắt bếp khi rau vừa chín.',
          ],
          'tips': 'Canh này rất hợp cho bữa tối nhẹ.',
        },
      ];
    }

    if (normalized == 'eat_clean') {
      return <Map<String, dynamic>>[
        {
          'name': 'Cơm gạo lứt bò xào rau',
          'description': 'Bữa trưa Eat Clean đủ chất và no lâu.',
          'difficulty': 'medium',
          'prep_time': 10,
          'cook_time': 18,
          'ingredients': ['gạo lứt', 'thịt bò', 'bông cải'],
          'instructions': [
            'Nấu gạo lứt trước khi chuẩn bị món.',
            'Xào bò nhanh với rau trên lửa lớn.',
            'Dùng cùng gạo lứt để cân bằng dinh dưỡng.',
          ],
          'tips': 'Không xào bò quá lâu để giữ độ mềm.',
        },
        {
          'name': 'Cá hấp rau củ',
          'description': 'Ít dầu mỡ, giữ vị tự nhiên và rất dễ tiêu.',
          'difficulty': 'easy',
          'prep_time': 8,
          'cook_time': 15,
          'ingredients': ['cá', 'cà rốt', 'bí ngòi'],
          'instructions': [
            'Sơ chế cá và rau củ.',
            'Xếp lên xửng hấp và hấp chín.',
            'Rưới chút nước tương nhạt trước khi ăn.',
          ],
          'tips': 'Có thể thêm gừng để khử mùi tanh và tăng hương vị.',
        },
      ];
    }

    return <Map<String, dynamic>>[
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
  }

  static Future<Map<String, dynamic>> _buildPreferences(
    String? dietaryPreference,
  ) async {
    final prefs = <String, dynamic>{};
    final normalized = dietaryPreference?.trim().toLowerCase();
    if (normalized == 'vegetarian') {
      prefs['dietary_restrictions'] = 'Ăn chay';
      prefs['cuisine'] = 'Món chay Việt Nam';
      return prefs;
    }
    if (normalized == 'weight_loss') {
      prefs['dietary_restrictions'] = 'Giảm cân';
      prefs['difficulty'] = 'easy';
      prefs['cuisine'] = 'Món Việt ít dầu mỡ';
      return prefs;
    }
    if (normalized == 'eat_clean') {
      prefs['dietary_restrictions'] = 'Eat Clean';
      prefs['difficulty'] = 'easy';
      prefs['cuisine'] = 'Món Việt Eat Clean';
      return prefs;
    }

    final authService = AuthService();
    final user = await authService.getUser();
    final dietary = user?['dietary_restrictions']?.toString();
    if (dietary != null && dietary.isNotEmpty) {
      prefs['dietary_restrictions'] = dietary;
    }
    return prefs;
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
        '/api/v1/meal-plan/current',
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
      await ApiService.put('/api/v1/meal-plan/current', {
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
