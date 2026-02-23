import 'package:supabase_flutter/supabase_flutter.dart';
import '../app/supabase_config.dart';

/// Singleton service layer for authentication operations.
/// Decouples auth logic from the Supabase SDK.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final SupabaseClient _client = SupabaseConfig.client;

  /// Stream of auth state changes (sign in, sign out, token refresh, etc.).
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// The currently signed-in user, or null.
  User? get currentUser => _client.auth.currentUser;

  /// Sign in with email and password.
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Sign up with email, password, and user metadata.
  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
  }

  /// Sign out the current user.
  Future<void> signOut() => _client.auth.signOut();
}
