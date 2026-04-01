import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:zenradar/models/matcha_product.dart';
import 'package:zenradar/data/services/auth/auth_service.dart';
import 'package:zenradar/data/services/data/database_service.dart';
import 'package:zenradar/data/services/settings/settings_service.dart';
import 'package:zenradar/data/services/settings/theme_service.dart';
import 'package:zenradar/data/services/notifications/favorite_notification_service.dart';
import 'package:zenradar/data/services/notifications/notification_service.dart';
import 'package:zenradar/data/services/subscription/subscription_service.dart';
import 'package:zenradar/data/services/settings/localization_service.dart';
import 'package:zenradar/presentation/widgets/common/matcha_icon.dart';
import 'package:zenradar/presentation/widgets/dialogs/language_selection_dialog.dart';
import 'package:zenradar/presentation/screens/auth/auth_screen.dart';
import 'package:zenradar/presentation/screens/subscription/subscription_upgrade_screen.dart';
import 'package:zenradar/presentation/screens/core/app_initializer.dart';

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
  SubscriptionTier _currentTier = SubscriptionTier.free;
  bool _isPremium = false;
  String? _currentLanguageCode;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkAuthStatus();
    _loadSubscriptionStatus().then((_) {
      // Load site product counts after subscription status is loaded
      _loadSiteProductCounts();
    });
    _loadCurrentLanguage();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.instance.getSettings();
      setState(() {
        _userSettings = settings;
        _isLoading = false;
      });
    } catch (_) {
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
    } catch (_) {
      // Ignore and keep existing values.
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final tier = await SubscriptionService.instance.getCurrentTier();
      final isPremium = await SubscriptionService.instance.isPremiumUser();

      setState(() {
        _currentTier = tier;
        _isPremium = isPremium;
      });

      // Reload site product counts when subscription status changes
      _loadSiteProductCounts();
    } catch (_) {
      // Ignore and keep existing values.
    }
  }

  Future<void> _loadCurrentLanguage() async {
    final code = await LocalizationService.instance.getLanguageCode();
    setState(() {
      _currentLanguageCode = code;
    });
  }

  String _getCurrentLanguageName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_currentLanguageCode == null) {
      return l10n.systemDefault;
    }

    final localeInfo = LocalizationService.getLocaleInfo(_currentLanguageCode!);
    return localeInfo != null
        ? '${localeInfo.flag} ${localeInfo.nativeName}'
        : _currentLanguageCode!;
  }

  Future<void> _showLanguageDialog() async {
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => const LanguageSelectionDialog(),
    );

    if (result != null && mounted) {
      // Language was changed, reload to apply
      await _loadCurrentLanguage();

      // Show a snackbar to inform user
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.language} ${l10n.success.toLowerCase()}'),
            action: SnackBarAction(
              label: l10n.close,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );

        // Restart app to apply language changes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AppInitializer()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      await SettingsService.instance.saveSettings(_userSettings);

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.settings} ${l10n.success.toLowerCase()}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.failed}: $e'),
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

                    // Subscription Settings
                    _buildSubscriptionCard(),
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
    final l10n = AppLocalizations.of(context)!;
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
                Text(
                  l10n.account,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoggedIn) ...[
              Text('${l10n.email}: $_userEmail'),
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
                                title: Text(l10n.signOut),
                                content: Text(l10n.areYouSure),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: Text(l10n.cancel),
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
                                    child: Text(l10n.signOut),
                                  ),
                                ],
                              ),
                        );

                        if (shouldSignOut == true) {
                          final authService = AuthService();
                          await authService.signOut();
                          await _checkAuthStatus();

                          if (mounted) {
                            // Navigate back to app initializer to handle auth state
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                builder: (context) => const AppInitializer(),
                              ),
                              (route) => false,
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.logout),
                      label: Text(l10n.signOut),
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
              Text(l10n.signInToSyncSettingsAcrossDevices),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  );
                  await _checkAuthStatus();
                },
                child: Text(l10n.signIn),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationSettings() {
    final l10n = AppLocalizations.of(context)!;
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
                Text(
                  l10n.notifications,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Master notification toggle
            SwitchListTile(
              title: Text(l10n.enableNotifications),
              subtitle: Text(l10n.masterSwitchForAllNotifications),
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
                title: Text(l10n.favoriteProductAlerts),
                subtitle: Text(l10n.getNotifiedAboutFavoriteChanges),
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
                    title: Text(l10n.stockStatus),
                    subtitle: Text(l10n.notifyWhenInStock),
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
                    title: Text(l10n.priceChanges),
                    subtitle: Text(l10n.notifyWhenFavoritePricesChange),
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
                            l10n.cloudNotificationsDeliveredInstantly,
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
                                    ? l10n.monitoringFavoriteProducts(
                                      FavoriteNotificationService
                                          .instance
                                          .monitoredProductsCount,
                                    )
                                    : l10n.favoriteMonitoringInactive,
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
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.monitoredSites,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _buildTierBadge(),
              ],
            ),
            const SizedBox(height: 8),
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
                        l10n.serverMonitoredWebsites,
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
                    l10n.allSupportedSitesMonitoredByServer,
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
                        l10n.productsCount(
                          _siteProductCounts[site['key']] ?? 0,
                        ),
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
              title: Text(l10n.suggestNewWebsite),
              subtitle: Text(l10n.requestMonitoringForAdditionalSites),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showWebsiteSuggestionDialog,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    final l10n = AppLocalizations.of(context)!;
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
                Text(
                  l10n.aboutZenRadar,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(l10n.aboutZenRadarDescription),
            const SizedBox(height: 16),
            Text(
              l10n.versionNumber('1.0.0'),
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisplaySettings() {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.appearance,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Language Setting
            ListTile(
              leading: Icon(
                Icons.language,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.primary
                        : null,
              ),
              title: Text(l10n.language),
              subtitle: Text(_getCurrentLanguageName(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showLanguageDialog,
            ),
            const Divider(),

            ListTile(
              leading: Icon(
                Icons.palette,
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.primary
                        : null,
              ),
              title: Text(l10n.theme),
              subtitle: Text(
                '${l10n.systemDefault}: ${_getThemeModeDisplayName(ThemeService.instance.themeMode)}',
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
              title: Text(l10n.preferredCurrency),
              subtitle: Text(
                _userSettings.preferredCurrency == 'Original'
                    ? l10n.showPricesInOriginalSiteCurrency
                    : l10n.showPricesInCurrency(
                      _userSettings.preferredCurrency,
                    ),
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
            _buildSectionTitle(AppLocalizations.of(context)!.contactMe),
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
                  AppLocalizations.of(context)!.contact,
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
                  AppLocalizations.of(context)!.email,
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
                  AppLocalizations.of(context)!.github,
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
                  AppLocalizations.of(context)!.linkedIn,
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
                  AppLocalizations.of(context)!.payPal,
                  _launchPayPal,
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
            _buildSectionTitle(
              AppLocalizations.of(context)!.feedbackAndSuggestions,
            ),
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
              title: Text(AppLocalizations.of(context)!.submitFeedback),
              subtitle: Text(
                AppLocalizations.of(context)!.shareIdeasOnFeedbackBoard,
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
                      AppLocalizations.of(context)!.feedbackImprovesZenRadar,
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
    final allSites = [
      {'key': 'ippodo', 'name': 'Ippodo Tea'},
      {'key': 'marukyu', 'name': 'Marukyu-Koyamaen'},
      {'key': 'matcha-karu', 'name': 'Matcha-Karu'},
      {'key': 'yoshien', 'name': 'YOSHI En'},
      {'key': 'tokichi', 'name': 'Nakamura Tokichi'},
      {'key': 'sho-cha', 'name': 'Sho-Cha'},
      {'key': 'sazentea', 'name': 'Sazen Tea'},
      {'key': 'enjoyemeri', 'name': 'Enjoy Emeri'},
      {'key': 'poppatea', 'name': 'Poppa Tea'},
      {'key': 'horiishichimeien', 'name': 'Horiishichimeien'},
    ];

    // All users can now see all sites - no filtering based on subscription tier
    return allSites;
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
    final l10n = AppLocalizations.of(context)!;
    switch (mode) {
      case AppThemeMode.light:
        return l10n.lightMode;
      case AppThemeMode.dark:
        return l10n.darkMode;
      case AppThemeMode.system:
        return l10n.systemDefault;
    }
  }

  void _showWebsiteSuggestionDialog() {
    final l10n = AppLocalizations.of(context)!;
    final websiteUrlController = TextEditingController();
    final websiteNameController = TextEditingController();
    final additionalInfoController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.suggestNewWebsite),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.helpExpandZenRadar,
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: websiteNameController,
                      decoration: InputDecoration(
                        labelText: l10n.websiteName,
                        hintText: l10n.websiteNameHint,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterWebsiteName;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: websiteUrlController,
                      decoration: InputDecoration(
                        labelText: l10n.websiteUrl,
                        hintText: l10n.websiteUrlHint,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterWebsiteUrl;
                        }
                        final uri = Uri.tryParse(value);
                        if (uri == null ||
                            !uri.hasAbsolutePath ||
                            (!uri.scheme.startsWith('http'))) {
                          return l10n.pleaseEnterValidUrl;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: additionalInfoController,
                      decoration: InputDecoration(
                        labelText: l10n.additionalInformationOptional,
                        hintText: l10n.additionalInformationHint,
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
                child: Text(l10n.cancel),
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
                            SnackBar(
                              content: Text(l10n.thankYouSuggestionEmailOpened),
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
                            content: Text(
                              l10n.couldNotOpenEmailAppWithError('$e'),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                child: Text(l10n.sendSuggestion),
              ),
            ],
          ),
    );
  }

  void _showThemeDialog() {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.chooseTheme),
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
    final l10n = AppLocalizations.of(context)!;
    final currencies = ['Original', 'EUR', 'USD', 'JPY', 'GBP'];
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.chooseCurrency),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children:
                  currencies.map((currency) {
                    String displayName =
                        currency == 'Original'
                            ? l10n.originalNativeSiteCurrency
                            : currency;
                    return RadioListTile<String>(
                      title: Text(displayName),
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
    final l10n = AppLocalizations.of(context)!;
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
                Text(
                  l10n.debugTools,
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
                label: Text(l10n.testNotification),
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
              l10n.sendTestNotificationDescription,
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
    final l10n = AppLocalizations.of(context)!;
    try {
      await NotificationService.instance.showNotification(
        id: 999,
        title: l10n.zenRadarTestNotificationTitle,
        body: l10n.zenRadarTestNotificationBody,
        payload: 'test_notification',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.testNotificationSent),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToSendTestNotification('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showContactDialog() {
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final messageController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.contactUs),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: l10n.yourName,
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterYourName;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: l10n.yourEmail,
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterYourEmail;
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return l10n.pleaseEnterValidEmail;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: messageController,
                      decoration: InputDecoration(
                        labelText: l10n.yourMessage,
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.pleaseEnterYourMessage;
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
                child: Text(l10n.cancel),
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
                            SnackBar(
                              content: Text(l10n.emailAppOpenedSuccessfully),
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
                            content: Text(
                              l10n.couldNotOpenEmailAppWithError('$e'),
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                child: Text(l10n.sendEmail),
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
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.emailAddressCopiedToClipboard),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Build subscription settings card
  Widget _buildSubscriptionCard() {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTier = _isPremium ? SubscriptionTier.premium : _currentTier;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  l10n.subscription,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                _buildTierBadge(),
              ],
            ),
            const SizedBox(height: 16),

            // Current plan info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    _isPremium
                        ? (isDark
                            ? Colors.amber.shade900.withAlpha(100)
                            : Colors.amber.shade50)
                        : (isDark
                            ? Colors.grey.shade800.withAlpha(150)
                            : Colors.grey.shade50),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      _isPremium
                          ? (isDark
                              ? Colors.amber.shade600.withAlpha(150)
                              : Colors.amber.shade200)
                          : (isDark
                              ? Colors.grey.shade600.withAlpha(150)
                              : Colors.grey.shade200),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isPremium ? Icons.star : Icons.person,
                        color:
                            _isPremium
                                ? (isDark
                                    ? Colors.amber.shade300
                                    : Colors.amber.shade700)
                                : (isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${effectiveTier.displayName} Plan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color:
                                _isPremium
                                    ? (isDark
                                        ? Colors.amber.shade200
                                        : Colors.amber.shade800)
                                    : (isDark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Plan features
                  _buildPlanFeatures(),

                  if (!_isPremium) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showUpgradeDialog,
                        icon: const Icon(Icons.upgrade),
                        label: Text(l10n.upgradeToPremium),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDark ? Colors.amber.shade700 : Colors.amber,
                          foregroundColor:
                              isDark ? Colors.white : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build plan features list
  Widget _buildPlanFeatures() {
    final l10n = AppLocalizations.of(context)!;
    final features = [
      _buildFeatureRow(
        l10n.favorites,
        _isPremium
            ? l10n.unlimitedFavorites
            : '${_currentTier.maxFavorites} ${l10n.maximum}',
        _isPremium,
      ),
      _buildFeatureRow(
        l10n.sites,
        l10n.allVendorSites, // All users now have access to all sites
        true, // Always show as premium feature (enabled for all)
      ),
      _buildFeatureRow(
        l10n.scanFrequency,
        _isPremium ? l10n.checkEveryHour : l10n.checkEverySixHours,
        _isPremium,
      ),
      _buildFeatureRow(
        l10n.fullHistoryAccessDesc,
        _isPremium
            ? l10n.fullHistoryAccess
            : '${_currentTier.historyLimitDays} ${l10n.days}',
        _isPremium,
      ),
    ];

    return Column(children: features);
  }

  /// Build individual feature row
  Widget _buildFeatureRow(String feature, String value, bool isPremium) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isPremium ? Icons.check_circle : Icons.info,
            size: 16,
            color:
                isPremium
                    ? (isDark ? Colors.green.shade300 : Colors.green)
                    : (isDark ? Colors.orange.shade300 : Colors.orange),
          ),
          const SizedBox(width: 8),
          Text(feature, style: const TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Build tier badge showing current subscription status
  Widget _buildTierBadge() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTier = _isPremium ? SubscriptionTier.premium : _currentTier;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:
            _isPremium
                ? (isDark ? Colors.amber.shade700.withAlpha(180) : Colors.amber)
                : (isDark
                    ? Colors.grey.shade600.withAlpha(150)
                    : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _isPremium
                  ? (isDark ? Colors.amber.shade500 : Colors.amber.shade700)
                  : (isDark ? Colors.grey.shade500 : Colors.grey.shade500),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isPremium ? Icons.star : Icons.person,
            size: 16,
            color:
                _isPremium
                    ? (isDark ? Colors.amber.shade200 : Colors.amber.shade900)
                    : (isDark ? Colors.grey.shade300 : Colors.grey.shade600),
          ),
          const SizedBox(width: 4),
          Text(
            effectiveTier.displayName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  _isPremium
                      ? (isDark ? Colors.amber.shade100 : Colors.amber.shade900)
                      : (isDark ? Colors.grey.shade300 : Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  /// Show upgrade dialog
  void _showUpgradeDialog() {
    var isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.star, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              Text(l10n.upgradeToPremium),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.unlockFullPotentialPremium,
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              _buildUpgradeFeature(l10n.unlimitedFavoriteProducts, '42 → ∞'),
              _buildUpgradeFeature(l10n.hourlyCheckFrequency, '6h → 1h'),
              _buildUpgradeFeature(l10n.fullPriceAndStockHistory, '7d → ∞'),
              _buildUpgradeFeature(l10n.priorityNotifications, l10n.comingSoon),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.amber.shade50 : Colors.amber.shade800,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.amber.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.paymentIntegrationComingSoon,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark
                                  ? Colors.grey.shade800.withAlpha(150)
                                  : Colors.grey.shade50,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.maybeLater),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => const SubscriptionUpgradeScreen(
                          sourceScreen: 'settings',
                        ),
                  ),
                );
              },
              icon: const Icon(Icons.upgrade),
              label: Text(l10n.getPremium),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.amber.shade900,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build upgrade feature row
  Widget _buildUpgradeFeature(String feature, String comparison) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            comparison,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
