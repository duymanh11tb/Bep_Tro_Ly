import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fridge_model.dart';
import 'api_service.dart';

class FridgeService {
  Future<List<FridgeModel>> getFridges() async {
    try {
      final response = await ApiService.get(
        '/api/v1/fridges',
        withAuth: true,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        return data.map((item) => FridgeModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> createFridge(String name, String? location) async {
    try {
      final response = await ApiService.post(
        '/api/v1/fridges',
        {
          'name': name,
          'location': location,
        },
        withAuth: true,
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {}
      }

      if (response.statusCode == 201) {
        return {'success': true, 'fridge': FridgeModel.fromJson(data)};
      }
      return {'success': false, 'message': data['error'] ?? 'Lỗi khi tạo tủ lạnh: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateFridge(int id, String name, String? location, {String? status}) async {
    try {
      final response = await ApiService.put(
        '/api/v1/fridges/$id',
        {
          'name': name,
          'location': location,
          if (status != null) 'status': status,
        },
        withAuth: true,
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        return {
          'success': true, 
          'message': data['message'] ?? 'Cập nhật thành công', 
          'fridge': FridgeModel.fromJson(data['fridge'] ?? data)
        };
      }
      return {'success': false, 'message': data['error'] ?? 'Lỗi khi cập nhật tủ lạnh: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteFridge(int id) async {
    try {
      final response = await ApiService.delete(
        '/api/v1/fridges/$id',
        withAuth: true,
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Đã xóa tủ lạnh'};
      }
      return {'success': false, 'message': data['error'] ?? 'Lỗi khi xóa tủ lạnh: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> inviteMember(int fridgeId, String identifier) async {
    try {
      final response = await ApiService.post(
        '/api/v1/fridges/$fridgeId/members',
        {'identifier': identifier},
        withAuth: true,
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Đã gửi lời mời thành công'};
      }
      return {'success': false, 'message': data['error'] ?? 'Lỗi khi mời thành viên: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> removeMember(int fridgeId, int userId) async {
    try {
      final response = await ApiService.delete(
        '/api/v1/fridges/$fridgeId/members/$userId',
        withAuth: true,
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message'] ?? 'Đã xóa thành viên'};
      }
      return {'success': false, 'message': data['error'] ?? 'Lỗi khi xóa thành viên: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> acceptInvitation(int fridgeId) async {
    try {
      final response = await ApiService.post(
        '/api/v1/fridges/$fridgeId/members/accept',
        const {},
        withAuth: true,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Active Fridge Management
  static const String _activeFridgeKey = 'active_fridge_id';

  static Future<void> setActiveFridge(int fridgeId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeFridgeKey, fridgeId);
  }

  static Future<int?> getActiveFridgeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_activeFridgeKey);
  }

  static Future<FridgeModel?> getActiveFridge() async {
    final fridgeId = await getActiveFridgeId();
    if (fridgeId == null) return null;

    final fridges = await FridgeService().getFridges();
    try {
      return fridges.firstWhere((f) => f.fridgeId == fridgeId);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> searchUser(String query) async {
    try {
      final encodedQuery = Uri.encodeQueryComponent(query);
      final response = await ApiService.get(
        '/api/v1/auth/search?query=$encodedQuery',
        withAuth: true,
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(utf8.decode(response.bodyBytes));
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        final user = Map<String, dynamic>.from(data['user'] ?? data);
        if (user.containsKey('photo_url') && user['photo_url'] != null) {
          String url = user['photo_url'];
          user['photo_url'] = ApiService.absoluteUrl(url);
        }
        return user;
      } else {
        throw data['error'] ?? 'Không tìm thấy người dùng (Mã: ${response.statusCode})';
      }
    } catch (e) {
      rethrow;
    }
  }
}
