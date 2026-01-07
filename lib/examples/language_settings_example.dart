// Example: How to add language selection to settings_screen.dart
// This is a reference implementation showing how to integrate the language selector

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/localization_service.dart';
import '../widgets/language_selection_dialog.dart';

class LanguageSettingsExample extends StatefulWidget {
  const LanguageSettingsExample({super.key});

  @override
  State<LanguageSettingsExample> createState() =>
      _LanguageSettingsExampleState();
}

class _LanguageSettingsExampleState extends State<LanguageSettingsExample> {
  String? _currentLanguageCode;

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    final code = await LocalizationService.instance.getLanguageCode();
    setState(() {
      _currentLanguageCode = code;
    });
  }

  String _getCurrentLanguageName() {
    if (_currentLanguageCode == null) {
      final l10n = AppLocalizations.of(context)!;
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

      // Show a snackbar to inform user to restart app for full effect
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

        // Note: For a full app reload, you would typically use:
        // Phoenix.rebirth(context); or similar restart mechanism
        // For now, just inform the user
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          // Appearance Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.appearance,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Language Setting
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(_getCurrentLanguageName()),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showLanguageDialog,
          ),

          // Theme Setting (example)
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text(l10n.theme),
            subtitle: Text(l10n.systemDefault),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // Show theme selection dialog
            },
          ),

          const Divider(),

          // General Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.general,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Notifications (example)
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: Text(l10n.notifications),
            subtitle: Text(l10n.enableNotifications),
            value: true,
            onChanged: (value) {
              // Handle notification toggle
            },
          ),

          const Divider(),

          // Data & Privacy Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.dataAndPrivacy,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: Text(l10n.clearCache),
            onTap: () async {
              // Show confirmation dialog
              final confirm = await showDialog<bool>(
                context: context,
                builder:
                    (context) => AlertDialog(
                      title: Text(l10n.areYouSure),
                      content: Text(l10n.thisActionCannotBeUndone),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l10n.cancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(l10n.confirm),
                        ),
                      ],
                    ),
              );

              if (confirm == true && mounted) {
                // Clear cache
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.cacheCleared)));
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.history),
            title: Text(l10n.clearSearchHistory),
            onTap: () async {
              // Clear search history
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.searchHistoryCleared)),
              );
            },
          ),

          const Divider(),

          // About Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.about,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.info),
            title: Text(l10n.version),
            subtitle: const Text('1.0.0+2'),
            onTap: () {
              // Show version info
            },
          ),

          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: Text(l10n.privacyPolicy),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // Open privacy policy
            },
          ),

          ListTile(
            leading: const Icon(Icons.description),
            title: Text(l10n.termsOfService),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // Open terms of service
            },
          ),

          ListTile(
            leading: const Icon(Icons.support),
            title: Text(l10n.contactSupport),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // Open support
            },
          ),

          ListTile(
            leading: const Icon(Icons.star),
            title: Text(l10n.rateApp),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              // Open app store rating
            },
          ),
        ],
      ),
    );
  }
}

// IMPORTANT: To add this to your existing settings_screen.dart:
//
// 1. Add the imports at the top:
//    import 'package:flutter_gen/gen_l10n/app_localizations.dart';
//    import '../services/localization_service.dart';
//    import '../widgets/language_selection_dialog.dart';
//
// 2. Add these methods to your _SettingsScreenState class:
//    - _loadCurrentLanguage()
//    - _getCurrentLanguageName()
//    - _showLanguageDialog()
//
// 3. Replace hardcoded strings with l10n.* equivalents
//
// 4. Add the language ListTile in the appropriate section
