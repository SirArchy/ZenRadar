// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/matcha_product.dart';
import '../services/notification_service.dart';
import '../services/background_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import '../services/cloud_crawler_service.dart';
import '../widgets/matcha_icon.dart';
import '../widgets/app_mode_selection_dialog.dart';
import 'website_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Contact/social launchers
  Future<void> _launchGitHub() async {
    final Uri githubUri = Uri.parse('https://github.com/SirArchy');
    if (await canLaunchUrl(githubUri)) {
      await launchUrl(githubUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchLinkedIn() async {
    final Uri linkedinUri = Uri.parse(
      'https://www.linkedin.com/in/fabian-e-762b85244',
    );
    if (await canLaunchUrl(linkedinUri)) {
      await launchUrl(linkedinUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPayPal() async {
    final Uri paypalUri = Uri.parse('https://www.paypal.me/FEbert353');
    if (await canLaunchUrl(paypalUri)) {
      await launchUrl(paypalUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchBuyMeACoffee() async {
    final Uri coffeeUri = Uri.parse('https://ko-fi.com/sirarchy');
    if (await canLaunchUrl(coffeeUri)) {
      await launchUrl(coffeeUri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSocialButton(Widget icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(32),
          child: icon,
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  UserSettings _settings = UserSettings();
  bool _isLoading = true;
  bool _isServiceRunning = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    if (!kIsWeb) {
      _checkServiceStatus();
    }
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

  void _updateSettings(UserSettings Function(UserSettings) updater) async {
    setState(() {
      _settings = updater(_settings);
    });

    // Auto-save settings immediately
    try {
      await SettingsService.instance.saveSettings(_settings);
      // Notify background service of settings update
      await BackgroundServiceController.instance.updateSettings();
    } catch (e) {
      _showErrorSnackBar('Failed to save settings: $e');
    }
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
        title: Row(
          children: [
            const MatchaIcon(size: 20, withSteam: false),
            const SizedBox(width: 8),
            const Text('Settings'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // App Mode Settings
          Card(
            color: Colors.blue.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _settings.appMode == 'server'
                            ? Icons.cloud
                            : Icons.phone_android,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Operation Mode',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color:
                          _settings.appMode == 'server'
                              ? Colors.blue.shade100
                              : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _settings.appMode == 'server'
                                ? Colors.blue
                                : Colors.green,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _settings.appMode == 'server'
                              ? Icons.cloud_done
                              : Icons.smartphone,
                          color:
                              _settings.appMode == 'server'
                                  ? Colors.blue
                                  : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _settings.appMode == 'server'
                                    ? 'Server Mode Active'
                                    : 'Local Mode Active',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      _settings.appMode == 'server'
                                          ? Colors.blue.shade700
                                          : Colors.green.shade700,
                                ),
                              ),
                              Text(
                                _settings.appMode == 'server'
                                    ? 'Cloud monitoring • Zero battery usage'
                                    : 'Device monitoring • Full privacy control',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      _settings.appMode == 'server'
                                          ? Colors.blue.shade600
                                          : Colors.green.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Only show mode change button on mobile platforms
                  if (!kIsWeb)
                    ElevatedButton.icon(
                      onPressed: _showModeSelectionDialog,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Change Mode'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  // Show web mode indicator instead of change button
                  if (kIsWeb)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.web, color: Colors.blue.shade600),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Web version automatically uses server mode for optimal performance',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Cloud Integration (server mode only)
          if (_settings.appMode == 'server')
            Card(
              color: Colors.purple.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.cloud_sync, color: Colors.purple),
                        const SizedBox(width: 8),
                        const Text(
                          'Cloud Integration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildCloudStatusCard(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _triggerManualCrawl,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Manual Crawl'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _checkServerHealth,
                          icon: const Icon(Icons.health_and_safety),
                          label: const Text('Health'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

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

          const SizedBox(height: 16),

          // Monitoring Settings (mobile only and mode-dependent)
          if (!kIsWeb)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _settings.appMode == 'server'
                          ? 'Server Monitoring'
                          : 'Local Monitoring',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_settings.appMode == 'server') ...[
                      // Server mode information
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.cloud_sync, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'Cloud Monitoring Active',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '• Websites monitored every 30 minutes\n'
                              '• 24/7 cloud-based scanning\n'
                              '• Automatic data synchronization\n'
                              '• Zero impact on device battery',
                              style: TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Local mode controls (existing functionality)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color:
                              _isServiceRunning
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                _isServiceRunning
                                    ? Colors.green
                                    : Colors.orange,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isServiceRunning
                                  ? Icons.check_circle
                                  : Icons.warning,
                              color:
                                  _isServiceRunning
                                      ? Colors.green
                                      : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _isServiceRunning
                                    ? 'Background monitoring is active'
                                    : 'Background monitoring is paused',
                                style: TextStyle(
                                  color:
                                      _isServiceRunning
                                          ? Colors.green.shade700
                                          : Colors.orange.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _toggleBackgroundService,
                              child: Text(_isServiceRunning ? 'Stop' : 'Start'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        title: const Text('Check Frequency'),
                        subtitle: DropdownButton<int>(
                          value: _settings.checkFrequencyMinutes,
                          isExpanded: true,
                          underline: Container(),
                          items:
                              _getFrequencyOptions().map((option) {
                                return DropdownMenuItem<int>(
                                  value: option['value'] as int,
                                  child: Text(option['label'] as String),
                                );
                              }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              _updateSettings(
                                (settings) => settings.copyWith(
                                  checkFrequencyMinutes: value,
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        title: const Text('Active Hours'),
                        subtitle: FutureBuilder<bool>(
                          future:
                              SettingsService.instance.isWithinActiveHours(),
                          builder: (context, snapshot) {
                            final isWithinHours = snapshot.data ?? false;
                            final status =
                                isWithinHours
                                    ? 'Currently active'
                                    : 'Currently paused';
                            final statusColor =
                                isWithinHours ? Colors.green : Colors.orange;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_settings.startTime} - ${_settings.endTime}',
                                ),
                                Text(
                                  status,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        trailing: const Icon(Icons.edit),
                        onTap: () => _showActiveHoursDialog(),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: const Text('Background Scan Mode'),
                        subtitle: Text(
                          _settings.backgroundScanFavoritesOnly
                              ? 'Only scan favorite products in background'
                              : 'Scan all products in background',
                        ),
                        value: _settings.backgroundScanFavoritesOnly,
                        onChanged: (value) {
                          _updateSettings(
                            (s) =>
                                s.copyWith(backgroundScanFavoritesOnly: value),
                          );
                        },
                        secondary: Icon(
                          _settings.backgroundScanFavoritesOnly
                              ? Icons.favorite
                              : Icons.public,
                          color:
                              _settings.backgroundScanFavoritesOnly
                                  ? Colors.red
                                  : Colors.blue,
                        ),
                      ),
                      if (_settings.backgroundScanFavoritesOnly)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            'When enabled, background scans will only monitor your favorite products. This saves battery and provides faster scans. Add favorites by tapping ♡ on products.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          // Site Settings (mode-dependent)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _settings.appMode == 'server'
                        ? 'Monitored Sites (Server)'
                        : 'Monitored Sites',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (_settings.appMode == 'server') ...[
                    // Server mode: Show available sites info and suggestion form
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'Server-Monitored Websites',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            'All supported matcha websites are automatically monitored by our servers. Data is synchronized to your device regularly.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Show current monitored sites with product counts
                    ..._getBuiltInSites().map(
                      (site) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              Icons.language,
                              size: 16,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                site['name']!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Text(
                              '~50 products', // Placeholder - would come from server
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Divider(),

                    // Suggestion form
                    ListTile(
                      leading: const Icon(Icons.add_link),
                      title: const Text('Suggest New Website'),
                      subtitle: const Text(
                        'Request monitoring for additional matcha sites',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _showWebsiteSuggestionDialog,
                    ),
                  ] else ...[
                    // Local mode: Show current controls
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: const Text('Built-in Websites'),
                      subtitle: Text(
                        '${_settings.enabledSites.where((site) => _getBuiltInSites().any((builtIn) => builtIn['key'] == site)).length} of ${_getBuiltInSites().length} enabled',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _showBuiltInWebsitesDialog(),
                    ),
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
                            builder:
                                (context) => const WebsiteManagementScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Display Settings
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Display Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.palette),
                    title: const Text('Theme'),
                    subtitle: Text(
                      'Current: ${ThemeService.instance.getThemeModeDisplayName(ThemeService.instance.themeMode)}',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _showThemeDialog(),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.attach_money),
                    title: const Text('Preferred Currency'),
                    subtitle: Text(
                      'Show prices in ${_settings.preferredCurrency}',
                    ),
                    trailing: const Icon(Icons.edit),
                    onTap: () => _showCurrencyDialog(),
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
                      'Nakamura Tokichi, Marukyu-Koyamaen, Ippodo Tea,\nYoshi En, Matcha Kāru, Sho-Cha, Sazen Tea,\nMamecha, Emeri, Poppatea + Custom websites',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Debug Section (for testing background service - local mode only)
          if (!kIsWeb && _settings.appMode == 'local')
            Card(
              color: Colors.orange.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bug_report, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Debug Tools',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Use these tools to test background service functionality:',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          _showSuccessSnackBar('Testing background service...');
                          await BackgroundServiceController.instance
                              .triggerManualCheck();
                          _showSuccessSnackBar('Manual check triggered');
                        } catch (e) {
                          _showErrorSnackBar('Failed to trigger check: $e');
                        }
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Trigger Manual Check'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final isRunning =
                              await BackgroundServiceController.instance
                                  .isServiceRunning();
                          _showSuccessSnackBar('Service running: $isRunning');
                        } catch (e) {
                          _showErrorSnackBar('Failed to check service: $e');
                        }
                      },
                      icon: const Icon(Icons.info),
                      label: const Text('Check Service Status'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          _showSuccessSnackBar(
                            'Restarting background service...',
                          );
                          await BackgroundServiceController.instance
                              .stopService();
                          await Future.delayed(const Duration(seconds: 2));
                          await BackgroundServiceController.instance
                              .startService();
                          _showSuccessSnackBar('Service restarted');
                        } catch (e) {
                          _showErrorSnackBar('Failed to restart service: $e');
                        }
                      },
                      icon: const Icon(Icons.restart_alt),
                      label: const Text('Restart Service'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Contact Section
          Card(
            margin: const EdgeInsets.only(top: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Contact Me'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        const Icon(
                          Icons.contact_mail,
                          size: 44,
                          color: Colors.blueGrey,
                        ),
                        'Contact',
                        () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => AlertDialog(
                                  title: const Text('Contact'),
                                  content: const Text(
                                    'Feel free to reach out via email, GitHub, LinkedIn, PayPal, or BuyMeACoffee!',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildSocialButton(
                        const Icon(Icons.email, size: 44, color: Colors.teal),
                        'Email',
                        () async {
                          final Uri emailUri = Uri(
                            scheme: 'mailto',
                            path: 'fabian.ebert@online.de',
                            query: 'subject=ZenRadar Feedback',
                          );
                          if (await canLaunchUrl(emailUri)) {
                            await launchUrl(
                              emailUri,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Could not open email app.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildSocialButton(
                        const Icon(Icons.code, size: 44, color: Colors.black87),
                        'GitHub',
                        _launchGitHub,
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildSocialButton(
                        const Icon(
                          Icons.business,
                          size: 44,
                          color: Colors.blueAccent,
                        ),
                        'LinkedIn',
                        _launchLinkedIn,
                      ),
                      const SizedBox(width: 16),
                      _buildSocialButton(
                        const Icon(
                          Icons.attach_money,
                          size: 44,
                          color: Colors.green,
                        ),
                        'PayPal',
                        _launchPayPal,
                      ),
                      const SizedBox(width: 16),
                      _buildSocialButton(
                        const Icon(
                          Icons.local_cafe,
                          size: 44,
                          color: Colors.brown,
                        ),
                        'BuyMeACoffee',
                        _launchBuyMeACoffee,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _getBuiltInSites() {
    return [
      {
        'key': 'tokichi',
        'name': 'Nakamura Tokichi',
        'url': 'global.tokichi.jp',
      },
      {
        'key': 'marukyu',
        'name': 'Marukyu-Koyamaen',
        'url': 'marukyu-koyamaen.co.jp',
      },
      {'key': 'ippodo', 'name': 'Ippodo Tea', 'url': 'global.ippodo-tea.co.jp'},
      {'key': 'yoshien', 'name': 'Yoshi En', 'url': 'yoshien.co.jp'},
      {'key': 'matcha-karu', 'name': 'Matcha Kāru', 'url': 'matchakaru.com'},
      {'key': 'sho-cha', 'name': 'Sho-Cha', 'url': 'sho-cha.com'},
      {'key': 'sazentea', 'name': 'Sazen Tea', 'url': 'sazentea.com'},
      {'key': 'mamecha', 'name': 'Mamecha', 'url': 'mamecha.co.jp'},
      {'key': 'enjoyemeri', 'name': 'Emeri', 'url': 'enjoyemeri.com'},
      {'key': 'poppatea', 'name': 'Poppatea', 'url': 'poppatea.com'},
    ];
  }

  List<Map<String, dynamic>> _getFrequencyOptions() {
    List<Map<String, dynamic>> options = [];

    // Quick monitoring options (minutes)
    for (int minutes in [10, 15, 30, 45]) {
      options.add({'value': minutes, 'label': 'Every $minutes minutes'});
    }

    // Hour-based options (converted to minutes)
    for (int hours in [1, 2, 4, 6, 8, 12, 24]) {
      int minutes = hours * 60;
      options.add({
        'value': minutes,
        'label': 'Every $hours hour${hours == 1 ? '' : 's'}',
      });
    }

    return options;
  }

  void _showBuiltInWebsitesDialog() {
    final sites = _getBuiltInSites();

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.language),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Built-in Matcha Websites',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Enable or disable monitoring for built-in matcha websites:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: sites.length,
                            itemBuilder: (context, index) {
                              final site = sites[index];
                              final isEnabled = _settings.enabledSites.contains(
                                site['key'],
                              );

                              return SwitchListTile(
                                title: Text(site['name']!),
                                subtitle: Text(
                                  site['url']!,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                                value: isEnabled,
                                onChanged: (value) {
                                  _updateSettings((settings) {
                                    List<String> newEnabledSites = List.from(
                                      settings.enabledSites,
                                    );
                                    if (value) {
                                      if (!newEnabledSites.contains(
                                        site['key'],
                                      )) {
                                        newEnabledSites.add(site['key']!);
                                      }
                                    } else {
                                      newEnabledSites.remove(site['key']);
                                    }
                                    return settings.copyWith(
                                      enabledSites: newEnabledSites,
                                    );
                                  });
                                  setDialogState(() {}); // Update dialog state
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        // Enable all sites
                        _updateSettings((settings) {
                          final allSiteKeys =
                              sites.map((site) => site['key']!).toList();
                          List<String> newEnabledSites = List.from(
                            settings.enabledSites,
                          );
                          for (final key in allSiteKeys) {
                            if (!newEnabledSites.contains(key)) {
                              newEnabledSites.add(key);
                            }
                          }
                          return settings.copyWith(
                            enabledSites: newEnabledSites,
                          );
                        });
                        setDialogState(() {});
                      },
                      child: const Text('Enable All'),
                    ),
                    TextButton(
                      onPressed: () {
                        // Disable all built-in sites
                        _updateSettings((settings) {
                          final allSiteKeys =
                              sites.map((site) => site['key']!).toList();
                          List<String> newEnabledSites = List.from(
                            settings.enabledSites,
                          );
                          newEnabledSites.removeWhere(
                            (key) => allSiteKeys.contains(key),
                          );
                          return settings.copyWith(
                            enabledSites: newEnabledSites,
                          );
                        });
                        setDialogState(() {});
                      },
                      child: const Text('Disable All'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showCurrencyDialog() {
    const currencies = [
      {'code': 'EUR', 'name': 'Euro (€)', 'symbol': '€'},
      {'code': 'USD', 'name': 'US Dollar (\$)', 'symbol': '\$'},
      {'code': 'JPY', 'name': 'Japanese Yen (¥)', 'symbol': '¥'},
      {'code': 'GBP', 'name': 'British Pound (£)', 'symbol': '£'},
      {'code': 'CHF', 'name': 'Swiss Franc (CHF)', 'symbol': 'CHF'},
      {'code': 'CAD', 'name': 'Canadian Dollar (CAD)', 'symbol': 'CAD'},
      {'code': 'AUD', 'name': 'Australian Dollar (AUD)', 'symbol': 'AUD'},
    ];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Preferred Currency'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select your preferred currency for price display:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children:
                          currencies.map((currency) {
                            return RadioListTile<String>(
                              title: Text(currency['name']!),
                              value: currency['code']!,
                              groupValue: _settings.preferredCurrency,
                              onChanged: (value) {
                                _updateSettings(
                                  (settings) => settings.copyWith(
                                    preferredCurrency: value!,
                                  ),
                                );
                                Navigator.pop(context);
                                _showSuccessSnackBar(
                                  'Currency updated to ${currency['name']}',
                                );
                              },
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Theme'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose your preferred theme:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children:
                          ThemeService.instance.availableThemeModes.map((mode) {
                            String description;
                            IconData icon;

                            switch (mode) {
                              case AppThemeMode.light:
                                description = 'Always use light theme';
                                icon = Icons.light_mode;
                                break;
                              case AppThemeMode.dark:
                                description = 'Always use dark theme';
                                icon = Icons.dark_mode;
                                break;
                              case AppThemeMode.system:
                                description = 'Follow system setting';
                                icon = Icons.settings_system_daydream;
                                break;
                            }

                            return RadioListTile<AppThemeMode>(
                              title: Row(
                                children: [
                                  Icon(icon, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    ThemeService.instance
                                        .getThemeModeDisplayName(mode),
                                  ),
                                ],
                              ),
                              subtitle: Text(description),
                              value: mode,
                              groupValue: ThemeService.instance.themeMode,
                              onChanged: (value) async {
                                if (value != null) {
                                  await ThemeService.instance.setThemeMode(
                                    value,
                                  );
                                  Navigator.pop(context);
                                  _showSuccessSnackBar(
                                    'Theme updated to ${ThemeService.instance.getThemeModeDisplayName(value)}',
                                  );
                                  // Force rebuild to update the subtitle
                                  setState(() {});
                                }
                              },
                            );
                          }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
    );
  }

  void _showActiveHoursDialog() {
    TimeOfDay startTime = _parseTimeOfDay(_settings.startTime);
    TimeOfDay endTime = _parseTimeOfDay(_settings.endTime);

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Active Hours'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Set the hours when background monitoring should be active.\n'
                        'Outside these hours, no stock checks will be performed.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          const Text('Start: '),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                                builder: (context, child) {
                                  return MediaQuery(
                                    data: MediaQuery.of(
                                      context,
                                    ).copyWith(alwaysUse24HourFormat: true),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  startTime = picked;
                                });
                              }
                            },
                            child: Text(_formatTimeOfDay(startTime)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('End:   '),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                                builder: (context, child) {
                                  return MediaQuery(
                                    data: MediaQuery.of(
                                      context,
                                    ).copyWith(alwaysUse24HourFormat: true),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  endTime = picked;
                                });
                              }
                            },
                            child: Text(_formatTimeOfDay(endTime)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_isTimesOverlapping(startTime, endTime))
                        const Text(
                          'Note: End time is before start time, monitoring will span overnight.',
                          style: TextStyle(fontSize: 12, color: Colors.orange),
                        ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final newStartTime = _formatTimeOfDay(startTime);
                        final newEndTime = _formatTimeOfDay(endTime);

                        _updateSettings(
                          (settings) => settings.copyWith(
                            startTime: newStartTime,
                            endTime: newEndTime,
                          ),
                        );

                        await SettingsService.instance.setActiveHours(
                          newStartTime,
                          newEndTime,
                        );

                        // Notify background service of settings change
                        if (!kIsWeb) {
                          await BackgroundServiceController.instance
                              .updateSettings();
                        }

                        Navigator.pop(context);
                        _showSuccessSnackBar('Active hours updated');
                      },
                      child: const Text('Save'),
                    ),
                  ],
                ),
          ),
    );
  }

  TimeOfDay _parseTimeOfDay(String timeString) {
    final parts = timeString.split(':');
    if (parts.length == 2) {
      try {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      } catch (e) {
        // Invalid format, return default
      }
    }
    return const TimeOfDay(hour: 8, minute: 0);
  }

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  bool _isTimesOverlapping(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return endMinutes <= startMinutes;
  }

  Future<void> _checkServiceStatus() async {
    try {
      bool isRunning =
          await BackgroundServiceController.instance.isServiceRunning();
      setState(() {
        _isServiceRunning = isRunning;
      });
    } catch (e) {
      // Service status check failed, assume it's not running
      setState(() {
        _isServiceRunning = false;
      });
    }
  }

  Future<void> _toggleBackgroundService() async {
    try {
      if (_isServiceRunning) {
        await BackgroundServiceController.instance.stopService();
        _showSuccessSnackBar('Background monitoring stopped');
      } else {
        await BackgroundServiceController.instance.startService();
        _showSuccessSnackBar('Background monitoring started');
      }
      await _checkServiceStatus();
    } catch (e) {
      _showErrorSnackBar('Failed to toggle service: $e');
    }
  }

  void _showModeSelectionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AppModeSelectionDialog(
            isInitialSetup: false,
            onModeSelected: (mode) {
              setState(() {
                _settings = _settings.copyWith(appMode: mode);
              });
            },
          ),
    );
  }

  void _showWebsiteSuggestionDialog() {
    final TextEditingController urlController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_link, color: Colors.blue),
                SizedBox(width: 8),
                Text('Suggest Website'),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Suggest a matcha website to be added to our server monitoring:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Website Name',
                      hintText: 'e.g., "Premium Matcha Store"',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: urlController,
                    decoration: const InputDecoration(
                      labelText: 'Website URL',
                      hintText: 'https://example.com',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (Optional)',
                      hintText: 'Why should this site be monitored?',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (urlController.text.isNotEmpty &&
                      nameController.text.isNotEmpty) {
                    // TODO: Send suggestion to server
                    Navigator.pop(context);
                    _showSuccessSnackBar(
                      'Website suggestion submitted for review',
                    );
                  } else {
                    _showErrorSnackBar(
                      'Please fill in the website name and URL',
                    );
                  }
                },
                child: const Text('Submit'),
              ),
            ],
          ),
    );
  }

  // Cloud Integration Methods
  ServerHealthStatus? _serverHealth;
  String? _lastCrawlRequestId;

  Widget _buildCloudStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color:
            _serverHealth?.isHealthy == true
                ? Colors.green.shade100
                : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              _serverHealth?.isHealthy == true ? Colors.green : Colors.orange,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _serverHealth?.isHealthy == true
                    ? Icons.cloud_done
                    : Icons.cloud_off,
                color:
                    _serverHealth?.isHealthy == true
                        ? Colors.green
                        : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                _serverHealth?.isHealthy == true
                    ? 'Server Online'
                    : 'Server Status Unknown',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (_serverHealth?.message != null) ...[
            const SizedBox(height: 4),
            Text(
              _serverHealth!.message,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
          if (_lastCrawlRequestId != null) ...[
            const SizedBox(height: 4),
            Text(
              'Last Request: $_lastCrawlRequestId',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _triggerManualCrawl() async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => const AlertDialog(
              content: Row(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(width: 16),
                  Text('Triggering crawl...'),
                ],
              ),
            ),
      );

      final requestId = await CloudCrawlerService.instance.triggerManualCrawl(
        sites: ['tokichi', 'marukyu', 'ippodo'], // Default sites
        userId: 'flutter-user-${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() {
        _lastCrawlRequestId = requestId;
      });

      // Close loading dialog
      Navigator.of(context).pop();

      _showSuccessSnackBar('Crawl triggered successfully: $requestId');
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      _showErrorSnackBar('Failed to trigger crawl: $e');
    }
  }

  Future<void> _checkServerHealth() async {
    try {
      final health = await CloudCrawlerService.instance.checkServerHealth();
      setState(() {
        _serverHealth = health;
      });

      _showSuccessSnackBar(
        health.isHealthy ? 'Server is healthy' : 'Server status checked',
      );
    } catch (e) {
      setState(() {
        _serverHealth = ServerHealthStatus(
          isHealthy: false,
          lastCrawlTime: null,
          recentCrawlCount: 0,
          message: 'Error checking server: $e',
        );
      });
      _showErrorSnackBar('Failed to check server health: $e');
    }
  }
}
