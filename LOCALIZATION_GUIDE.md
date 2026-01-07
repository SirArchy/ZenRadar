# Multi-Language Support Implementation Guide

## Overview
ZenRadar now supports 6 languages:
- 🇬🇧 English (en)
- 🇩🇪 German (de) - **Fully translated**
- 🇪🇸 Spanish (es)
- 🇵🇹 Portuguese (pt)
- 🇫🇷 French (fr)
- 🇯🇵 Japanese (ja)

## Files Created/Modified

### Configuration Files
- `l10n.yaml` - Localization configuration
- `pubspec.yaml` - Added flutter_localizations and generate flag

### Translation Files (lib/l10n/)
- `app_en.arb` - English translations (base)
- `app_de.arb` - German translations (complete)
- `app_es.arb` - Spanish translations
- `app_pt.arb` - Portuguese translations
- `app_fr.arb` - French translations
- `app_ja.arb` - Japanese translations

### Services
- `lib/services/localization_service.dart` - Language management service

### Widgets
- `lib/widgets/language_selection_dialog.dart` - Language picker dialog

### Core Files
- `lib/main.dart` - Updated to support localization

## How to Use Localization in Your Code

### 1. Import the generated localizations
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
```

### 2. Access translations in your widget
```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  
  return Text(l10n.home);  // Returns "Home" or "Startseite" depending on locale
}
```

### 3. Example Usage in Screens
```dart
// Instead of hardcoded strings:
Text('Settings')  // ❌ Bad

// Use localized strings:
Text(l10n.settings)  // ✅ Good
```

### 4. Add Language Selector to Settings
Add this to your settings screen:

```dart
import '../widgets/language_selection_dialog.dart';

ListTile(
  leading: const Icon(Icons.language),
  title: Text(l10n.language),
  subtitle: Text(_getCurrentLanguageName()),  // Display current language
  onTap: () async {
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => const LanguageSelectionDialog(),
    );
    
    if (result != null && mounted) {
      // Restart app to apply new language
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AppInitializer()),
        (route) => false,
      );
    }
  },
)
```

### 5. Change Language Programmatically
```dart
// Save language preference
await LocalizationService.instance.setLanguageCode('de');

// Clear preference (use system default)
await LocalizationService.instance.clearLanguageCode();

// Get current language
final currentLang = await LocalizationService.instance.getLanguageCode();
```

## Available Translation Keys

All available keys can be found in `lib/l10n/app_en.arb`. Some examples:

### Common
- `appName`, `appTagline`
- `home`, `favorites`, `analytics`, `settings`
- `search`, `filters`, `sort`
- `loading`, `error`, `success`, `failed`

### Actions
- `apply`, `cancel`, `save`, `delete`, `edit`, `close`
- `refresh`, `retry`, `confirm`

### Product Related
- `productDetails`, `description`, `ingredients`
- `stockStatus`, `priceHistory`, `stockHistory`
- `inStock`, `outOfStock`

### Account
- `signIn`, `signOut`, `email`, `password`
- `createAccount`, `forgotPassword`

### Subscription
- `freePlan`, `premiumPlan`, `upgradeToPremium`
- `subscription`, `manageSub`

### Time
- `day`, `week`, `month`, `year`

## Adding New Translation Keys

1. Add to `lib/l10n/app_en.arb`:
```json
"newKey": "New String",
"@newKey": {
  "description": "Description of what this string is for"
}
```

2. Add translations to other language files:
```json
// app_de.arb
"newKey": "Neuer String"
```

3. Run `flutter pub get` to regenerate localization files

4. Use in code:
```dart
Text(l10n.newKey)
```

## Testing Different Languages

### Method 1: Change Device Language
Change your device's language in system settings and restart the app.

### Method 2: Force Locale in Code (for testing)
In `main.dart`, you can temporarily force a locale:
```dart
MaterialApp(
  locale: const Locale('de'),  // Force German
  // ... other properties
)
```

### Method 3: Use Language Selector
Use the LanguageSelectionDialog widget to switch languages in the app.

## Next Steps

1. **Replace hardcoded strings**: Go through your screens and replace all hardcoded English strings with localized versions
2. **Add missing translations**: Currently only German is fully translated. Add translations for Spanish, Portuguese, French, and Japanese
3. **Test thoroughly**: Test the app in each supported language
4. **Add more keys**: Add any application-specific strings that aren't in the base translation file

## Example: Converting a Screen

Before:
```dart
AppBar(
  title: const Text('Settings'),
)

ListTile(
  title: const Text('Dark Mode'),
  subtitle: const Text('Enable dark theme'),
)
```

After:
```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  
  return Scaffold(
    appBar: AppBar(
      title: Text(l10n.settings),
    ),
    body: ListView(
      children: [
        ListTile(
          title: Text(l10n.darkMode),
          subtitle: Text('${l10n.theme} - ${l10n.appearance}'),
        ),
      ],
    ),
  );
}
```

## Notes

- The system automatically picks up the device's language if it's supported
- Users can override the system language using the language selector
- Unsupported device languages default to English
- Language preference is saved in SharedPreferences
- App needs to be restarted to fully apply language changes
