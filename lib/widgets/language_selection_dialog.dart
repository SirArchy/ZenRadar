import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Dialog for selecting app language
class LanguageSelectionDialog extends StatefulWidget {
  const LanguageSelectionDialog({super.key});

  @override
  State<LanguageSelectionDialog> createState() =>
      _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends State<LanguageSelectionDialog> {
  String? _selectedLanguageCode;

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    final savedLanguage = await LocalizationService.instance.getLanguageCode();
    setState(() {
      _selectedLanguageCode =
          savedLanguage ?? Localizations.localeOf(context).languageCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(l10n.language),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // System default option
            RadioListTile<String?>(
              title: Row(
                children: [
                  const Text('🌐'),
                  const SizedBox(width: 8),
                  Text(l10n.systemDefault),
                ],
              ),
              value: null,
              groupValue: _selectedLanguageCode,
              onChanged: (value) {
                setState(() {
                  _selectedLanguageCode = value;
                });
              },
            ),
            const Divider(),
            // Language options
            ...LocalizationService.supportedLanguages.map((localeInfo) {
              return RadioListTile<String>(
                title: Row(
                  children: [
                    Text(localeInfo.flag, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localeInfo.nativeName,
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          localeInfo.name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withAlpha(
                              153,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                value: localeInfo.code,
                groupValue: _selectedLanguageCode,
                onChanged: (value) {
                  setState(() {
                    _selectedLanguageCode = value;
                  });
                },
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () async {
            if (_selectedLanguageCode == null) {
              // Use system default
              await LocalizationService.instance.clearLanguageCode();
            } else {
              // Save selected language
              await LocalizationService.instance.setLanguageCode(
                _selectedLanguageCode!,
              );
            }

            if (context.mounted) {
              Navigator.of(context).pop(_selectedLanguageCode);
            }
          },
          child: Text(l10n.apply),
        ),
      ],
    );
  }
}
