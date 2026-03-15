import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_data';

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await ApiService.post('/api/auth/login', {
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
      return {
        'success': false, 
        'message': data['error'] ?? 'Login failed'
      };
    }
  }

  Future<Map<String, dynamic>> register(String email, String password, {String? displayName}) async {
    final response = await ApiService.post('/api/auth/register', {
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
        'message': data['error'] ?? 'Registration failed'
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

  Future<String?> getRole() async {
    final user = await getUser();
    return user?['role'];
  }
}
