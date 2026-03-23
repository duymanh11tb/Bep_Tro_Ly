import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get geminiApiKey {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
    return key;
  }
  
  static String get apiUrl {
    return dotenv.env['API_URL'] ?? 'http://localhost:5001';
  }
  
  static String get apiUrlWeb {
    return dotenv.env['API_URL_WEB'] ?? 'auto';
  }
  
  static bool get isDevelopment {
    return dotenv.env['ENVIRONMENT'] == 'development';
  }
}
