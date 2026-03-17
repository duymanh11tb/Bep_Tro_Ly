import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // API Backend deployed on VPS
  static String get baseUrl {
    // Port 5001 is mapped to API container port 5000 on VPS
    return 'http://103.77.173.6:5001';
  }

  static const Duration _requestTimeout = Duration(seconds: 15);
  static const int _maxRetries = 2;

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

    debugPrint('POST $url');
    debugPrint('Body: ${jsonEncode(body)}');

    return _requestWithRetry(
      () => http
          .post(url, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout),
    );
  }

  static Future<http.Response> get(
    String endpoint, {
    bool withAuth = false,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders(withAuth: withAuth);

    return _requestWithRetry(
      () => http.get(url, headers: headers).timeout(_requestTimeout),
    );
  }

  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders(withAuth: withAuth);
    return _requestWithRetry(
      () => http
          .put(url, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout),
    );
  }

  static Future<http.Response> delete(
    String endpoint, {
    bool withAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders(withAuth: withAuth);
    return _requestWithRetry(
      () => http.delete(url, headers: headers).timeout(_requestTimeout),
    );
  }

  static Future<http.Response> _requestWithRetry(
    Future<http.Response> Function() send,
  ) async {
    var attempt = 0;

    while (true) {
      try {
        final response = await send();
        if (!_shouldRetryStatus(response.statusCode) ||
            attempt >= _maxRetries) {
          return response;
        }

        await Future.delayed(
          _computeBackoff(response: response, attempt: attempt),
        );
      } catch (e) {
        if (attempt >= _maxRetries) {
          throw Exception('Connection error: $e');
        }
        await Future.delayed(_computeBackoff(attempt: attempt));
      }

      attempt += 1;
    }
  }

  static bool _shouldRetryStatus(int statusCode) {
    return statusCode == 429 || statusCode == 503;
  }

  static Duration _computeBackoff({
    http.Response? response,
    required int attempt,
  }) {
    final retryAfter = response?.headers['retry-after'];
    if (retryAfter != null) {
      final sec = int.tryParse(retryAfter.trim());
      if (sec != null && sec > 0) {
        return Duration(seconds: sec);
      }
    }

    final baseMs = 500 * (1 << attempt);
    final jitterMs = Random().nextInt(250);
    return Duration(milliseconds: baseMs + jitterMs);
  }
}
