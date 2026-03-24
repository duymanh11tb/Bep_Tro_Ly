import 'dart:convert';
import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationService {
  Future<List<NotificationModel>> getNotifications() async {
    try {
      final response = await ApiService.get(
        '/api/v1/notifications',
        withAuth: true,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((n) => NotificationModel.fromJson(n)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> markAsRead(int id) async {
    try {
      final response = await ApiService.put(
        '/api/v1/notifications/$id/read',
        const {},
        withAuth: true,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> respondToInvitation(int notificationId, bool accept) async {
    try {
      final response = await ApiService.post(
        '/api/v1/notifications/$notificationId/respond',
        {'accept': accept},
        withAuth: true,
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));
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
