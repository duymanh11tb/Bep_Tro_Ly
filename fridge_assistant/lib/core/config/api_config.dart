import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
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
