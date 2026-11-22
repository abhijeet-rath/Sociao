/// Build-time configuration, supplied with `--dart-define-from-file=env.json`.
///
/// Only the project URL and the *publishable* (anon) key belong here.
/// The secret / service-role key must NEVER be added to the app.
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// Throws a clear error when the app was started without env values.
  static void validate() {
    if (!isConfigured) {
      throw StateError(
        'Missing SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY.\n'
        'Copy env.example.json to env.json, fill in your values and run:\n'
        'flutter run --dart-define-from-file=env.json',
      );
    }
  }
}
