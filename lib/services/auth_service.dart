import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'subscription_service.dart';

/// Authentication service for server mode
/// Handles Firebase Authentication for email/password sign in/up
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;

  // Constructor calls initialization
  AuthService._internal() {
    _initializeGoogleSignIn();
  }

  static AuthService get instance => _instance;

  // Initialize GoogleSignIn with proper configuration
  void _initializeGoogleSignIn() {
    if (kIsWeb) {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        // For web, the client ID is configured in index.html
        // No need to specify it here for web
      );
    } else {
      _googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
        // For Android, ensure the app's package name and SHA-1 fingerprint
        // are registered in Firebase Console
        // The client ID comes from google-services.json
        signInOption: SignInOption.standard,
      );
    }
  }

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

      // Sync trial status from Firestore after successful sign-in
      await _syncUserDataAfterSignIn();

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

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // For web, check if we have proper configuration
        if (kDebugMode) {
          print('Attempting Google Sign-in on Web...');
        }

        // Try to sign in silently first (recommended for web)
        GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();

        // If no silent sign-in, trigger the sign-in flow
        if (googleUser == null) {
          if (kDebugMode) {
            print('No silent sign-in available, triggering sign-in flow...');
          }
          googleUser = await _googleSignIn.signIn();
        }

        // If the user cancels the sign in process
        if (googleUser == null) {
          return AuthResult.error('Google Sign-in cancelled');
        }

        // Get the authentication details
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        if (kDebugMode) {
          print(
            'Got Google auth - Access Token: ${googleAuth.accessToken != null}',
          );
          print('Got Google auth - ID Token: ${googleAuth.idToken != null}');
        }

        // Create Firebase credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase with the Google credentials
        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );

        if (kDebugMode) {
          print(
            'User signed in with Google (Web): ${userCredential.user?.email}',
          );
        }

        // Sync trial status from Firestore after successful sign-in
        await _syncUserDataAfterSignIn();

        return AuthResult.success(userCredential.user);
      } else {
        // For mobile platforms, use the standard flow
        // Sign out from any existing Google account first
        await _googleSignIn.signOut();

        // Trigger the Google Sign In flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        // If the user cancels the sign in process
        if (googleUser == null) {
          return AuthResult.error('Google Sign-in cancelled');
        }

        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Create a new credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase with the Google credentials
        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );

        if (kDebugMode) {
          print(
            'User signed in with Google (Mobile): ${userCredential.user?.email}',
          );
        }

        // Sync trial status from Firestore after successful sign-in
        await _syncUserDataAfterSignIn();

        return AuthResult.success(userCredential.user);
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Google sign in Firebase error: ${e.code} - ${e.message}');
      }
      return AuthResult.error(_getAuthErrorMessage(e));
    } catch (e) {
      if (kDebugMode) {
        print('Google sign in error: $e');
        print('Error type: ${e.runtimeType}');
      }

      // Handle specific Google Sign-In errors
      if (e is PlatformException) {
        switch (e.code) {
          case 'sign_in_failed':
            // This is often error code 10 (DEVELOPER_ERROR)
            if (e.message?.contains('10') ?? false) {
              return AuthResult.error(
                'Google Sign-in configuration error. The app is not properly configured in Firebase Console.\n'
                'Please ensure the SHA-1 fingerprint is added to your Firebase project.\n'
                'Error: ${e.message}',
              );
            }
            return AuthResult.error(
              'Google Sign-in failed. Please check your internet connection and try again.',
            );
          case 'network_error':
            return AuthResult.error(
              'Network error during Google Sign-in. Please check your connection.',
            );
          case 'sign_in_canceled':
            return AuthResult.error('Google Sign-in was cancelled');
          case 'sign_in_required':
            return AuthResult.error('Google Sign-in is required');
          default:
            return AuthResult.error(
              'Google Sign-in error: ${e.message ?? 'Unknown error (${e.code})'}',
            );
        }
      }

      final errorMessage = e.toString();
      if (errorMessage.contains('CLIENT_ID_REQUIRED') ||
          errorMessage.contains('invalid_client') ||
          errorMessage.contains('401')) {
        return AuthResult.error(
          'Google Sign-in is not properly configured. Please check the setup guide in GOOGLE_SIGNIN_SETUP.md',
        );
      }

      return AuthResult.error('Google sign-in failed. Please try again.');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Sign out from both Firebase and Google
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);

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

  /// Sync user data from Firestore after successful sign-in
  Future<void> _syncUserDataAfterSignIn() async {
    try {
      // Use a delayed execution to avoid circular imports
      // and ensure all services are initialized
      Future.delayed(const Duration(milliseconds: 100), () async {
        await SubscriptionService.instance
            .isPremiumUser(); // This triggers sync
      });

      if (kDebugMode) {
        print('🔄 User data sync initiated after sign-in');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error syncing user data after sign-in: $e');
      }
      // Don't throw error to avoid disrupting sign-in flow
    }
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
      case 'invalid-verification-code':
        return 'Invalid verification code. Please try again.';
      case 'invalid-verification-id':
        return 'Invalid verification ID. Please try again.';
      case 'credential-already-in-use':
        return 'This Google account is already linked to another user.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with the same email address but different sign-in credentials.';
      default:
        if (kDebugMode) {
          print('Unhandled Firebase Auth error: ${e.code} - ${e.message}');
        }
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
