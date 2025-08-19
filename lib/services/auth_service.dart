import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Authentication service for server mode
/// Handles Firebase Authentication for email/password sign in/up
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static AuthService get instance => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with email and password
  Future<AuthResult> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      // Validate email format
      if (!_isValidEmail(email)) {
        return AuthResult.error('Please enter a valid email address');
      }

      // Validate password strength
      final passwordValidation = _validatePassword(password);
      if (passwordValidation != null) {
        return AuthResult.error(passwordValidation);
      }

      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password,
          );

      // Update display name if provided
      if (displayName != null && displayName.isNotEmpty) {
        await credential.user?.updateDisplayName(displayName.trim());
      }

      // Send email verification
      await credential.user?.sendEmailVerification();

      if (kDebugMode) {
        print('User signed up successfully: ${credential.user?.email}');
      }

      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Sign up error: ${e.code} - ${e.message}');
      }
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected sign up error: $e');
      }
      return AuthResult.error(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Validate email format
      if (!_isValidEmail(email)) {
        return AuthResult.error('Please enter a valid email address');
      }

      if (password.isEmpty) {
        return AuthResult.error('Please enter your password');
      }

      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (kDebugMode) {
        print('User signed in successfully: ${credential.user?.email}');
      }

      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Sign in error: ${e.code} - ${e.message}');
      }
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected sign in error: $e');
      }
      return AuthResult.error(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      if (kDebugMode) {
        print('User signed out successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sign out error: $e');
      }
      rethrow;
    }
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      if (!_isValidEmail(email)) {
        return AuthResult.error('Please enter a valid email address');
      }

      await _auth.sendPasswordResetEmail(email: email.trim());

      if (kDebugMode) {
        print('Password reset email sent to: $email');
      }

      return AuthResult.success(
        null,
        message: 'Password reset email sent. Please check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Password reset error: ${e.code} - ${e.message}');
      }
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected password reset error: $e');
      }
      return AuthResult.error(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Resend email verification
  Future<AuthResult> resendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.error('No user is currently signed in');
      }

      if (user.emailVerified) {
        return AuthResult.error('Email is already verified');
      }

      await user.sendEmailVerification();

      if (kDebugMode) {
        print('Email verification sent to: ${user.email}');
      }

      return AuthResult.success(
        null,
        message: 'Verification email sent. Please check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Email verification error: ${e.code} - ${e.message}');
      }
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected email verification error: $e');
      }
      return AuthResult.error(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Reload user to check email verification status
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      if (kDebugMode) {
        print('Error reloading user: $e');
      }
    }
  }

  /// Delete user account
  Future<AuthResult> deleteAccount() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.error('No user is currently signed in');
      }

      await user.delete();

      if (kDebugMode) {
        print('User account deleted successfully');
      }

      return AuthResult.success(null, message: 'Account deleted successfully');
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Delete account error: ${e.code} - ${e.message}');
      }
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected delete account error: $e');
      }
      return AuthResult.error(
        'An unexpected error occurred. Please try again.',
      );
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  /// Validate password strength
  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Please enter a password';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    if (password.length > 128) {
      return 'Password must be less than 128 characters';
    }

    // Check for at least one letter and one number
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);

    if (!hasLetter || !hasNumber) {
      return 'Password must contain at least one letter and one number';
    }

    return null; // Password is valid
  }

  /// Convert Firebase Auth errors to user-friendly messages
  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Please sign in instead.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled. Please contact support.';
      case 'weak-password':
        return 'Please choose a stronger password.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'user-not-found':
        return 'No account found with this email. Please sign up first.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please check your credentials.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'requires-recent-login':
        return 'This operation requires recent authentication. Please sign in again.';
      default:
        return e.message ??
            'An authentication error occurred. Please try again.';
    }
  }
}

/// Result wrapper for authentication operations
class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? error;
  final String? message;

  AuthResult._({required this.isSuccess, this.user, this.error, this.message});

  factory AuthResult.success(User? user, {String? message}) {
    return AuthResult._(isSuccess: true, user: user, message: message);
  }

  factory AuthResult.error(String error) {
    return AuthResult._(isSuccess: false, error: error);
  }
}
