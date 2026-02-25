import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../app/supabase_config.dart';

/// Singleton service layer for authentication operations.
/// Decouples auth logic from the Supabase SDK.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const int _maxAttempts = 3;

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
    return _retry(
      () => _client.auth.signInWithPassword(email: email, password: password),
    );
  }

  /// Sign up with email, password, and user metadata.
  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
  }) {
    return _retry(
      () => _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      ),
    );
  }

  /// Sign out the current user.
  Future<void> signOut() => _retry(() => _client.auth.signOut());

  /// Retries [action] up to [_maxAttempts] times with exponential back-off
  /// when a network-level error is detected.
  Future<T> _retry<T>(Future<T> Function() action) async {
    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e) {
        final isLastAttempt = attempt == _maxAttempts;
        if (isLastAttempt || !_isNetworkError(e)) rethrow;
        // Exponential back-off: 1s, 2s
        await Future<void>.delayed(Duration(seconds: attempt));
      }
    }
    // Unreachable, but satisfies the return type.
    throw StateError('Retry loop exited unexpectedly');
  }

  /// Returns true for errors caused by network connectivity issues.
  bool _isNetworkError(Object error) {
    if (error is SocketException) return true;
    if (error is AuthRetryableFetchException) return true;
    return false;
  }
}
