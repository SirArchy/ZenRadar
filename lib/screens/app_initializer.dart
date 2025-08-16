import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../models/matcha_product.dart';
import '../widgets/app_mode_selection_dialog.dart';
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
          // Set server mode for web users
          final updatedSettings = settings.copyWith(appMode: 'server');
          await SettingsService.instance.saveSettings(updatedSettings);
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // For mobile users, check if this is a fresh install or if appMode is not set
      // For existing mobile users, default to local mode
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
      // If settings can't be loaded
      if (kIsWeb) {
        // For web, force server mode even if settings fail
        try {
          final defaultSettings = UserSettings().copyWith(appMode: 'server');
          await SettingsService.instance.saveSettings(defaultSettings);
          setState(() {
            _isLoading = false;
          });
        } catch (saveError) {
          // If we can't save settings, still continue with web defaults
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        // For mobile, show mode selection
        setState(() {
          _needsModeSelection = true;
          _isLoading = false;
        });
      }
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
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_cafe, size: 80, color: Colors.brown),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to ZenRadar!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your matcha stock monitoring companion',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                ElevatedButton.icon(
                  onPressed: _showModeSelection,
                  icon: const Icon(Icons.settings_applications),
                  label: const Text('Get Started'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    textStyle: const TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const HomeScreen();
  }

  void _showModeSelection() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissal
      builder:
          (context) => AppModeSelectionDialog(
            isInitialSetup: true,
            onModeSelected: (mode) {
              setState(() {
                _needsModeSelection = false;
              });
            },
          ),
    );
  }
}
