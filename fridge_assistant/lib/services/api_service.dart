import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ApiService {
  // Android Emulator uses 10.0.2.2 to access localhost of the host machine
  // Windows/iOS use localhost directly
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    }
    return 'http://localhost:5000';
  }

  static Future<Map<String, String>> getHeaders({bool withAuth = false}) async {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAuth = false,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders(withAuth: withAuth);

    print('POST $url');
    print('Body: ${jsonEncode(body)}');

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      return response;
    } catch (e) {
      print('API Error: $e');
      throw Exception('Connection error: $e');
    }
  }

  static Future<http.Response> get(
    String endpoint, {
    bool withAuth = false,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders(withAuth: withAuth);

    print('GET $url');

    try {
      final response = await http.get(url, headers: headers);
      print('Response Status: ${response.statusCode}');
      return response;
    } catch (e) {
      print('API Error: $e');
      throw Exception('Connection error: $e');
    }
  }
}
