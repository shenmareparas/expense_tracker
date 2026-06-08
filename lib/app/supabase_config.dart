import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Supabase configuration and client access.
///
/// Credentials are injected at build time via --dart-define:
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx
///
/// For local development you may also place them in a
/// `--dart-define-from-file=.env.json` file (not committed to git).
class SupabaseConfig {
  // These are resolved at compile time. The fallbacks below are only
  // present for convenience during initial development and should be
  // replaced with your actual values via dart-define before shipping.
  static const String _url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://spxvkxmpcgxbmsneffgo.supabase.co',
  );
  static const String _anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_Yi8cw2XgJ9SvVz7g9o5hgg_I9zR227S',
  );

  /// Initialize Supabase. Call once in main().
  static Future<void> initialize() async {
    await Supabase.initialize(url: _url, publishableKey: _anonKey);
  }

  /// The Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;
}

