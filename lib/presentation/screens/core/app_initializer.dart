// ignore_for_file: avoid_print

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:zenradar/presentation/screens/onboarding/onboarding_screen_new.dart';
import 'package:zenradar/data/services/settings/settings_service.dart';
import 'package:zenradar/data/services/auth/auth_service.dart';
import 'package:zenradar/data/services/subscription/subscription_service.dart';
import 'package:zenradar/presentation/screens/navigation/main_screen.dart';
import 'package:zenradar/presentation/screens/auth/auth_screen.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _needsOnboarding = false;
  bool _needsAuth = false;
  String _loadingText = '';

  @override
  void initState() {
    super.initState();
    _checkInitialSetup();
  }

  Future<void> _checkInitialSetup() async {
    if (mounted) {
      setState(() {
        _loadingText = 'Checking setup...';
      });
    }

    bool hasCompletedOnboarding = true;
    try {
      hasCompletedOnboarding =
          await SettingsService.instance.hasCompletedOnboarding();
    } catch (e) {
      // Avoid forcing onboarding on transient startup failures.
      hasCompletedOnboarding = true;
    }

    if (!hasCompletedOnboarding) {
      if (!mounted) {
        return;
      }
      setState(() {
        _needsOnboarding = true;
        _isLoading = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _loadingText = 'Verifying authentication...';
      });
    }

    try {
      final authService = AuthService.instance;
      final hadPersistedSession = await authService.hadPersistedSession();

      User? restoredUser = authService.currentUser;
      restoredUser ??= await _waitForRestoredUser(
        authService,
        timeout:
            hadPersistedSession
                ? const Duration(seconds: 3)
                : const Duration(milliseconds: 800),
      );

      if (restoredUser == null) {
        if (hadPersistedSession) {
          // Avoid repeated long waits on future app starts when no session exists.
          await authService.clearPersistedSessionHint();
        }

        if (!mounted) {
          return;
        }
        setState(() {
          _needsAuth = true;
          _isLoading = false;
        });
        return;
      }

      if (mounted) {
        setState(() {
          _loadingText = 'Almost ready...';
        });
      }

      try {
        await SubscriptionService.instance.isPremiumUser();
      } catch (e) {
        // Continue with app initialization even if sync fails.
      }

      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _needsAuth = true;
        _isLoading = false;
      });
    }
  }

  Future<User?> _waitForRestoredUser(
    AuthService authService, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      final user = authService.currentUser;
      if (user != null) {
        return user;
      }

      await Future.delayed(const Duration(milliseconds: 250));
    }

    return authService.currentUser;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _loadingText.isEmpty && l10n != null
                    ? l10n.startingZenRadar
                    : _loadingText,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n?.pleaseWait ?? 'Please wait...',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_needsOnboarding) {
      return const OnboardingScreen();
    }

    if (_needsAuth) {
      return AuthScreen(
        onAuthSuccess: () {
          setState(() {
            _needsAuth = false;
          });
        },
        onSkip: () {
          setState(() {
            _needsAuth = false;
          });
        },
      );
    }

    return const MainScreen();
  }
}
