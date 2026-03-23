import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/config/api_config.dart';

class ApiService {
  // API Backend deployed on VPS
  static String get baseUrl {
    final configured = ApiConfig.apiUrl.trim();
    if (!kIsWeb) {
      return (configured.isEmpty)
          ? 'http://localhost:5001'
          : configured;
    }

    final configuredWeb = ApiConfig.apiUrlWeb.trim();
    if (configuredWeb.isEmpty || configuredWeb == 'auto') {
      // If we are on localhost/dev, prefer the configured API_URL (if any) 
      // instead of self-origin, to allow testing against remote servers.
      if (_isDevelopingLocally) {
        final remote = ApiConfig.apiUrl.trim();
        if (remote.isNotEmpty) return remote;
      }
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

  static String _resolveWebBaseUrl(String? configured) {
    final page = Uri.base;
    final pageOrigin = page.origin;
    final isLocalWebHost = _isDevelopingLocally;

    if (configured == null || configured.isEmpty) {
      return pageOrigin;
    }

    final parsed = Uri.tryParse(configured);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return pageOrigin;
    }

    // In production web deployments, prefer same-origin so the app stays
    // aligned with reverse proxies and avoids cross-origin/mixed-content issues.
    if (!isLocalWebHost) {
      return pageOrigin;
    }

    final runningSecure = page.scheme == 'https';
    if (runningSecure && parsed.scheme == 'http') {
      // On web, https pages cannot fetch insecure http APIs.
      // Prefer same-origin when deployed behind a reverse proxy.
      if (!isLocalWebHost) {
        return pageOrigin;
      }

      return parsed.replace(scheme: 'https').toString();
    }

    return configured;
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

  // === Gemini AI Integration ===

  static GenerativeModel? _geminiModel;

  static Future<GenerativeModel> _getGeminiModel() async {
    if (_geminiModel == null) {
      final apiKey = ApiConfig.geminiApiKey;
      _geminiModel = GenerativeModel(
        model: 'gemini-1.5-flash-latest', // Dùng bản latest để ổn định hơn
        apiKey: apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 8192,
        ),
      );
    }
    return _geminiModel!;
  }

  /// Gợi ý món ăn từ nguyên liệu sử dụng Gemini
  static Future<List<Map<String, dynamic>>> suggestRecipesWithGemini({
    required List<String> availableIngredients,
    List<String>? expiringIngredients,
    int numberOfRecipes = 5,
  }) async {
    try {
      final model = await _getGeminiModel();

      final prompt = _buildRecipePrompt(
        availableIngredients: availableIngredients,
        expiringIngredients: expiringIngredients,
        numberOfRecipes: numberOfRecipes,
      );

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;

      if (text == null) {
        throw Exception('No response from Gemini');
      }

      return _parseGeminiRecipes(text);
    } catch (e) {
      debugPrint('Gemini API error: $e');

      // Fallback: gọi API backend nếu có
      try {
        return await _getRecipesFromBackend(
          availableIngredients: availableIngredients,
          expiringIngredients: expiringIngredients,
        );
      } catch (backendError) {
        debugPrint('Backend fallback error: $backendError');
        return [];
      }
    }
  }

  static String _buildRecipePrompt({
    required List<String> availableIngredients,
    List<String>? expiringIngredients,
    required int numberOfRecipes,
  }) {
    return '''
Bạn là đầu bếp chuyên nghiệp. Hãy gợi ý $numberOfRecipes món ăn từ nguyên liệu sau:

NGUYÊN LIỆU CÓ SẴN:
${availableIngredients.map((i) => '- $i').join('\n')}

${expiringIngredients != null && expiringIngredients.isNotEmpty ? '''
NGUYÊN LIỆU CẦN DÙNG TRƯỚC (sắp hết hạn):
${expiringIngredients.map((i) => '- $i').join('\n')}
''' : ''}

YÊU CẦU:
- Ưu tiên sử dụng nguyên liệu sắp hết hạn
- Mỗi món nên có độ phù hợp (match_score) từ 0-1
- Công thức rõ ràng, dễ làm
- Difficulty: easy, medium, hard

TRẢ VỀ JSON CHÍNH XÁC (không text khác):
{
  "recipes": [
    {
      "name": "Tên món ăn",
      "description": "Mô tả ngắn gọn",
      "ingredients_used": ["nguyên liệu 1", "nguyên liệu 2"],
      "ingredients_missing": ["nguyên liệu cần thêm"],
      "prep_time": 15,
      "cook_time": 30,
      "difficulty": "easy",
      "match_score": 0.85,
      "instructions": ["Bước 1: ...", "Bước 2: ..."],
      "tips": "Mẹo nấu ngon"
    }
  ]
}
''';
  }

  static List<Map<String, dynamic>> _parseGeminiRecipes(String response) {
    try {
      String jsonString = response.trim();

      // Xử lý nếu response có code block
      if (jsonString.contains('```json')) {
        final start = jsonString.indexOf('```json') + 7;
        final end = jsonString.indexOf('```', start);
        jsonString = jsonString.substring(start, end).trim();
      } else if (jsonString.contains('```')) {
        final start = jsonString.indexOf('```') + 3;
        final end = jsonString.indexOf('```', start);
        jsonString = jsonString.substring(start, end).trim();
      }

      final data = jsonDecode(jsonString);

      if (data['recipes'] != null && data['recipes'] is List) {
        return List<Map<String, dynamic>>.from(data['recipes']);
      }

      return [];
    } catch (e) {
      debugPrint('Parse Gemini response error: $e');
      debugPrint('Raw response: $response');
      return [];
    }
  }

  /// Fallback: Gọi API backend nếu có
  static Future<List<Map<String, dynamic>>> _getRecipesFromBackend({
    required List<String> availableIngredients,
    List<String>? expiringIngredients,
  }) async {
    try {
      final response = await ApiService.post(
        '/api/recipes/suggest',
        {
          'ingredients': availableIngredients,
          'expiring_ingredients': expiringIngredients ?? [],
        },
        withAuth: true,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['recipes'] ?? []);
      }

      return [];
    } catch (e) {
      debugPrint('Backend recipe API error: $e');
      return [];
    }
  }

