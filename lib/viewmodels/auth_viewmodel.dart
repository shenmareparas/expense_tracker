import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

/// ViewModel for authentication state management.
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  Stream<AuthState> get authStateChanges => _authService.onAuthStateChange;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  void clearError() {
    _setError(null);
  }

  Future<bool> signIn({required String email, required String password}) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signIn(email: email, password: password);
      return true;
    } catch (e) {
      _setError(_friendlyMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.signUp(name: name, email: email, password: password);
      return true;
    } catch (e) {
      _setError(_friendlyMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    DatabaseService.instance.clearCache();
    await _authService.signOut();
  }

  /// Maps raw exceptions to user-friendly messages.
  String _friendlyMessage(Object error) {
    if (error is SocketException || error is AuthRetryableFetchException) {
      return 'Connection failed. Please check your internet and try again.';
    }
    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('invalid') || msg.contains('credentials')) {
        return 'Invalid email or password.';
      }
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }
}
