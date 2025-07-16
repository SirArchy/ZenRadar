// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/matcha_product.dart';
import '../services/notification_service.dart';
import '../services/background_service.dart';
import '../services/settings_service.dart';
import 'website_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserSettings _settings = UserSettings();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.instance.getSettings();
      setState(() {
        _settings = settings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    try {
      await SettingsService.instance.saveSettings(_settings);

      // Notify background service of settings update
      await BackgroundServiceController.instance.updateSettings();

      _showSuccessSnackBar('Settings saved successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to save settings: $e');
    }
  }

  void _updateSettings(UserSettings Function(UserSettings) updater) {
    setState(() {
      _settings = updater(_settings);
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveSettings),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Notification Settings (mobile only)
          if (!kIsWeb)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      title: const Text('Enable Notifications'),
                      subtitle: const Text(
                        'Receive alerts when products come back in stock',
                      ),
                      value: _settings.notificationsEnabled,
                      onChanged: (value) {
                        _updateSettings(
                          (s) => s.copyWith(notificationsEnabled: value),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      title: const Text('Test Notification'),
                      subtitle: const Text('Send a test notification'),
                      trailing: const Icon(Icons.send),
                      onTap: () async {
                        await NotificationService.instance
                            .showTestNotification();
                        _showSuccessSnackBar('Test notification sent');
                      },
                    ),
                  ],
                ),
              ),
            ),

          if (!kIsWeb) const SizedBox(height: 16),

          // Debug Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Debug Mode',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Head Mode'),
                    subtitle: const Text(
                      'Show crawler activity and progress in real-time',
                    ),
                    value: _settings.headModeEnabled,
                    onChanged: (value) {
                      _updateSettings(
                        (s) => s.copyWith(headModeEnabled: value),
                      );
                    },
                  ),
                  if (_settings.headModeEnabled) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border: Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Head mode shows detailed crawler activity. This may impact performance.',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Monitoring Settings (mobile only)
          if (!kIsWeb)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monitoring',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Check Frequency'),
                      subtitle: Text(
                        'Every ${_settings.checkFrequencyHours} hours',
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _showFrequencyDialog(),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text('Active Hours'),
                      subtitle: Text(
                        '${_settings.startTime} - ${_settings.endTime}',
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _showActiveHoursDialog(),
                    ),
                  ],
                ),
              ),
            ),

          if (!kIsWeb) const SizedBox(height: 16),

          // Site Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Monitored Sites',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ..._buildSiteToggles(),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.web),
                    title: const Text('Manage Custom Websites'),
                    subtitle: const Text(
                      'Add and configure custom websites to monitor',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const WebsiteManagementScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // About Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const ListTile(
                    leading: Icon(Icons.info),
                    title: Text('ZenRadar'),
                    subtitle: Text(
                      'Matcha stock monitoring app\nVersion 1.0.0',
                    ),
                  ),
                  const ListTile(
                    leading: Icon(Icons.language),
                    title: Text('Monitored Sites'),
                    subtitle: Text(
                      'Tokichi Global, Marukyu-Koyamaen, Ippodo Tea',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSiteToggles() {
    const sites = [
      {'key': 'tokichi', 'name': 'Tokichi Global'},
      {'key': 'marukyu', 'name': 'Marukyu-Koyamaen'},
      {'key': 'ippodo', 'name': 'Ippodo Tea'},
    ];

    return sites.map((site) {
      bool isEnabled = _settings.enabledSites.contains(site['key']);
      return SwitchListTile(
        title: Text(site['name']!),
        value: isEnabled,
        onChanged: (value) {
          setState(() {
            List<String> newEnabledSites = List.from(_settings.enabledSites);
            if (value) {
              if (!newEnabledSites.contains(site['key'])) {
                newEnabledSites.add(site['key']!);
              }
            } else {
              newEnabledSites.remove(site['key']);
            }
            _settings = _settings.copyWith(enabledSites: newEnabledSites);
          });
        },
      );
    }).toList();
  }

  void _showFrequencyDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Check Frequency'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  [1, 2, 4, 6, 8, 12, 24].map((hours) {
                    return RadioListTile<int>(
                      title: Text('Every $hours hour${hours == 1 ? '' : 's'}'),
                      value: hours,
                      groupValue: _settings.checkFrequencyHours,
                      onChanged: (value) {
                        setState(() {
                          _settings = _settings.copyWith(
                            checkFrequencyHours: value!,
                          );
                        });
                        Navigator.pop(context);
                      },
                    );
                  }).toList(),
            ),
          ),
    );
  }

  void _showActiveHoursDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Active Hours'),
            content: const Text(
              'Feature coming soon!\nFor now, monitoring is active 24/7.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }
}
