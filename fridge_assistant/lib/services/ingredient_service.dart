import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ingredient.dart';
import 'api_service.dart';

class IngredientService {
  static const String _cacheKey = 'ingredients';
  
  Future<List<Ingredient>> getIngredients() async {
    try {
      // Thử lấy từ API backend trước
      final response = await ApiService.get(
        '/api/ingredients',
        withAuth: true,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final List<dynamic> ingredientsJson = data is List ? data : (data['ingredients'] ?? []);
        final ingredients = ingredientsJson
            .map((json) => Ingredient.fromJson(json))
            .toList();
        
        // Cache lại
        await _cacheIngredients(ingredients);
        
        return ingredients;
      }
      
      // Fallback: lấy từ cache
      return await _getCachedIngredients();
    } catch (e) {
      debugPrint('Get ingredients error: $e');
      // Fallback: lấy từ cache
      return await _getCachedIngredients();
    }
  }
  
  Future<void> addIngredient(Ingredient ingredient) async {
    try {
      final response = await ApiService.post(
        '/api/ingredients',
        ingredient.toJson(),
        withAuth: true,
      );
      
      if (response.statusCode != 201 && response.statusCode != 200) {
        throw Exception('Failed to add ingredient');
      }
      
      // Clear cache
      await _clearCache();
    } catch (e) {
      debugPrint('Add ingredient error: $e');
      rethrow;
    }
  }
  
  Future<void> updateIngredient(Ingredient ingredient) async {
    try {
      final response = await ApiService.put(
        '/api/ingredients/${ingredient.id}',
        ingredient.toJson(),
        withAuth: true,
      );
      
      if (response.statusCode != 200) {
        throw Exception('Failed to update ingredient');
      }
      
      await _clearCache();
    } catch (e) {
      debugPrint('Update ingredient error: $e');
      rethrow;
    }
  }
  
  Future<void> deleteIngredient(String id) async {
    try {
      final response = await ApiService.delete(
        '/api/ingredients/$id',
        withAuth: true,
      );
      
      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception('Failed to delete ingredient');
      }
      
      await _clearCache();
    } catch (e) {
      debugPrint('Delete ingredient error: $e');
      rethrow;
    }
  }
  
  Future<void> _cacheIngredients(List<Ingredient> ingredients) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = ingredients.map((i) => jsonEncode(i.toJson())).toList();
    await prefs.setStringList(_cacheKey, jsonList);
    await prefs.setString('${_cacheKey}_timestamp', DateTime.now().toIso8601String());
  }
  
  Future<List<Ingredient>> _getCachedIngredients() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_cacheKey);
    
    if (jsonList == null) return [];
    
    return jsonList
        .map((json) => Ingredient.fromJson(jsonDecode(json)))
        .toList();
  }
  
  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    await prefs.remove('${_cacheKey}_timestamp');
  }
}
