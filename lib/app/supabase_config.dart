import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Supabase configuration and client access.
class SupabaseConfig {
  static const String _url = 'https://spxvkxmpcgxbmsneffgo.supabase.co';
  static const String _anonKey =
      'sb_publishable_Yi8cw2XgJ9SvVz7g9o5hgg_I9zR227S';

  /// Initialize Supabase. Call once in main().
  static Future<void> initialize() async {
    await Supabase.initialize(url: _url, anonKey: _anonKey);
  }

  /// The Supabase client instance.
  static SupabaseClient get client => Supabase.instance.client;
}
