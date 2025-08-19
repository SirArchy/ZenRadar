import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zenradar/screens/onboarding_screen_new.dart';
import '../services/settings_service.dart';
import 'home_screen.dart';

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  bool _needsModeSelection = false;

  @override
  void initState() {
    super.initState();
    _checkInitialSetup();
  }

  Future<void> _checkInitialSetup() async {
    try {
      final settings = await SettingsService.instance.getSettings();

      // For web users, automatically use server mode and skip mode selection
      if (kIsWeb) {
        if (settings.appMode.isEmpty || settings.appMode != 'server') {
          // Show onboarding for first-time web users
          setState(() {
            _needsModeSelection = true;
            _isLoading = false;
          });
          return;
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // For mobile users, check if this is a fresh install or if appMode is not set
      if (settings.appMode.isEmpty) {
        setState(() {
          _needsModeSelection = true;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      // If settings can't be loaded, always show onboarding
      setState(() {
        _needsModeSelection = true;
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

    if (_needsModeSelection) {
      return const OnboardingScreen();
    }

    return const HomeScreen();
  }
}
