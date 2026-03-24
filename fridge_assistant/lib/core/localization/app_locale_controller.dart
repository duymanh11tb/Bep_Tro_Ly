import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../services/app_preferences_service.dart';

class AppLocaleController extends ValueNotifier<Locale> {
  AppLocaleController._() : super(const Locale(AppPreferencesService.vietnamese));

  static final AppLocaleController instance = AppLocaleController._();

  String get localeCode => value.languageCode;

  Future<void> loadSavedLocale() async {
    final code = await AppPreferencesService.getPreferredLanguageCode();
    if (value.languageCode != code) {
      value = Locale(code);
    }
  }

  Future<void> setLocaleCode(String code) async {
    final normalized = AppPreferencesService.normalizeLanguageCode(code);
    await AppPreferencesService.setPreferredLanguageCode(normalized);
    if (value.languageCode != normalized) {
      value = Locale(normalized);
    }
  }
}
