import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/settings_service.dart';

class SiteSelectionDialog extends StatefulWidget {
  final List<String> availableSites;
  final List<String> selectedSites;
  final bool includeCustomSites;

  const SiteSelectionDialog({
    super.key,
    required this.availableSites,
    required this.selectedSites,
    this.includeCustomSites = true,
  });

  @override
  State<SiteSelectionDialog> createState() => _SiteSelectionDialogState();
}

class _SiteSelectionDialogState extends State<SiteSelectionDialog> {
  late Set<String> _selectedSites;
  final bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSites = Set.from(widget.selectedSites);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.web_stories, color: Colors.blue),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              l10n.selectSitesToScan,
              style: const TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.chooseWhichMatcha,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // Select All / Deselect All
            CheckboxListTile(
              title: Text(
                l10n.selectAllSites,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${_selectedSites.length} ${l10n.ofSelected(widget.availableSites.length)}',
              ),
              value:
                  _selectedSites.length == widget.availableSites.length
                      ? true
                      : _selectedSites.isEmpty
                      ? false
                      : null,
              tristate: true,
              onChanged: (value) {
                setState(() {
                  if (_selectedSites.length == widget.availableSites.length) {
                    _selectedSites.clear();
                  } else {
                    _selectedSites = Set.from(widget.availableSites);
                  }
                });
              },
              dense: true,
            ),
            const Divider(),
            // Site list
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.availableSites.length,
                  itemBuilder: (context, index) {
                    final site = widget.availableSites[index];
                    final isSelected = _selectedSites.contains(site);

                    return CheckboxListTile(
                      title: Text(site),
                      subtitle: _getSiteDescription(site),
                      value: isSelected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selectedSites.add(site);
                          } else {
                            _selectedSites.remove(site);
                          }
                        });
                      },
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Scan time estimate
            if (_selectedSites.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timer, size: 16, color: Colors.blue.shade600),
                    const SizedBox(width: 8),
                    Text(
                      '${l10n.estimatedTime} ${_getEstimatedTime()}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton.icon(
          onPressed:
              _isLoading || _selectedSites.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selectedSites.toList()),
          icon:
              _isLoading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.radar),
          label: Text(_isLoading ? l10n.starting : l10n.startScan),
        ),
      ],
    );
  }

  Widget? _getSiteDescription(String site) {
    final descriptions = {
      'tokichi': 'Traditional Japanese matcha',
      'ippodo': 'Premium tea house',
      'marukyu': 'Historic Kyoto tea company',
      'poppatea': 'Authentic Japanese matcha sent from Sweden',
      'horiishichimeien': 'Modern matcha experience',
      'yoshien': 'German matcha retailer',
      'matcha-karu': 'Organic matcha specialist',
      'sho-cha': 'Artisan tea collection',
      'sazentea': 'Japanese tea direct import',
      'enjoyemeri': 'Curated tea selection',
    };

    final description = descriptions[site];
    if (description != null) {
      return Text(
        description,
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      );
    }
    return null;
  }

  String _getEstimatedTime() {
    final siteCount = _selectedSites.length;
    if (siteCount <= 2) {
      return '30-60 seconds';
    } else if (siteCount <= 5) {
      return '1-2 minutes';
    } else if (siteCount <= 8) {
      return '2-3 minutes';
    } else {
      return '3-5 minutes';
    }
  }
}

/// Shows a dialog to select which sites to scan
/// Returns a list of selected site keys, or null if cancelled
Future<List<String>?> showSiteSelectionDialog({
  required BuildContext context,
  required List<String> availableSites,
  List<String>? preSelectedSites,
  bool includeCustomSites = true,
}) async {
  // Get current user settings to pre-select enabled sites
  final settings = await SettingsService.instance.getSettings();
  final defaultSelected = preSelectedSites ?? settings.enabledSites;

  return await showDialog<List<String>>(
    // ignore: use_build_context_synchronously
    context: context,
    barrierDismissible: false,
    builder:
        (context) => SiteSelectionDialog(
          availableSites: availableSites,
          selectedSites: defaultSelected,
          includeCustomSites: includeCustomSites,
        ),
  );
}
