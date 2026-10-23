import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pickorbeet/core/providers/core_providers.dart';

/// Choices from the settings screen. They live on the device.
@immutable
class AppPreferences {
  const AppPreferences({
    this.notifications = true,
    this.darkMode = false,
    this.languageCode = 'en',
    this.currencyCode = 'BDT',
  });

  final bool notifications;
  final bool darkMode;
  final String languageCode;
  final String currencyCode;

  String get languageLabel => switch (languageCode) {
        'en' => 'English (US)',
        _ => languageCode,
      };

  String get currencyLabel => switch (currencyCode) {
        'BDT' => 'Bangladeshi Taka (৳)',
        _ => currencyCode,
      };

  AppPreferences copyWith({
    bool? notifications,
    bool? darkMode,
    String? languageCode,
    String? currencyCode,
  }) {
    return AppPreferences(
      notifications: notifications ?? this.notifications,
      darkMode: darkMode ?? this.darkMode,
      languageCode: languageCode ?? this.languageCode,
      currencyCode: currencyCode ?? this.currencyCode,
    );
  }
}

class PreferencesNotifier extends Notifier<AppPreferences> {
  static const _notifications = 'settings_notifications';
  static const _dark = 'settings_dark_mode';
  static const _language = 'settings_language';
  static const _currency = 'settings_currency';

  @override
  AppPreferences build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppPreferences(
      notifications: prefs.getBool(_notifications) ?? true,
      darkMode: prefs.getBool(_dark) ?? false,
      languageCode: prefs.getString(_language) ?? 'en',
      currencyCode: prefs.getString(_currency) ?? 'BDT',
    );
  }

  Future<void> setNotifications(bool value) async {
    state = state.copyWith(notifications: value);
    await ref.read(sharedPreferencesProvider).setBool(_notifications, value);
  }

  Future<void> setDarkMode(bool value) async {
    state = state.copyWith(darkMode: value);
    await ref.read(sharedPreferencesProvider).setBool(_dark, value);
  }

  Future<void> setLanguage(String code) async {
    state = state.copyWith(languageCode: code);
    await ref.read(sharedPreferencesProvider).setString(_language, code);
  }

  Future<void> setCurrency(String code) async {
    state = state.copyWith(currencyCode: code);
    await ref.read(sharedPreferencesProvider).setString(_currency, code);
  }
}

final preferencesProvider = NotifierProvider<PreferencesNotifier, AppPreferences>(PreferencesNotifier.new);
