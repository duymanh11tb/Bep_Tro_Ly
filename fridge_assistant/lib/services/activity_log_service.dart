import 'dart:convert';
import '../models/activity_log_model.dart';
import 'api_service.dart';

class ActivityLogService {
  Future<List<ActivityLogModel>> getFridgeActivities(int fridgeId, {String type = 'all'}) async {
    final response = await ApiService.get(
      '/api/v1/activity?fridgeId=$fridgeId&type=$type',
      withAuth: true,
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
      return data.map((item) => ActivityLogModel.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load activity logs');
    }
  }

  static Future<void> logCooking(int? fridgeId, String recipeName, {int? recipeId}) async {
    final response = await ApiService.post(
      '/api/v1/recipes/cook',
      {
        'fridgeId': fridgeId,
        'recipeId': recipeId,
        'recipeName': recipeName,
      },
      withAuth: true,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to log cooking activity');
    }
  }
}
