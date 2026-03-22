import 'package:shared_preferences/shared_preferences.dart';

class LanguageOption {
  final String code;
  final String label;
  final String subtitle;

  const LanguageOption({
    required this.code,
    required this.label,
    required this.subtitle,
  });
}

class AppPreferencesService {
  static const String _preferredLanguageKey = 'preferred_language';

  static const String vietnamese = 'vi';
  static const String english = 'en';

  static const List<LanguageOption> supportedLanguages = [
    LanguageOption(
      code: vietnamese,
      label: 'Tiếng Việt',
      subtitle: 'Ngôn ngữ mặc định của ứng dụng',
    ),
    LanguageOption(
      code: english,
      label: 'English',
      subtitle: 'Dùng cho cấu hình ưu tiên và hỗ trợ sau này',
    ),
  ];

  static Future<String> getPreferredLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return normalizeLanguageCode(prefs.getString(_preferredLanguageKey));
  }

  static Future<void> setPreferredLanguageCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferredLanguageKey, normalizeLanguageCode(code));
  }

  static String normalizeLanguageCode(String? code) {
    final normalized = code?.trim().toLowerCase();
    for (final option in supportedLanguages) {
      if (option.code == normalized) return option.code;
    }
    return vietnamese;
  }

  static String labelFor(String? code) {
    final normalized = normalizeLanguageCode(code);
    return supportedLanguages
        .firstWhere((option) => option.code == normalized)
        .label;
  }
}
