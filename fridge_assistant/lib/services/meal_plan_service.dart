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

      if (resp.statusCode != 200) return [];

      final data = jsonDecode(utf8.decode(resp.bodyBytes));
      if (data['success'] != true || data['recipes'] == null) return [];

      final list = data['recipes'] as List;
      return list.map((e) => RecipeSuggestion.fromJson(e)).toList();
    } catch (e) {
      debugPrint('MealPlanService._suggestByIngredients error: $e');
      return [];
    }
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
