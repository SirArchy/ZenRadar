import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage app localization and language switching
class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  static LocalizationService get instance => _instance;

  LocalizationService._internal();

  static const String _languageCodeKey = 'language_code';

  // Supported languages
  static const List<LocaleInfo> supportedLanguages = [
    LocaleInfo(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇬🇧',
    ),
    LocaleInfo(code: 'de', name: 'German', nativeName: 'Deutsch', flag: '🇩🇪'),
    LocaleInfo(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
    ),
    LocaleInfo(
      code: 'pt',
      name: 'Portuguese',
      nativeName: 'Português',
      flag: '🇵🇹',
    ),
    LocaleInfo(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
    ),
    LocaleInfo(code: 'ja', name: 'Japanese', nativeName: '日本語', flag: '🇯🇵'),
  ];

  /// Get the list of supported locales for Flutter
  static List<Locale> get supportedLocales {
    return supportedLanguages.map((lang) => Locale(lang.code)).toList();
  }

  /// Get the current language code from shared preferences
  Future<String?> getLanguageCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_languageCodeKey);
    } catch (e) {
      return null;
    }
  }

  /// Save the language code to shared preferences
  Future<bool> setLanguageCode(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_languageCodeKey, languageCode);
    } catch (e) {
      return false;
    }
  }

  /// Clear the saved language preference (use system default)
  Future<bool> clearLanguageCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_languageCodeKey);
    } catch (e) {
      return false;
    }
  }

  /// Get LocaleInfo by language code
  static LocaleInfo? getLocaleInfo(String code) {
    try {
      return supportedLanguages.firstWhere((lang) => lang.code == code);
    } catch (e) {
      return null;
    }
  }

  /// Check if a language code is supported
  static bool isSupported(String code) {
    return supportedLanguages.any((lang) => lang.code == code);
  }

  /// Get the device's current locale if supported, otherwise return English
  static Locale getDeviceLocale(BuildContext context) {
    final deviceLocale = View.of(context).platformDispatcher.locale;

    // Check if the device language is supported
    if (isSupported(deviceLocale.languageCode)) {
      return Locale(deviceLocale.languageCode);
    }

    // Default to English
    return const Locale('en');
  }
}

/// Information about a locale/language
class LocaleInfo {
  final String code;
  final String name;
  final String nativeName;
  final String flag;

  const LocaleInfo({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
  });
}
