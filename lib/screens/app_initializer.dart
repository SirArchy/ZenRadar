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

  @override
  void initState() {
    super.initState();
    _checkInitialSetup();
  }

  Future<void> _checkInitialSetup() async {
    try {
      final settings = await SettingsService.instance.getSettings();

      // Check if this is a first-time user (simplified logic)
      // In server mode, we just check if settings exist and are properly configured
      if (settings.enabledSites.isEmpty) {
        setState(() {
          _needsOnboarding = true;
          _isLoading = false;
        });
        return;
      }

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
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Initializing ZenRadar...'),
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
