// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/matcha_product.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import '../services/favorite_notification_service.dart';
import '../services/notification_service.dart';
import '../widgets/matcha_icon.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  UserSettings _userSettings = UserSettings();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _userEmail;
  Map<String, int> _siteProductCounts = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAuthStatus();
    _loadSiteProductCounts();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.instance.getSettings();
      setState(() {
        _userSettings = settings;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAuthStatus() async {
    final authService = AuthService();
    final isLoggedIn = authService.isSignedIn;
    String? email;

    if (isLoggedIn) {
      final user = authService.currentUser;
      email = user?.email;
    }

    setState(() {
      _isLoggedIn = isLoggedIn;
      _userEmail = email;
    });
  }

  Future<void> _loadSiteProductCounts() async {
    try {
      final db = DatabaseService.platformService;
      final sites = _getBuiltInSites();
      final Map<String, int> counts = {};

      for (final site in sites) {
        final products = await db.getProductsBySite(site['key']!);
        counts[site['key']!] = products.length;
      }

      setState(() {
        _siteProductCounts = counts;
      });
    } catch (e) {
      print('Error loading site product counts: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      await SettingsService.instance.saveSettings(_userSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _updateSetting<T>(T value, void Function(T) updateFunction) {
    setState(() {
      updateFunction(value);
    });
    _saveSettings();

    // Update notification service when notification settings change
    FavoriteNotificationService.instance.updateSettings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Authentication Card
                    _buildAuthCard(),
                    const SizedBox(height: 16),

                    // Notification Settings
                    _buildNotificationSettings(),
                    const SizedBox(height: 16),

                    // Site Selection
                    _buildSiteSelection(),
                    const SizedBox(height: 16),

                    // Display Settings
                    _buildDisplaySettings(),
                    const SizedBox(height: 16),

                    // Debug Section (only in debug mode)
                    if (kDebugMode) ...[
                      _buildDebugSection(),
                      const SizedBox(height: 16),
                    ],

                    // Contact Section
                    _buildContactSection(),
                    const SizedBox(height: 16),

                    // Feedback Section
                    _buildFeedbackSection(),
                    const SizedBox(height: 16),

                    // About Section
                    _buildAboutSection(),
                  ],
                ),
              ),
    );
  }

  Widget _buildAuthCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isLoggedIn
                      ? Icons.account_circle
                      : Icons.account_circle_outlined,
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Account',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoggedIn) ...[
              Text('Signed in as: $_userEmail'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // Show confirmation dialog
                        final shouldSignOut = await showDialog<bool>(
                          context: context,
                          builder:
                              (context) => AlertDialog(
                                title: const Text('Sign Out'),
                                content: const Text(
                                  'Are you sure you want to sign out? Your settings will remain on this device.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Theme.of(context).colorScheme.error,
                                      foregroundColor:
                                          Theme.of(context).colorScheme.onError,
                                    ),
                                    child: const Text('Sign Out'),
                                  ),
                                ],
                              ),
                        );

                        if (shouldSignOut == true) {
                          final authService = AuthService();
                          await authService.signOut();
                          await _checkAuthStatus();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Successfully signed out'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const Text('Sign in to sync your settings across devices'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  );
                  await _checkAuthStatus();
                },
                child: const Text('Sign In'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.notifications,
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Master notification toggle
            SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: const Text('Master switch for all notifications'),
              value: _userSettings.notificationsEnabled,
              onChanged:
                  (value) => _updateSetting(
                    value,
                    (v) =>
                        _userSettings = _userSettings.copyWith(
                          notificationsEnabled: v,
                        ),
                  ),
            ),

            // Conditional notification settings
            if (_userSettings.notificationsEnabled) ...[
              const Divider(),

              // Favorite products notifications
              SwitchListTile(
                title: const Text('Favorite Product Alerts'),
                subtitle: const Text(
                  'Get notified about changes to your favorite products',
                ),
                value: _userSettings.favoriteProductNotifications,
                onChanged:
                    (value) => _updateSetting(
                      value,
                      (v) =>
                          _userSettings = _userSettings.copyWith(
                            favoriteProductNotifications: v,
                          ),
                    ),
              ),

              // Stock change notifications (only if favorite notifications enabled)
              if (_userSettings.favoriteProductNotifications) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: SwitchListTile(
                    title: const Text('Stock Changes'),
                    subtitle: const Text(
                      'Notify when favorite products come back in stock',
                    ),
                    value: _userSettings.notifyStockChanges,
                    onChanged:
                        (value) => _updateSetting(
                          value,
                          (v) =>
                              _userSettings = _userSettings.copyWith(
                                notifyStockChanges: v,
                              ),
                        ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: SwitchListTile(
                    title: const Text('Price Changes'),
                    subtitle: const Text(
                      'Notify when prices change for favorite products',
                    ),
                    value: _userSettings.notifyPriceChanges,
                    onChanged:
                        (value) => _updateSetting(
                          value,
                          (v) =>
                              _userSettings = _userSettings.copyWith(
                                notifyPriceChanges: v,
                              ),
                        ),
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // Information card about server notifications
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cloud_done,
                          color:
                              Theme.of(context).brightness == Brightness.dark
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Cloud notifications are delivered instantly when stock changes are detected by our servers.',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_userSettings.favoriteProductNotifications) ...[
                      const SizedBox(height: 8),
                      FutureBuilder<bool>(
                        future: _getFavoriteMonitoringStatus(),
                        builder: (context, snapshot) {
                          final isMonitoring = snapshot.data ?? false;
                          return Row(
                            children: [
                              Icon(
                                isMonitoring
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: isMonitoring ? Colors.red : Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isMonitoring
                                    ? 'Monitoring ${FavoriteNotificationService.instance.monitoredProductsCount} favorite products'
                                    : 'Favorite monitoring inactive',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onPrimaryContainer,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSiteSelection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monitored Sites (Server)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Server mode: Show available sites info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Server-Monitored Websites',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All supported matcha websites are automatically monitored by our servers. Data is synchronized to your device regularly.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                    ),
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
                    Icon(Icons.language, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        site['name']!,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withAlpha(100),
                        ),
                      ),
                      child: Text(
                        '${_siteProductCounts[site['key']] ?? 0} products',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
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
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const MatchaIcon(size: 24),
                const SizedBox(width: 8),
                const Text(
                  'About ZenRadar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'ZenRadar helps you monitor matcha availability across multiple Japanese tea retailers. '
              'Never miss your favorite matcha again!',
            ),
            const SizedBox(height: 16),
            const Text(
              'Version: 1.0.0',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplaySettings() {
    return Card(
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
              leading: Icon(
                Icons.palette,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.primary
                        : null,
              ),
              title: const Text('Theme'),
              subtitle: Text(
                'Current: ${_getThemeModeDisplayName(ThemeService.instance.themeMode)}',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _showThemeDialog(),
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.attach_money,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.primary
                        : null,
              ),
              title: const Text('Preferred Currency'),
              subtitle: Text(
                'Show prices in ${_userSettings.preferredCurrency}',
              ),
              trailing: const Icon(Icons.edit),
              onTap: () => _showCurrencyDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Card(
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
                  Icon(
                    Icons.contact_mail,
                    size: 44,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.blueGrey.shade300
                            : Colors.blueGrey,
                  ),
                  'Contact',
                  _showContactDialog,
                ),
                const SizedBox(width: 16),
                _buildSocialButton(
                  Icon(
                    Icons.email,
                    size: 44,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.teal.shade300
                            : Colors.teal,
                  ),
                  'Email',
                  () async {
                    final Uri emailUri = Uri(
                      scheme: 'mailto',
                      path: 'fabian.ebert@online.de',
                      query: 'subject=ZenRadar Feedback',
                    );
                    try {
                      if (await canLaunchUrl(emailUri)) {
                        await launchUrl(emailUri);
                      } else {
                        // Fallback for Android - try different launch modes
                        try {
                          await launchUrl(
                            emailUri,
                            mode: LaunchMode.platformDefault,
                          );
                        } catch (e) {
                          if (context.mounted) {
                            // Copy email to clipboard as final fallback
                            await _copyEmailToClipboard();
                          }
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        await _copyEmailToClipboard();
                      }
                    }
                  },
                ),
                const SizedBox(width: 16),
                _buildSocialButton(
                  Icon(
                    Icons.code,
                    size: 44,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey.shade300
                            : Colors.black87,
                  ),
                  'GitHub',
                  _launchGitHub,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSocialButton(
                  Icon(
                    Icons.business,
                    size: 44,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.blueAccent.shade200
                            : Colors.blueAccent,
                  ),
                  'LinkedIn',
                  _launchLinkedIn,
                ),
                const SizedBox(width: 16),
                _buildSocialButton(
                  Icon(
                    Icons.attach_money,
                    size: 44,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.green.shade300
                            : Colors.green,
                  ),
                  'PayPal',
                  _launchPayPal,
                ),
                const SizedBox(width: 16),
                _buildSocialButton(
                  Icon(
                    Icons.local_cafe,
                    size: 44,
                    color:
                        Theme.of(context).brightness == Brightness.dark
                            ? Colors.brown.shade300
                            : Colors.brown,
                  ),
                  'BuyMeACoffee',
                  _launchBuyMeACoffee,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Feedback & Suggestions'),
            const SizedBox(height: 8),
            ListTile(
              leading: Icon(
                Icons.feedback,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.orange.shade300
                        : Colors.orange,
                size: 28,
              ),
              title: const Text('Submit Feedback'),
              subtitle: const Text(
                'Share your ideas and suggestions on our feedback board',
              ),
              trailing: const Icon(Icons.open_in_new),
              onTap: _launchFeedbacky,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withAlpha(75)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your feedback helps improve ZenRadar! Vote on existing ideas or submit new ones.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods
  List<Map<String, String>> _getBuiltInSites() {
    return [
      {'key': 'tokichi', 'name': 'Tokichi'},
      {'key': 'marukyu', 'name': 'Marukyu-Koyamaen'},
      {'key': 'ippodo', 'name': 'Ippodo Tea'},
      {'key': 'yoshien', 'name': 'Yoshien'},
      {'key': 'matcha-karu', 'name': 'Matcha-Karu'},
      {'key': 'sho-cha', 'name': 'Sho-Cha'},
      {'key': 'sazentea', 'name': 'Sazen Tea'},
      {'key': 'enjoyemeri', 'name': 'Enjoy Emeri'},
      {'key': 'poppatea', 'name': 'Poppa Tea'},
      {'key': 'horiishichimeien', 'name': 'Horiishichimeien'},
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Icon(
          Icons.info,
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildSocialButton(Widget icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.withAlpha(50),
            ),
            child: icon,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _getThemeModeDisplayName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
      case AppThemeMode.system:
        return 'System';
    }
  }

  void _showWebsiteSuggestionDialog() {
    final websiteUrlController = TextEditingController();
    final websiteNameController = TextEditingController();
    final additionalInfoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Suggest New Website'),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Help us expand ZenRadar by suggesting a new matcha website to monitor!',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: websiteNameController,
                      decoration: const InputDecoration(
                        labelText: 'Website Name',
                        hintText: 'e.g. "Uji Tea Company"',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the website name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: websiteUrlController,
                      decoration: const InputDecoration(
                        labelText: 'Website URL',
                        hintText: 'https://example.com',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter the website URL';
                        }
                        final uri = Uri.tryParse(value);
                        if (uri == null ||
                            !uri.hasAbsolutePath ||
                            (!uri.scheme.startsWith('http'))) {
                          return 'Please enter a valid URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: additionalInfoController,
                      decoration: const InputDecoration(
                        labelText: 'Additional Information (Optional)',
                        hintText: 'Special features, product types, etc.',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    // Compose suggestion email
                    final Uri emailUri = Uri(
                      scheme: 'mailto',
                      path: 'fabian.ebert@online.de',
                      query: Uri.encodeQueryComponent(
                        'subject=ZenRadar Website Suggestion - ${websiteNameController.text}&'
                        'body=Website Suggestion for ZenRadar\n\n'
                        'Website Name: ${websiteNameController.text}\n'
                        'Website URL: ${websiteUrlController.text}\n\n'
                        'Additional Information:\n${additionalInfoController.text.isEmpty ? 'None provided' : additionalInfoController.text}\n\n'
                        'Please consider adding this website to ZenRadar for matcha monitoring.\n\n'
                        'Thank you!',
                      ),
                    );

                    try {
                      if (await canLaunchUrl(emailUri)) {
                        await launchUrl(
                          emailUri,
                          mode: LaunchMode.externalApplication,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Thank you for your suggestion! Email app opened.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        throw 'Could not launch email app';
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not open email app: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                child: const Text('Send Suggestion'),
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
            title: const Text('Choose Theme'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  AppThemeMode.values.map((mode) {
                    return RadioListTile<AppThemeMode>(
                      title: Text(_getThemeModeDisplayName(mode)),
                      value: mode,
                      groupValue: ThemeService.instance.themeMode,
                      onChanged: (value) {
                        if (value != null) {
                          ThemeService.instance.setThemeMode(value);
                          Navigator.pop(context);
                        }
                      },
                    );
                  }).toList(),
            ),
          ),
    );
  }

  void _showCurrencyDialog() {
    final currencies = ['EUR', 'USD', 'JPY', 'GBP'];
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Choose Currency'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  currencies.map((currency) {
                    return RadioListTile<String>(
                      title: Text(currency),
                      value: currency,
                      groupValue: _userSettings.preferredCurrency,
                      onChanged: (value) {
                        if (value != null) {
                          _updateSetting(
                            value,
                            (v) =>
                                _userSettings = _userSettings.copyWith(
                                  preferredCurrency: v,
                                ),
                          );
                          Navigator.pop(context);
                        }
                      },
                    );
                  }).toList(),
            ),
          ),
    );
  }

  // URL launcher methods
  void _launchGitHub() async {
    final Uri url = Uri.parse('https://github.com/SirArchy/ZenRadar');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _launchLinkedIn() async {
    final Uri url = Uri.parse('https://www.linkedin.com/in/fabian-e-762b85244');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _launchPayPal() async {
    final Uri url = Uri.parse('https://paypal.me/FEbert353');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _launchBuyMeACoffee() async {
    final Uri url = Uri.parse('https://buymeacoffee.com/worktimetracker');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _launchFeedbacky() async {
    final Uri url = Uri.parse('https://app.feedbacky.net/b/zenRadar');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  /// Get the current status of favorite product monitoring
  Future<bool> _getFavoriteMonitoringStatus() async {
    return FavoriteNotificationService.instance.isMonitoring;
  }

  Widget _buildDebugSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bug_report,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Debug Tools',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Test notification button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _testNotification,
                icon: const Icon(Icons.notifications_active),
                label: const Text('Test Notification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor:
                      Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              'Send a test notification to verify that notifications are working correctly.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testNotification() async {
    try {
      await NotificationService.instance.showNotification(
        id: 999,
        title: 'ZenRadar Test Notification',
        body:
            'This is a test notification to verify that notifications are working correctly.',
        payload: 'test_notification',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test notification sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error sending test notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send test notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showContactDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Contact Us'),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: 'Your Email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: messageController,
                      decoration: const InputDecoration(
                        labelText: 'Your Message',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your message';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    // Compose email
                    final Uri emailUri = Uri(
                      scheme: 'mailto',
                      path: 'fabian.ebert@online.de',
                      query: Uri.encodeQueryComponent(
                        'subject=ZenRadar Contact Form - ${nameController.text}&'
                        'body=Name: ${nameController.text}\n'
                        'Email: ${emailController.text}\n\n'
                        'Message:\n${messageController.text}',
                      ),
                    );

                    try {
                      if (await canLaunchUrl(emailUri)) {
                        await launchUrl(
                          emailUri,
                          mode: LaunchMode.externalApplication,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Email app opened successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } else {
                        throw 'Could not launch email app';
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not open email app: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                child: const Text('Send Email'),
              ),
            ],
          ),
    );
  }

  Future<void> _copyEmailToClipboard() async {
    await Clipboard.setData(
      const ClipboardData(text: 'fabian.ebert@online.de'),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email address copied to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
