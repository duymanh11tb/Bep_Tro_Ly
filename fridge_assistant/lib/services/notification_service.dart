import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationService {
  final String _baseUrl = ApiService.baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<NotificationModel>> getNotifications() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/notifications'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((n) => NotificationModel.fromJson(n)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> markAsRead(int id) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/v1/notifications/$id/read'),
        headers: await _getHeaders(),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> respondToInvitation(int notificationId, bool accept) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/notifications/$notificationId/respond'),
        headers: await _getHeaders(),
        body: jsonEncode({'accept': accept}),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['error'] ?? 'Lỗi khi phản hồi lời mời'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  static Future<int> getUnreadCount() async {
    // This is a helper for the badge
    try {
      final service = NotificationService();
      final notifications = await service.getNotifications();
      return notifications.where((n) => !n.isRead).length;
    } catch (e) {
      return 0;
    }
  }
}