  /// Tạo ảnh cho món ăn bằng Gemini
  static Future<String?> generateRecipeImage(String recipeName) async {
    try {
      final model = await _getGeminiModel();

      final prompt = '''
Tìm URL ảnh thật chất lượng cao cho món ăn "$recipeName".
Yêu cầu:
- Ảnh thật của món ăn (không phải ảnh minh họa)
- URL từ nguồn đáng tin cậy (Pexels, Unsplash, hoặc ảnh thực tế)
- Trả về duy nhất URL hợp lệ, không kèm text khác
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final url = response.text?.trim();

      if (url != null &&
          (url.startsWith('http://') || url.startsWith('https://'))) {
        return url;
      }

      return null;
    } catch (e) {
      debugPrint('Generate image error: $e');
      return null;
    }
  }

  /// Gợi ý món ăn kèm ảnh (kết hợp)
  static Future<List<Map<String, dynamic>>> suggestRecipesWithImages({
    required List<String> availableIngredients,
    List<String>? expiringIngredients,
    int numberOfRecipes = 5,
  }) async {
    // Lấy gợi ý công thức
    final recipes = await suggestRecipesWithGemini(
      availableIngredients: availableIngredients,
      expiringIngredients: expiringIngredients,
      numberOfRecipes: numberOfRecipes,
    );

    // Thêm ảnh cho từng món (có thể chạy song song)
    final updatedRecipes = <Map<String, dynamic>>[];

    for (var recipe in recipes) {
      final imageUrl = await generateRecipeImage(recipe['name']);
      updatedRecipes.add({
        ...recipe,
        'image_url': imageUrl,
      });
    }

    return updatedRecipes;
  }
}
class _RecentResponse {
  final http.Response response;
  final DateTime at;

  const _RecentResponse({required this.response, required this.at});
}
