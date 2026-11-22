import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/supabase/supabase_client.dart';

/// Overridden in `main()` once SharedPreferences has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.light,
    this.notificationsEnabled = true,
    this.language = 'en',
  });

  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final String language;

  SettingsState copyWith({
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    String? language,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    language: language ?? this.language,
  );
}

const _themeKey = 'theme';
const _notifKey = 'notifications';
const _langKey = 'language';

ThemeMode themeFromName(String? name) => switch (name) {
  'dark' => ThemeMode.dark,
  'system' => ThemeMode.system,
  _ => ThemeMode.light,
};

/// App preferences. Stored locally (instant, works signed-out) and mirrored
/// to the `user_settings` table so they follow the user across devices.
class SettingsController extends Notifier<SettingsState> {
  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  SettingsState build() {
    ref.listen<String?>(
      currentUserProvider.select((u) => u?.id),
      (_, id) => id == null ? null : _pull(id),
      fireImmediately: true,
    );
    return SettingsState(
      themeMode: themeFromName(_prefs.getString(_themeKey)),
      notificationsEnabled: _prefs.getBool(_notifKey) ?? true,
      language: _prefs.getString(_langKey) ?? 'en',
    );
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

  Future<void> setNotifications(bool enabled) =>
      _update(state.copyWith(notificationsEnabled: enabled));

  Future<void> setLanguage(String code) =>
      _update(state.copyWith(language: code));

  Future<void> _update(SettingsState next) async {
    state = next;
    await _prefs.setString(_themeKey, next.themeMode.name);
    await _prefs.setBool(_notifKey, next.notificationsEnabled);
    await _prefs.setString(_langKey, next.language);
    await _push(next);
  }

  Future<void> _push(SettingsState s) async {
    final me = ref.read(currentUserProvider)?.id;
    if (me == null) return; // signed out: preferences stay local
    try {
      await ref.read(supabaseClientProvider).from('user_settings').upsert({
        'user_id': me,
        'theme': s.themeMode.name,
        'notifications_enabled': s.notificationsEnabled,
        'language': s.language,
      });
    } catch (_) {
      // Local value still applies; it will sync on the next change.
    }
  }

  Future<void> _pull(String userId) async {
    try {
      final row = await ref
          .read(supabaseClientProvider)
          .from('user_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return;
      final next = SettingsState(
        themeMode: themeFromName(row['theme'] as String?),
        notificationsEnabled: row['notifications_enabled'] as bool? ?? true,
        language: row['language'] as String? ?? 'en',
      );
      state = next;
      await _prefs.setString(_themeKey, next.themeMode.name);
      await _prefs.setBool(_notifKey, next.notificationsEnabled);
      await _prefs.setString(_langKey, next.language);
    } catch (_) {
      // Keep local preferences when offline.
    }
  }
}

final settingsProvider = NotifierProvider<SettingsController, SettingsState>(
  SettingsController.new,
);
