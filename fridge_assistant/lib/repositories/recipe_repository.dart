import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/recipe_suggestion.dart';

class RecipeRepository {
  /// Lấy gợi ý món ăn từ Gemini
  static Future<List<RecipeSuggestion>> getSuggestions({
    required List<String> ingredients,
    List<String>? expiringIngredients,
    int limit = 5,
  }) async {
    try {
      if (ingredients.isEmpty) {
        return [];
      }

      // Gọi Gemini API qua ApiService
      final recipesData = await ApiService.suggestRecipesWithImages(
        availableIngredients: ingredients,
        expiringIngredients: expiringIngredients,
        numberOfRecipes: limit,
      );

      if (recipesData.isEmpty) {
        throw Exception('AI không trả về gợi ý hợp lệ');
      }
      
      // Convert sang RecipeSuggestion objects
      final suggestions = <RecipeSuggestion>[];
      for (var data in recipesData) {
        final recipe = RecipeSuggestion.fromGeminiData(data);
        
        // Cập nhật số lượng nguyên liệu sắp hết
        final updatedRecipe = recipe.copyWith(
          ingredientsExpiringCount: expiringIngredients != null
              ? RecipeSuggestion.countExpiringIngredients(
                  recipe.ingredientsUsed,
                  expiringIngredients,
                )
              : 0,
        );
        
        suggestions.add(updatedRecipe);
      }
      
      // Sắp xếp theo độ phù hợp giảm dần
      suggestions.sort((a, b) => b.matchScore.compareTo(a.matchScore));
      
      return suggestions;
    } catch (e) {
      debugPrint('RecipeRepository error: $e');
      throw Exception('Không lấy được gợi ý món ăn lúc này. Vui lòng thử lại.');
    }
  }
  
  /// Cache gợi ý để dùng sau
  static Future<void> cacheSuggestions(
    List<RecipeSuggestion> suggestions,
    String cacheKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = suggestions.map((r) => jsonEncode(r.toJson())).toList();
    await prefs.setStringList(cacheKey, jsonList);
    await prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
  }
  
  /// Lấy gợi ý từ cache
  static Future<List<RecipeSuggestion>> getCachedSuggestions(
    String cacheKey, {
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    final timestampStr = prefs.getString('${cacheKey}_timestamp');
    if (timestampStr != null) {
      final timestamp = DateTime.parse(timestampStr);
      if (DateTime.now().difference(timestamp) > maxAge) {
        return [];
      }
    }
    
    final jsonList = prefs.getStringList(cacheKey);
    if (jsonList == null) return [];
    
    return jsonList
        .map((json) => RecipeSuggestion.fromJson(jsonDecode(json)))
        .toList();
  }
}
