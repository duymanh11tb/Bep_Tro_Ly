import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/activity_log_model.dart';
import 'auth_service.dart';
import 'api_service.dart';

class ActivityLogService {
  final String _baseUrl = '${ApiService.baseUrl}/api/v1';

  Future<List<ActivityLogModel>> getFridgeActivities(int fridgeId, {String type = 'all'}) async {
    final token = await AuthService().getToken();
    final response = await http.get(
      Uri.parse('$_baseUrl/activity?fridgeId=$fridgeId&type=$type'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      List<dynamic> data = jsonDecode(response.body);
      return data.map((item) => ActivityLogModel.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load activity logs');
    }
  }

  static Future<void> logCooking(int? fridgeId, String recipeName, {int? recipeId}) async {
    final baseUrl = '${ApiService.baseUrl}/api/v1';
    final token = await AuthService().getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/recipes/cook'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'fridgeId': fridgeId,
        'recipeId': recipeId,
        'recipeName': recipeName,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to log cooking activity');
    }
  }
}
