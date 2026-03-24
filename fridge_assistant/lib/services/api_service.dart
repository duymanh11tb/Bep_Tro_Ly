import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config/api_config.dart';

class ApiService {
  // API Backend deployed on VPS
  static String get baseUrl {
    final configured = ApiConfig.apiUrl.trim();
    if (!kIsWeb) {
      return _sanitizeBaseUrl(
        configured.isEmpty ? 'http://localhost:5001' : configured,
      );
    }

    final configuredWeb = ApiConfig.apiUrlWeb.trim();
    if (!_isDevelopingLocally) {
      return _resolveProductionWebBaseUrl(configuredWeb);
    }

    if (configuredWeb.isEmpty || configuredWeb == 'auto') {
      final remote = ApiConfig.apiUrl.trim();
      if (remote.isNotEmpty) return _sanitizeBaseUrl(remote);
      return _resolveWebBaseUrl(null);
    }

    return _resolveWebBaseUrl(configuredWeb);
  }

  static const Duration _requestTimeout = Duration(seconds: 15);
  static const int _maxRetries = 2;
  static const Duration _tapDebounceWindow = Duration(milliseconds: 900);

  // Prevent request spam from rapid repeated taps.
  static final Map<String, Future<http.Response>> _inFlightRequests = {};
  static final Map<String, _RecentResponse> _recentResponses = {};

  static Uri buildUri(String endpoint) {
    return Uri.parse('$baseUrl$endpoint');
  }

  static String absoluteUrl(String pathOrUrl) {
    final raw = pathOrUrl.trim();
    if (raw.isEmpty) return raw;

    final parsed = Uri.tryParse(raw);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      return raw;
    }

    if (raw.startsWith('/')) {
      return '$baseUrl$raw';
    }

    return '$baseUrl/$raw';
  }

  static bool get _isDevelopingLocally {
    final page = Uri.base;
    return page.host == 'localhost' ||
        page.host == '127.0.0.1' ||
        page.host == '0.0.0.0';
  }

  static String _sanitizeBaseUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static String _resolveProductionWebBaseUrl(String configuredWeb) {
    final pageOrigin = Uri.base.origin;
    if (configuredWeb.isEmpty || configuredWeb == 'auto') {
      return _sanitizeBaseUrl(pageOrigin);
    }

    final parsed = Uri.tryParse(configuredWeb);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return _sanitizeBaseUrl(pageOrigin);
    }

    // Production web should prefer same-origin to avoid mixed-content and
    // cross-origin fetch failures behind domains/reverse proxies.
    final page = Uri.base;
    if (page.scheme == 'https' && parsed.scheme != 'https') {
      return _sanitizeBaseUrl(pageOrigin);
    }

    final sameOrigin =
        parsed.scheme == page.scheme &&
        parsed.host == page.host &&
        parsed.port == page.port;
    if (!sameOrigin) {
      return _sanitizeBaseUrl(pageOrigin);
    }

    return _sanitizeBaseUrl(configuredWeb);
  }

  static String _resolveWebBaseUrl(String? configured) {
    final page = Uri.base;
    final pageOrigin = page.origin;
    final isLocalWebHost = _isDevelopingLocally;

    if (configured == null || configured.isEmpty) {
      return _sanitizeBaseUrl(pageOrigin);
    }

    final parsed = Uri.tryParse(configured);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return _sanitizeBaseUrl(pageOrigin);
    }

    // In production web deployments, prefer same-origin so the app stays
    // aligned with reverse proxies and avoids cross-origin/mixed-content issues.
    if (!isLocalWebHost) {
      return _sanitizeBaseUrl(pageOrigin);
    }

    final runningSecure = page.scheme == 'https';
    if (runningSecure && parsed.scheme == 'http') {
      // On web, https pages cannot fetch insecure http APIs.
      // Prefer same-origin when deployed behind a reverse proxy.
      if (!isLocalWebHost) {
        return _sanitizeBaseUrl(pageOrigin);
      }

      return _sanitizeBaseUrl(parsed.replace(scheme: 'https').toString());
    }

    return _sanitizeBaseUrl(configured);
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
    final url = buildUri(endpoint);
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
    final url = buildUri(endpoint);
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
    final url = buildUri(endpoint);
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

  static Future<http.Response> patch(
    String endpoint,
    Map<String, dynamic> body, {
    bool withAuth = true,
  }) async {
    final url = buildUri(endpoint);
    final headers = await getHeaders(withAuth: withAuth);
    final requestKey = _buildRequestKey(
      method: 'PATCH',
      endpoint: endpoint,
      withAuth: withAuth,
      body: body,
    );

    return _sendWithTapGuard(
      requestKey: requestKey,
      send: () => http
          .patch(url, headers: headers, body: jsonEncode(body))
          .timeout(_requestTimeout),
    );
  }

  static Future<http.Response> delete(
    String endpoint, {
    bool withAuth = true,
  }) async {
    final url = buildUri(endpoint);
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
          throw Exception(_buildConnectionErrorMessage(e));
        }
        await Future.delayed(_computeBackoff(attempt: attempt));
      }

      attempt += 1;
    }
  }

  static String _buildConnectionErrorMessage(Object error) {
    if (!kIsWeb) {
      return 'Connection error: $error';
    }

    final page = Uri.base;
    final api = Uri.tryParse(baseUrl);
    if (api != null) {
      final isMixedContent = page.scheme == 'https' && api.scheme == 'http';
      if (isMixedContent) {
        return 'Không thể kết nối API vì ứng dụng web đang chạy HTTPS nhưng backend đang dùng HTTP. Hãy dùng cùng domain hoặc reverse proxy HTTPS.';
      }

      final sameOrigin =
          api.scheme == page.scheme &&
          api.host == page.host &&
          api.port == page.port;
      if (!_isDevelopingLocally && !sameOrigin) {
        return 'Không thể kết nối API do web đang gọi khác origin. Hãy cấu hình web dùng cùng domain hoặc reverse proxy API.';
      }
    }

    return 'Không kết nối được tới máy chủ. Hãy kiểm tra backend, domain và cổng truy cập.';
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
