import 'package:url_launcher/url_launcher.dart';

import 'app_info_service.dart';

class SupportService {
  static const String supportEmail = 'doanduymanh11@gmail.com';
  static const String supportPhone = '0865060731';

  static Future<bool> sendFeedback({
    required String issue,
    required String detail,
    String? userEmail,
  }) {
    final body = _buildFeedbackBody(
      issue: issue,
      detail: detail,
      userEmail: userEmail,
    );

    return emailSupport(
      subject: '[${AppInfoService.appName}] Phan hoi nguoi dung',
      body: body,
    );
  }

  static Future<bool> requestPasswordReset({required String email}) {
    return emailSupport(
      subject: '[${AppInfoService.appName}] Yeu cau ho tro dat lai mat khau',
      body: _buildForgotPasswordBody(email),
    );
  }

  static Future<bool> callSupport() {
    return _safeLaunch(
      Uri(
        scheme: 'tel',
        path: supportPhone,
      ),
    );
  }

  static Future<bool> openChatSupport({String? message}) async {
    final smsSent = await _safeLaunch(
      Uri(
        scheme: 'sms',
        path: supportPhone,
        queryParameters: message == null || message.trim().isEmpty
            ? null
            : {'body': message.trim()},
      ),
    );

    if (smsSent) return true;

    return emailSupport(
      subject: '[${AppInfoService.appName}] Yeu cau ho tro nhanh',
      body: message?.trim().isNotEmpty == true
          ? message!.trim()
          : 'Xin chao, toi can duoc ho tro nhanh tu doi ngu Bep Tro Ly.',
    );
  }

  static Future<bool> emailSupport({
    String? subject,
    String? body,
  }) {
    return _safeLaunch(
      Uri(
        scheme: 'mailto',
        path: supportEmail,
        queryParameters: <String, String>{
          if (subject != null && subject.trim().isNotEmpty)
            'subject': subject.trim(),
          if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
        },
      ),
    );
  }

  static Future<bool> _safeLaunch(Uri uri) async {
    try {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    return false;
  }

  static String _buildFeedbackBody({
    required String issue,
    required String detail,
    String? userEmail,
  }) {
    final buffer = StringBuffer()
      ..writeln('Xin chao doi ngu ${AppInfoService.appName},')
      ..writeln()
      ..writeln('Toi muon gui phan hoi nhu sau:')
      ..writeln('- Van de: ${issue.trim()}')
      ..writeln('- Chi tiet: ${detail.trim()}');

    if (userEmail != null && userEmail.trim().isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Thong tin lien he:')
        ..writeln('- Email tai khoan: ${userEmail.trim()}');
    }

    buffer
      ..writeln()
      ..writeln('Vui long ho tro khi co the. Cam on!');

    return buffer.toString();
  }

  static String _buildForgotPasswordBody(String email) {
    return '''
Xin chao doi ngu ${AppInfoService.appName},

Toi can ho tro dat lai mat khau cho tai khoan:
- Email dang ky: ${email.trim()}

Vui long huong dan giup toi cac buoc tiep theo.
Cam on!
''';
  }
}
