import 'package:google_sign_in/google_sign_in.dart';
import 'dart:convert';
import 'auth_service.dart';
import 'api_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: dotenv.env['GOOGLE_CLIENT_ID'],
    serverClientId: dotenv.env['GOOGLE_CLIENT_ID'],
    scopes: ['email', 'profile'],
  );

  final AuthService _authService = AuthService();

  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // 1. Khởi động quy trình đăng nhập Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        return {'success': false, 'message': 'Đã hủy đăng nhập'};
      }

      // 2. Lấy IdToken
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        return {'success': false, 'message': 'Không lấy được Token từ Google'};
      }

      // 3. Gửi Token về Backend sử dụng ApiService
      final response = await ApiService.post('/api/auth/google-login', {
        'idToken': idToken,
      });

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final token = data['token'];
        final user = data['user'];
        
        await _authService.loginWithToken(token, user);
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false, 
          'message': data['error'] ?? 'Lỗi xác thực Backend'
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
