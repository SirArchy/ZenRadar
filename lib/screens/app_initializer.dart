// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:zenradar/screens/onboarding_screen_new.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import 'main_screen.dart';
import 'auth_screen.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _needsOnboarding = false;
  bool _needsAuth = false;
  String _loadingText = 'Starting ZenRadar...';

  @override
  void initState() {
    super.initState();
    _checkInitialSetup();
  }

  Future<void> _checkInitialSetup() async {
    try {
      setState(() {
        _loadingText = 'Checking setup...';
      });

      final settingsService = SettingsService.instance;

      // Check if this is a first-time user - use faster check if possible
      final hasCompletedOnboarding =
          await settingsService.hasCompletedOnboarding();

      if (!hasCompletedOnboarding) {
        setState(() {
          _needsOnboarding = true;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _loadingText = 'Verifying authentication...';
      });

      // Check authentication status
      final authService = AuthService.instance;
      if (!authService.isSignedIn) {
        setState(() {
          _needsAuth = true;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _loadingText = 'Almost ready...';
      });

      // Add small delay to prevent flash
      await Future.delayed(const Duration(milliseconds: 200));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error checking setup: $e');
      setState(() {
        _needsOnboarding = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _loadingText,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Please wait...',
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
