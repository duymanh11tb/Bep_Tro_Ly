import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await ApiService.post('/api/v1/auth/login', {
        'email': email,
        'password': password,
      });

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = data['token'];
        final user = data['user'];

        await _saveAuthData(token, user);
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Login failed'};
      }
    } catch (e) {
      debugPrint('AuthService: login error: $e');
      return {
        'success': false,
        'message': 'Không kết nối được tới máy chủ. Hãy kiểm tra API_URL hoặc trạng thái server.',
      };
    }
  }

  Future<Map<String, dynamic>> register(
    String email,
    String password, {
    String? displayName,
  }) async {
    try {
      final response = await ApiService.post('/api/v1/auth/register', {
        'email': email,
        'password': password,
        'display_name': displayName ?? email.split('@')[0],
      });

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        final token = data['token'];
        final user = data['user'];

        await _saveAuthData(token, user);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Registration failed',
        };
      }
    } catch (e) {
      debugPrint('AuthService: register error: $e');
      return {
        'success': false,
        'message': 'Không kết nối được tới máy chủ. Hãy kiểm tra API_URL hoặc trạng thái server.',
      };
    }
  }

  Future<void> loginWithToken(String token, Map<String, dynamic> user) async {
    await _saveAuthData(token, user);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userKey);
  }

  Future<void> _saveAuthData(String token, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_userKey, jsonEncode(user));
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tokenKey);
  }

  Future<bool> validateSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      return false;
    }

    try {
      final response = await ApiService.get('/api/v1/auth/me', withAuth: true);
      if (response.statusCode == 200) {
        return true;
      }

      if (response.statusCode == 401 || response.statusCode == 403) {
        await logout();
        return false;
      }

      // Với lỗi server/network tạm thời, giữ trạng thái đăng nhập để người dùng thử lại.
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<Map<String, dynamic>?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString(_userKey);
    if (userStr != null) {
      return jsonDecode(userStr);
    }
    return null;
  }

  Future<Map<String, dynamic>?> refreshCurrentUser() async {
    try {
      final response = await ApiService.get('/api/v1/auth/me', withAuth: true);
      if (response.statusCode != 200 || response.body.isEmpty) {
        return getUser();
      }

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      final existingUser = await getUser() ?? <String, dynamic>{};
      final refreshedUser = Map<String, dynamic>.from(
        responseData['user'] ?? responseData,
      );
      final mergedUser = <String, dynamic>{
        ...existingUser,
        ...refreshedUser,
      };

      if (mergedUser['photo_url'] is String) {
        final url = mergedUser['photo_url'] as String;
        if (url.startsWith('/')) {
          mergedUser['photo_url'] = '${ApiService.baseUrl}$url';
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(mergedUser));
      return mergedUser;
    } catch (e) {
      debugPrint('AuthService: Error in refreshCurrentUser: $e');
      return getUser();
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      // Chuyển đổi sang snake_case cho .NET Backend
      final Map<String, dynamic> payload = {
        if (data.containsKey('display_name')) 'display_name': data['display_name'],
        if (data.containsKey('phone')) 'phone_number': data['phone'],
        if (data.containsKey('phone_number')) 'phone_number': data['phone_number'],
        if (data.containsKey('photo_url')) 'photo_url': data['photo_url'],
        if (data.containsKey('skill_level')) 'skill_level': data['skill_level'],
        if (data.containsKey('dietary_restrictions')) 'dietary_restrictions': data['dietary_restrictions'],
        if (data.containsKey('cuisine_preferences')) 'cuisine_preferences': data['cuisine_preferences'],
        if (data.containsKey('allergies')) 'allergies': data['allergies'],
      };

      final response = await ApiService.put('/api/v1/auth/profile', payload, withAuth: true);
      
      if (response.body.isEmpty) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          return {'success': true, 'message': 'Cập nhật thành công'};
        } else {
          return {'success': false, 'message': 'Lỗi từ máy chủ (Mã lỗi: ${response.statusCode})'};
        }
      }

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Backend .NET trả về user object trực tiếp hoặc trong field 'user'
        final Map<String, dynamic> updatedUser = Map<String, dynamic>.from(responseData['user'] ?? responseData);
        
        // Xử lý PhotoUrl nếu là đường dẫn tương đối
        if (updatedUser.containsKey('photo_url') && updatedUser['photo_url'] != null) {
          String url = updatedUser['photo_url'];
          if (url.startsWith('/')) {
            updatedUser['photo_url'] = '${ApiService.baseUrl}$url';
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(updatedUser));
        return {'success': true, 'user': updatedUser};
      } else {
        return {
          'success': false, 
          'message': responseData['error'] ?? responseData['message'] ?? 'Cập nhật thất bại'
        };
      }
    } catch (e) {
      debugPrint('AuthService: Error in updateProfile: $e');
      return {'success': false, 'message': 'Lỗi kết nối hoặc xử lý: $e'};
    }
  }

  Future<Map<String, dynamic>> updateAvatar(String filePath) async {
    try {
      final url = Uri.parse('${ApiService.baseUrl}/api/v1/auth/avatar');
      final token = await getToken();
      
      debugPrint('AuthService: Uploading avatar to $url');
      final request = http.MultipartRequest('POST', url);
      request.headers['Authorization'] = 'Bearer $token';
      
      if (kIsWeb) {
        final bytes = await http.ByteStream(Stream.value(await http.readBytes(Uri.parse(filePath)))).toBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: 'avatar.jpg',
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('avatar', filePath));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      debugPrint('AuthService: Avatar upload response status: ${response.statusCode}');
      debugPrint('AuthService: Avatar upload response body: ${response.body}');

      if (response.body.isEmpty) {
        if (response.statusCode == 200 || response.statusCode == 201) {
          return {'success': true, 'message': 'Đã cập nhật ảnh đại diện'};
        } else {
          return {'success': false, 'message': 'Lỗi từ máy chủ (Mã lỗi: ${response.statusCode})'};
        }
      }

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> updatedUser = Map<String, dynamic>.from(responseData['user'] ?? responseData);
        
        // Xử lý PhotoUrl nếu là đường dẫn tương đối
        if (updatedUser.containsKey('photo_url') && updatedUser['photo_url'] != null) {
          String url = updatedUser['photo_url'];
          if (url.startsWith('/')) {
            updatedUser['photo_url'] = '${ApiService.baseUrl}$url';
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey, jsonEncode(updatedUser));
        return {'success': true, 'user': updatedUser};
      } else {
        return {
          'success': false, 
          'message': responseData['error'] ?? responseData['message'] ?? 'Avatar update failed'
        };
      }
    } catch (e) {
      debugPrint('AuthService: Error in updateAvatar: $e');
      return {'success': false, 'message': 'Lỗi kết nối: $e'};
    }
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      final response = await ApiService.post('/api/v1/auth/change-password', {
        'current_password': currentPassword,
        'new_password': newPassword,
      }, withAuth: true);

      if (response.body.isEmpty) {
        if (response.statusCode == 404) {
          return {'success': false, 'message': 'Tính năng chưa được triển khai trên server. Vui lòng cập nhật server.'};
        }
        return {'success': false, 'message': 'Lỗi từ máy chủ (Mã lỗi: ${response.statusCode})'};
      }

      final responseData = jsonDecode(utf8.decode(response.bodyBytes));
      
      return {
        'success': response.statusCode == 200,
        'message': responseData['message'] ?? responseData['error'] ?? 'Đổi mật khẩu thất bại',
      };
    } catch (e) {
      debugPrint('AuthService: Error in changePassword: $e');
      return {'success': false, 'message': 'Lỗi kết nối hoặc xử lý: $e'};
    }
  }
}
