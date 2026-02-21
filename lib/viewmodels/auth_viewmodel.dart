import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// ViewModel for authentication state management.
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

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
      _setError(e is Exception ? e.toString() : 'Unexpected error occurred');
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
      _setError(e is Exception ? e.toString() : 'Unexpected error occurred');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
