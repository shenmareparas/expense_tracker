/// Typed exception hierarchy for the Expense Tracker application.
///
/// Using typed exceptions allows ViewModels to catch specific failure
/// modes and map them to user-friendly messages without leaking
/// internal Supabase or network error details to the UI layer.
library;

/// Base class for all application-level exceptions.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Thrown when an operation is attempted without a signed-in user.
class UnauthenticatedException extends AppException {
  const UnauthenticatedException()
    : super('You must be signed in to perform this action.');
}

/// Thrown when a database or network request fails.
class DataException extends AppException {
  const DataException([super.message = 'A data error occurred.']);
}

/// Thrown when authentication fails.
class AppAuthException extends AppException {
  const AppAuthException([super.message = 'Authentication failed.']);
}

/// Thrown when network connectivity issues occur.
class NetworkException extends AppException {
  const NetworkException([super.message = 'Network connection failed.']);
}
