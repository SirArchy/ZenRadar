import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class AppModeSelectionDialog extends StatefulWidget {
  final bool isInitialSetup;
  final Function(String mode)? onModeSelected;

  const AppModeSelectionDialog({
    super.key,
    this.isInitialSetup = false,
    this.onModeSelected,
  });

  @override
  State<AppModeSelectionDialog> createState() => _AppModeSelectionDialogState();
}

class _AppModeSelectionDialogState extends State<AppModeSelectionDialog> {
  String? _selectedMode;

  @override
  void initState() {
    super.initState();
    // Auto-select server mode for web users
    if (kIsWeb) {
      _selectedMode = 'server';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.settings_applications, color: Colors.blue),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.isInitialSetup
                  ? 'Choose Operation Mode'
                  : 'Change Operation Mode',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Web-specific message
              if (kIsWeb)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.web, color: Colors.blue.shade600, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Web Version',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The web version automatically uses server mode for optimal performance and to avoid CORS restrictions.',
                        style: TextStyle(
                          color: Colors.blue.shade600,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

              if (widget.isInitialSetup && !kIsWeb)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Choose how ZenRadar should operate:',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Local Mode Card - only show on mobile
              if (!kIsWeb)
                _buildModeCard(
                  mode: 'local',
                  title: '📱 Local Mode',
                  subtitle: 'Run everything on your device',
                  pros: [
                    '✅ Complete privacy',
                    '✅ Works offline',
                    '✅ Full control',
                    '✅ No server dependencies',
                  ],
                  cons: [
                    '❌ Uses device battery',
                    '❌ Limited by device resources',
                    '❌ May be killed by system',
                  ],
                  description:
                      'Your device crawls websites and stores all data locally.',
                ),

              if (!kIsWeb) const SizedBox(height: 16),

              // Server Mode Card
              _buildModeCard(
                mode: 'server',
                title: '☁️ Server Mode',
                subtitle: 'Use cloud-based monitoring',
                pros: [
                  '✅ Zero battery usage',
                  '✅ Always-on monitoring',
                  '✅ Reliable & fast',
                  '✅ Shared data improvements',
                ],
                cons: [
                  '❌ Requires internet',
                  '❌ Data stored in cloud',
                  '❌ Limited customization',
                ],
                description:
                    'Cloud servers monitor websites and sync data to your device.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!widget.isInitialSetup && !kIsWeb)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ElevatedButton(
          onPressed: _selectedMode != null ? () => _confirmSelection() : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text(
            kIsWeb
                ? (widget.isInitialSetup
                    ? 'Continue with Server Mode'
                    : 'Continue')
                : (widget.isInitialSetup ? 'Start App' : 'Apply Changes'),
          ),
        ),
      ],
    );
  }

  Widget _buildModeCard({
    required String mode,
    required String title,
    required String subtitle,
    required List<String> pros,
    required List<String> cons,
    required String description,
  }) {
    final isSelected = _selectedMode == mode;

    return GestureDetector(
      onTap: () => setState(() => _selectedMode = mode),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? const Color.fromARGB(255, 56, 61, 65) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Radio<String>(
                  value: mode,
                  groupValue: _selectedMode,
                  onChanged: (value) => setState(() => _selectedMode = value),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),

            // Pros and Cons in two columns
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pros column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Advantages:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      ...pros.map(
                        (pro) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            pro,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Cons column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Limitations:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      ...cons.map(
                        (con) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            con,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmSelection() async {
    if (_selectedMode == null) return;

    try {
      // Update settings with selected mode
      await SettingsService.instance.updateSettings(
        (settings) => settings.copyWith(appMode: _selectedMode),
      );

      // Call callback if provided
      if (widget.onModeSelected != null) {
        widget.onModeSelected!(_selectedMode!);
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedMode == 'local'
                  ? 'Switched to Local Mode - Device will handle monitoring'
                  : 'Switched to Server Mode - Cloud monitoring enabled',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.of(context).pop(_selectedMode);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update mode: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
