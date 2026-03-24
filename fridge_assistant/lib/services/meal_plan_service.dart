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
    String? refreshToken,
  }) async {
    return _suggestByIngredients(
      const [],
      limit: limit,
      dietaryPreference: dietaryPreference,
      refreshToken: refreshToken,
    );
  }

  static Future<List<RecipeSuggestion>> getSuggestionsByIngredients(
    List<String> ingredients, {
    int limit = 8,
    String? dietaryPreference,
    String? refreshToken,
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
      refreshToken: refreshToken,
    );
  }

  static Future<List<RecipeSuggestion>> _suggestByIngredients(
    List<String> ingredients, {
    required int limit,
    String? dietaryPreference,
    String? refreshToken,
  }) async {
    try {
      final preferences = await _buildPreferences(dietaryPreference);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        preferences['refresh_token'] = refreshToken;
      }
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
          refreshToken: refreshToken,
        );
      }

      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data['success'] != true || data['recipes'] == null) {
        return _buildLocalFallbackRecipes(
          ingredients,
          limit: limit,
          dietaryPreference: dietaryPreference,
          refreshToken: refreshToken,
        );
      }

      final list = data['recipes'] as List;
      final parsed = list.map((e) => RecipeSuggestion.fromJson(e)).toList();
      if (parsed.isEmpty) {
        return _buildLocalFallbackRecipes(
          ingredients,
          limit: limit,
          dietaryPreference: dietaryPreference,
          refreshToken: refreshToken,
        );
      }
      return parsed;
    } catch (e) {
      debugPrint('MealPlanService._suggestByIngredients error: $e');
      return _buildLocalFallbackRecipes(
        ingredients,
        limit: limit,
        dietaryPreference: dietaryPreference,
        refreshToken: refreshToken,
      );
    }
  }

  static List<RecipeSuggestion> _buildLocalFallbackRecipes(
    List<String> ingredients, {
    required int limit,
    String? dietaryPreference,
    String? refreshToken,
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
        }).toList();

    ranked.sort((a, b) {
      final scoreCompare = (b['match_score'] as double).compareTo(
        a['match_score'] as double,
      );
      if (scoreCompare != 0) return scoreCompare;
      return (a['name'] as String).compareTo(b['name'] as String);
    });

    _shuffleRankedRecipes(
      ranked,
      ingredients: normalized.toList(),
      dietaryPreference: dietaryPreference,
      refreshToken: refreshToken,
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
        {
          'name': 'Bún chay nấm rau',
          'description': 'Tô bún thanh nhẹ, phù hợp ngày muốn ăn nhẹ bụng.',
          'difficulty': 'easy',
          'prep_time': 10,
          'cook_time': 15,
          'ingredients': ['bún', 'nấm', 'rau cải'],
          'instructions': [
            'Trụng bún và rau cải vừa chín.',
            'Nấu nước dùng nấm thanh nhẹ.',
            'Xếp bún, rau rồi chan nước dùng lên trên.',
          ],
          'tips': 'Thêm đậu hũ chiên để món đầy đặn hơn.',
        },
        {
          'name': 'Miến xào rau củ chay',
          'description': 'Nhanh gọn, ít dầu và rất hợp bữa sáng.',
          'difficulty': 'easy',
          'prep_time': 8,
          'cook_time': 10,
          'ingredients': ['miến', 'cà rốt', 'nấm', 'bắp cải'],
          'instructions': [
            'Ngâm miến cho mềm rồi để ráo.',
            'Xào rau củ và nấm trên lửa lớn.',
            'Cho miến vào đảo nhanh, nêm nhẹ rồi tắt bếp.',
          ],
          'tips': 'Không xào quá lâu để miến không bị dính.',
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
        {
          'name': 'Tôm hấp bí ngòi',
          'description': 'Giàu đạm, thanh nhẹ và rất ít dầu mỡ.',
          'difficulty': 'easy',
          'prep_time': 8,
          'cook_time': 10,
          'ingredients': ['tôm', 'bí ngòi', 'gừng'],
          'instructions': [
            'Sơ chế tôm và bí ngòi.',
            'Xếp vào xửng hấp cùng vài lát gừng.',
            'Hấp chín rồi dùng ngay khi còn nóng.',
          ],
          'tips': 'Có thể ăn kèm salad để đủ chất hơn.',
        },
        {
          'name': 'Salad ức gà dưa leo',
          'description': 'Bữa nhẹ nhanh gọn, phù hợp cho ngày cần kiểm soát calo.',
          'difficulty': 'easy',
          'prep_time': 10,
          'cook_time': 12,
          'ingredients': ['ức gà', 'dưa leo', 'xà lách'],
          'instructions': [
            'Luộc hoặc áp chảo ức gà đến khi chín.',
            'Cắt dưa leo và rau vừa ăn.',
            'Trộn nhẹ với sốt chanh dầu oliu.',
          ],
          'tips': 'Ưu tiên sốt nhạt để giữ đúng mục tiêu giảm cân.',
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
        {
          'name': 'Yến mạch trái cây sữa chua',
          'description': 'Bữa sáng Eat Clean nhẹ bụng và giàu chất xơ.',
          'difficulty': 'easy',
          'prep_time': 6,
          'cook_time': 4,
          'ingredients': ['yến mạch', 'sữa chua', 'chuối'],
          'instructions': [
            'Ngâm hoặc nấu yến mạch cho mềm.',
            'Thêm sữa chua và trái cây cắt nhỏ.',
            'Dùng ngay cho bữa sáng nhanh gọn.',
          ],
          'tips': 'Có thể rắc thêm hạt chia để tăng độ no lâu.',
        },
        {
          'name': 'Gà áp chảo khoai lang',
          'description': 'Cân bằng tinh bột tốt và đạm nạc cho bữa trưa.',
          'difficulty': 'easy',
          'prep_time': 10,
          'cook_time': 18,
          'ingredients': ['ức gà', 'khoai lang', 'rau xà lách'],
          'instructions': [
            'Luộc hoặc nướng khoai lang đến khi chín.',
            'Áp chảo ức gà với ít gia vị.',
            'Ăn cùng rau xà lách và khoai lang.',
          ],
          'tips': 'Nên áp chảo ít dầu để giữ đúng tinh thần Eat Clean.',
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
        'name': 'Cơm chiên rau củ trứng',
        'description': 'Dễ làm, tận dụng cơm nguội và hợp bữa nhanh.',
        'difficulty': 'easy',
        'prep_time': 8,
        'cook_time': 10,
        'ingredients': ['cơm nguội', 'trứng', 'cà rốt', 'đậu que'],
        'instructions': [
          'Đánh trứng rồi xào sơ với rau củ.',
          'Cho cơm vào đảo đều trên lửa lớn.',
          'Nêm vừa ăn rồi dùng nóng.',
        ],
        'tips': 'Dùng cơm nguội sẽ giúp hạt cơm tơi hơn.',
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
        'name': 'Canh cải thịt bằm',
        'description': 'Thanh nhẹ, nấu nhanh và rất hợp bữa tối gia đình.',
        'difficulty': 'easy',
        'prep_time': 7,
        'cook_time': 12,
        'ingredients': ['rau cải', 'thịt bằm', 'gừng'],
        'instructions': [
          'Ướp nhẹ thịt bằm rồi vo nhỏ.',
          'Đun sôi nước, cho thịt vào trước.',
          'Thêm rau cải, nêm vừa rồi tắt bếp.',
        ],
        'tips': 'Nấu rau vừa chín để giữ màu xanh đẹp.',
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
      {
        'name': 'Gà xào sả ớt',
        'description': 'Đậm đà, thơm mùi sả và rất đưa cơm.',
        'difficulty': 'medium',
        'prep_time': 10,
        'cook_time': 15,
        'ingredients': ['thịt gà', 'sả', 'ớt', 'hành tím'],
        'instructions': [
          'Ướp gà với sả băm và gia vị.',
          'Phi thơm hành rồi xào gà trên lửa lớn.',
          'Đảo đến khi thịt chín săn và thơm.',
        ],
        'tips': 'Có thể giảm ớt nếu muốn vị dịu hơn.',
      },
      {
        'name': 'Đậu hũ sốt cà chua',
        'description': 'Món quen thuộc, nhẹ bụng mà vẫn đậm vị.',
        'difficulty': 'easy',
        'prep_time': 8,
        'cook_time': 12,
        'ingredients': ['đậu hũ', 'cà chua', 'hành lá'],
        'instructions': [
          'Chiên sơ đậu hũ cho vàng mặt.',
          'Nấu sốt cà chua rồi cho đậu vào rim nhẹ.',
          'Rắc hành lá trước khi tắt bếp.',
        ],
        'tips': 'Nếu thích mềm hơn, không cần chiên đậu quá lâu.',
      },
      {
        'name': 'Bò xào bông cải',
        'description': 'Món xào nhanh, giàu đạm và dễ ăn.',
        'difficulty': 'easy',
        'prep_time': 10,
        'cook_time': 12,
        'ingredients': ['thịt bò', 'bông cải', 'tỏi'],
        'instructions': [
          'Ướp bò nhẹ với tiêu và tỏi.',
          'Trụng bông cải sơ để giữ độ giòn.',
          'Xào bò nhanh rồi cho bông cải vào đảo đều.',
        ],
        'tips': 'Không xào bò quá chín để giữ độ mềm.',
      },
      {
        'name': 'Cá sốt cà chua',
        'description': 'Món mặn dễ ăn, hợp cơm gia đình hằng ngày.',
        'difficulty': 'medium',
        'prep_time': 12,
        'cook_time': 18,
        'ingredients': ['cá', 'cà chua', 'hành tím'],
        'instructions': [
          'Chiên sơ cá cho săn mặt.',
          'Làm sốt cà chua riêng đến khi sệt.',
          'Cho cá vào om nhẹ để thấm sốt.',
        ],
        'tips': 'Dùng ít đường để sốt dịu và tròn vị hơn.',
      },
    ];
  }

  static void _shuffleRankedRecipes(
    List<Map<String, dynamic>> ranked, {
    required List<String> ingredients,
    String? dietaryPreference,
    String? refreshToken,
  }) {
    final sortedIngredients = [...ingredients]..sort();
    final seedSource = [
      refreshToken ?? DateTime.now().millisecondsSinceEpoch.toString(),
      dietaryPreference ?? '',
      ...sortedIngredients,
    ].join('|');

    ranked.sort((a, b) {
      final aScore = a['match_score'] as double;
      final bScore = b['match_score'] as double;
      final scoreDiff = (bScore - aScore).abs();
      if (scoreDiff > 0.08) {
        return bScore.compareTo(aScore);
      }

      final aKey = '${a['name']}|$seedSource'.hashCode;
      final bKey = '${b['name']}|$seedSource'.hashCode;
      return aKey.compareTo(bKey);
    });
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
