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
  static const Duration _tapDebounceWindow = Duration(milliseconds: 900);

  // Prevent request spam from rapid repeated taps.
  static final Map<String, Future<http.Response>> _inFlightRequests = {};
  static final Map<String, _RecentResponse> _recentResponses = {};

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
    final requestKey = _buildRequestKey(
      method: 'POST',
      endpoint: endpoint,
      withAuth: withAuth,
      body: body,
    );

    debugPrint('POST $url');
    debugPrint('Body: ${jsonEncode(body)}');

    return _sendWithTapGuard(
      requestKey: requestKey,
      send: () => http
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
    final requestKey = _buildRequestKey(
      method: 'GET',
      endpoint: endpoint,
      withAuth: withAuth,
    );

    return _sendWithTapGuard(
      requestKey: requestKey,
      send: () => http.get(url, headers: headers).timeout(_requestTimeout),
    );
  }

  static Future<http.Response> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await getHeaders(withAuth: withAuth);
    final requestKey = _buildRequestKey(
      method: 'PUT',
      endpoint: endpoint,
      withAuth: withAuth,
      body: body,
    );

    return _sendWithTapGuard(
      requestKey: requestKey,
      send: () => http
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
    final requestKey = _buildRequestKey(
      method: 'DELETE',
      endpoint: endpoint,
      withAuth: withAuth,
    );

    return _sendWithTapGuard(
      requestKey: requestKey,
      send: () => http.delete(url, headers: headers).timeout(_requestTimeout),
    );
  }

  static String _buildRequestKey({
    required String method,
    required String endpoint,
    required bool withAuth,
    Map<String, dynamic>? body,
  }) {
    final bodyEncoded = body == null ? '' : jsonEncode(body);
    return '$method|$endpoint|auth:$withAuth|$bodyEncoded';
  }

  static Future<http.Response> _sendWithTapGuard({
    required String requestKey,
    required Future<http.Response> Function() send,
  }) async {
    final inFlight = _inFlightRequests[requestKey];
    if (inFlight != null) {
      debugPrint('ApiService: dedupe in-flight request $requestKey');
      return inFlight;
    }

    final now = DateTime.now();
    final recent = _recentResponses[requestKey];
    if (recent != null && now.difference(recent.at) < _tapDebounceWindow) {
      debugPrint('ApiService: throttled rapid repeat request $requestKey');
      return recent.response;
    }

    final future = _requestWithRetry(send);
    _inFlightRequests[requestKey] = future;

    try {
      final response = await future;
      _recentResponses[requestKey] = _RecentResponse(
        response: response,
        at: DateTime.now(),
      );
      return response;
    } finally {
      _inFlightRequests.remove(requestKey);
    }
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

class _RecentResponse {
  final http.Response response;
  final DateTime at;

  const _RecentResponse({required this.response, required this.at});
}
