import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'auth_service.dart';
import 'api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Android nên dùng serverClientId; clientId chỉ cần cho Web/iOS.
    clientId: (kIsWeb || Platform.isIOS)
        ? dotenv.env['GOOGLE_CLIENT_ID']
        : null,
    serverClientId: kIsWeb ? null : dotenv.env['GOOGLE_CLIENT_ID'],
    scopes: ['openid', 'email', 'profile'],
  );

  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // 1. Khởi động quy trình đăng nhập Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'success': false, 'message': 'Đã hủy đăng nhập'};
      }

      // 2. Lấy token từ Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;

      if (idToken == null && accessToken == null) {
        return {'success': false, 'message': 'Không lấy được Token từ Google'};
      }

      // 3. Gửi Token về Backend sử dụng ApiService
      final payload = <String, dynamic>{};
      if (idToken != null) payload['idToken'] = idToken;
      if (accessToken != null) payload['accessToken'] = accessToken;
      final response = await ApiService.post('/api/auth/google-login', payload);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = data['token'];
        final user = data['user'];

        await _authService.loginWithToken(token, user);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Lỗi xác thực Backend',
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Lỗi đăng nhập Google: $e'};
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _authService.logout();
  }
}
