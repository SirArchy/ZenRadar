import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zenradar/data/services/subscription/subscription_service.dart';

/// Authentication service for server mode
/// Handles Firebase Authentication for email/password sign in/up
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final GoogleSignIn _googleSignIn;
  static const String _persistedSessionKey = 'auth_has_persisted_session';

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
    final l10n = await _getL10n();
    try {
      // Validate email format
      if (!_isValidEmail(email)) {
        return AuthResult.error(l10n.enterValidEmail);
      }

      // Validate password strength
      final passwordValidation = _validatePassword(password, l10n);
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

      await _setPersistedSession(credential.user != null);

      if (kDebugMode) {}

      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {}
      return AuthResult.error(_getAuthErrorMessage(e, l10n));
    } catch (e) {
      if (kDebugMode) {}
      return AuthResult.error(l10n.authUnexpectedErrorTryAgain);
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final l10n = await _getL10n();
    try {
      // Validate email format
      if (!_isValidEmail(email)) {
        return AuthResult.error(l10n.enterValidEmail);
      }

      if (password.isEmpty) {
        return AuthResult.error(l10n.enterPassword);
      }

      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (kDebugMode) {}

      // Sync trial status from Firestore after successful sign-in
      await _syncUserDataAfterSignIn();

      await _setPersistedSession(credential.user != null);

      return AuthResult.success(credential.user);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {}
      return AuthResult.error(_getAuthErrorMessage(e, l10n));
    } catch (e) {
      if (kDebugMode) {}
      return AuthResult.error(l10n.authUnexpectedErrorTryAgain);
    }
  }

  /// Sign in with Google
  Future<AuthResult> signInWithGoogle() async {
    final l10n = await _getL10n();
    try {
      if (kIsWeb) {
        // For web, check if we have proper configuration
        if (kDebugMode) {}

        // Try to sign in silently first (recommended for web)
        GoogleSignInAccount? googleUser = await _googleSignIn.signInSilently();

        // If no silent sign-in, trigger the sign-in flow
        if (googleUser == null) {
          if (kDebugMode) {}
          googleUser = await _googleSignIn.signIn();
        }

        // If the user cancels the sign in process
        if (googleUser == null) {
          return AuthResult.error(l10n.authGoogleSignInCancelled);
        }

        // Get the authentication details
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        if (kDebugMode) {}

        // Create Firebase credential
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Sign in to Firebase with the Google credentials
        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );

        if (kDebugMode) {}

        // Sync trial status from Firestore after successful sign-in
        await _syncUserDataAfterSignIn();

        await _setPersistedSession(userCredential.user != null);

        return AuthResult.success(userCredential.user);
      } else {
        // For mobile platforms, use the standard flow
        // Sign out from any existing Google account first
        await _googleSignIn.signOut();

        // Trigger the Google Sign In flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

        // If the user cancels the sign in process
        if (googleUser == null) {
          return AuthResult.error(l10n.authGoogleSignInCancelled);
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

        if (kDebugMode) {}

        // Sync trial status from Firestore after successful sign-in
        await _syncUserDataAfterSignIn();

        await _setPersistedSession(userCredential.user != null);

        return AuthResult.success(userCredential.user);
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {}
      return AuthResult.error(_getAuthErrorMessage(e, l10n));
    } catch (e) {
      if (kDebugMode) {}

      // Handle specific Google Sign-In errors
      if (e is PlatformException) {
        switch (e.code) {
          case 'sign_in_failed':
            // This is often error code 10 (DEVELOPER_ERROR)
            if (e.message?.contains('10') ?? false) {
              return AuthResult.error(
                l10n.authGoogleConfigErrorDetails(e.message ?? l10n.unknown),
              );
            }
            return AuthResult.error(l10n.authGoogleSignInFailedCheckConnection);
          case 'network_error':
            return AuthResult.error(l10n.authNetworkErrorGoogleSignIn);
          case 'sign_in_canceled':
            return AuthResult.error(l10n.authGoogleSignInCancelled);
          case 'sign_in_required':
            return AuthResult.error(l10n.authGoogleSignInRequired);
          default:
            return AuthResult.error(
              l10n.authGoogleSignInErrorDetails(e.message ?? l10n.unknown),
            );
        }
      }

      final errorMessage = e.toString();
      if (errorMessage.contains('CLIENT_ID_REQUIRED') ||
          errorMessage.contains('invalid_client') ||
          errorMessage.contains('401')) {
        return AuthResult.error(l10n.authGoogleSignInNotConfigured);
      }

      return AuthResult.error(l10n.authGoogleSignInFailedTryAgain);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      // Sign out from both Firebase and Google
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
      await _setPersistedSession(false);

      if (kDebugMode) {}
    } catch (e) {
      if (kDebugMode) {}
      rethrow;
    }
  }

  /// Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    final l10n = await _getL10n();
    try {
      if (!_isValidEmail(email)) {
        return AuthResult.error(l10n.enterValidEmail);
      }

      await _auth.sendPasswordResetEmail(email: email.trim());

      if (kDebugMode) {}

      return AuthResult.success(null, message: l10n.authPasswordResetEmailSent);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {}
      return AuthResult.error(_getAuthErrorMessage(e, l10n));
    } catch (e) {
      if (kDebugMode) {}
      return AuthResult.error(l10n.authUnexpectedErrorTryAgain);
    }
  }

  /// Resend email verification
  Future<AuthResult> resendEmailVerification() async {
    final l10n = await _getL10n();
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.error(l10n.authNoUserSignedIn);
      }

      if (user.emailVerified) {
        return AuthResult.error(l10n.authEmailAlreadyVerified);
      }

      await user.sendEmailVerification();

      if (kDebugMode) {}

      return AuthResult.success(null, message: l10n.authVerificationEmailSent);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {}
      return AuthResult.error(_getAuthErrorMessage(e, l10n));
    } catch (e) {
      if (kDebugMode) {}
      return AuthResult.error(l10n.authUnexpectedErrorTryAgain);
    }
  }

  /// Reload user to check email verification status
  Future<void> reloadUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      if (kDebugMode) {}
    }
  }

  /// Delete user account
  Future<AuthResult> deleteAccount() async {
    final l10n = await _getL10n();
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return AuthResult.error(l10n.authNoUserSignedIn);
      }

      await user.delete();
      await _setPersistedSession(false);

      if (kDebugMode) {}

      return AuthResult.success(null, message: l10n.authAccountDeletedSuccess);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {}
      return AuthResult.error(_getAuthErrorMessage(e, l10n));
    } catch (e) {
      if (kDebugMode) {}
      return AuthResult.error(l10n.authUnexpectedErrorTryAgain);
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  /// Validate password strength
  String? _validatePassword(String password, AppLocalizations l10n) {
    if (password.isEmpty) {
      return l10n.enterPassword;
    }
    if (password.length < 6) {
      return l10n.passwordTooShort;
    }
    if (password.length > 128) {
      return l10n.authPasswordTooLong;
    }

    // Check for at least one letter and one number
    final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);

    if (!hasLetter || !hasNumber) {
      return l10n.authPasswordMustContainLetterAndNumber;
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

      if (kDebugMode) {}
    } catch (e) {
      if (kDebugMode) {}
      // Don't throw error to avoid disrupting sign-in flow
    }
  }

  /// Convert Firebase Auth errors to user-friendly messages
  String _getAuthErrorMessage(FirebaseAuthException e, AppLocalizations l10n) {
    switch (e.code) {
      case 'email-already-in-use':
        return l10n.authEmailAlreadyInUse;
      case 'invalid-email':
        return l10n.enterValidEmail;
      case 'operation-not-allowed':
        return l10n.authEmailPasswordNotEnabled;
      case 'weak-password':
        return l10n.authChooseStrongerPassword;
      case 'user-disabled':
        return l10n.authAccountDisabled;
      case 'user-not-found':
        return l10n.authUserNotFound;
      case 'wrong-password':
        return l10n.authWrongPassword;
      case 'invalid-credential':
        return l10n.authInvalidCredentials;
      case 'too-many-requests':
        return l10n.authTooManyRequests;
      case 'network-request-failed':
        return l10n.authNetworkError;
      case 'requires-recent-login':
        return l10n.authRequiresRecentLogin;
      case 'invalid-verification-code':
        return l10n.authInvalidVerificationCode;
      case 'invalid-verification-id':
        return l10n.authInvalidVerificationId;
      case 'credential-already-in-use':
        return l10n.authCredentialAlreadyInUse;
      case 'account-exists-with-different-credential':
        return l10n.authAccountExistsWithDifferentCredential;
      default:
        if (kDebugMode) {}
        return e.message ?? l10n.authGenericError;
    }
  }

  Future<AppLocalizations> _getL10n() async {
    final locale = PlatformDispatcher.instance.locale;
    try {
      return await AppLocalizations.delegate.load(locale);
    } catch (_) {
      return await AppLocalizations.delegate.load(const Locale('en'));
    }
  }

  Future<bool> hadPersistedSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_persistedSessionKey) ?? false;
  }

  Future<void> _setPersistedSession(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_persistedSessionKey, value);
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
