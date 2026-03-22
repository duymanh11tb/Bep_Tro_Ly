import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fridge_model.dart';
import 'auth_service.dart';
import 'api_service.dart';

class FridgeService {
  final String _baseUrl = ApiService.baseUrl;
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _getHeaders() async {
    final token = await _authService.getToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<FridgeModel>> getFridges() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/fridges'),
        headers: await _getHeaders(),
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => FridgeModel.fromJson(item)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting fridges: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> createFridge(String name, String? location) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/fridges'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'name': name,
          'location': location,
        }),
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body);
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
      final response = await http.put(
        Uri.parse('$_baseUrl/api/v1/fridges/$id'),
        headers: await _getHeaders(),
        body: jsonEncode({
          'name': name,
          'location': location,
          if (status != null) 'status': status,
        }),
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body);
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
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/v1/fridges/$id'),
        headers: await _getHeaders(),
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body);
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
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/fridges/$fridgeId/members'),
        headers: await _getHeaders(),
        body: jsonEncode({'identifier': identifier}),
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body);
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
      final response = await http.delete(
        Uri.parse('$_baseUrl/api/v1/fridges/$fridgeId/members/$userId'),
        headers: await _getHeaders(),
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body);
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
      final response = await http.post(
        Uri.parse('$_baseUrl/api/v1/fridges/$fridgeId/members/accept'),
        headers: await _getHeaders(),
        body: jsonEncode({}),
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
      final response = await http.get(
        Uri.parse('$_baseUrl/api/v1/auth/search?query=$query'),
        headers: await _getHeaders(),
      );

      Map<String, dynamic> data = {};
      if (response.body.isNotEmpty) {
        try {
          data = jsonDecode(response.body);
        } catch (_) {}
      }

      if (response.statusCode == 200) {
        final user = Map<String, dynamic>.from(data['user'] ?? data);
        if (user.containsKey('photo_url') && user['photo_url'] != null) {
          String url = user['photo_url'];
          if (url.startsWith('/')) {
            user['photo_url'] = '$_baseUrl$url';
          }
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
