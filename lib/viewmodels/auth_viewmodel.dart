import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../utils/exceptions.dart';

/// ViewModel for authentication state management.
class AuthViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  late final StreamSubscription<AuthState> _authSubscription;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  late final Stream<bool> authStateChanges = _authService.onAuthStateChange;

  bool _isInRecoveryMode = false;
  bool get isInRecoveryMode => _isInRecoveryMode;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  AuthViewModel() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _authSubscription = _authService.onRawAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isInRecoveryMode = true;
        notifyListeners();
      } else if (data.event == AuthChangeEvent.signedIn ||
          data.event == AuthChangeEvent.signedOut) {
        _isInRecoveryMode = false;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

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

  Future<bool> sendResetPasswordLink(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.sendResetPasswordLink(email);
      return true;
    } catch (e) {
      _setError(_friendlyMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.verifyRecoveryOtp(email: email, token: token);
      _isInRecoveryMode = true;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_friendlyMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    _setLoading(true);
    _setError(null);
    try {
      await _authService.updatePassword(newPassword);
      // Once successfully updated, clear recovery mode
      _isInRecoveryMode = false;
      notifyListeners();
      return true;
    } catch (e) {
      _setError(_friendlyMessage(e));
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Maps raw exceptions to user-friendly messages.
  String _friendlyMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }
    return 'Something went wrong. Please try again.';
  }
}
