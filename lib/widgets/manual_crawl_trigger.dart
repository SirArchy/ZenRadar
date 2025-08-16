// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import '../services/cloud_crawler_service.dart';

/// Widget to trigger manual crawls in server mode
class ManualCrawlTrigger extends StatefulWidget {
  final String userId;
  final List<String> availableSites;
  final VoidCallback? onCrawlTriggered;

  const ManualCrawlTrigger({
    super.key,
    required this.userId,
    required this.availableSites,
    this.onCrawlTriggered,
  });

  @override
  State<ManualCrawlTrigger> createState() => _ManualCrawlTriggerState();
}

class _ManualCrawlTriggerState extends State<ManualCrawlTrigger> {
  final CloudCrawlerService _crawlerService = CloudCrawlerService.instance;

  bool _isTriggering = false;
  String? _lastRequestId;
  String? _lastError;
  Set<String> _selectedSites = {};

  @override
  void initState() {
    super.initState();
    _selectedSites = Set.from(widget.availableSites);
  }

  Future<void> _triggerCrawl() async {
    if (_isTriggering) return;

    setState(() {
      _isTriggering = true;
      _lastError = null;
    });

    try {
      final requestId = await _crawlerService.triggerCrawlSimple(
        sites: _selectedSites.toList(),
        userId: widget.userId,
      );

      setState(() {
        _lastRequestId = requestId;
      });

      if (widget.onCrawlTriggered != null) {
        widget.onCrawlTriggered!();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Crawl triggered successfully! ID: $requestId'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _lastError = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to trigger crawl: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isTriggering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(Icons.cloud_sync, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Manual Crawl',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Site selection
            const Text(
              'Select sites to crawl:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 4,
              children:
                  widget.availableSites.map((site) {
                    final isSelected = _selectedSites.contains(site);
                    return FilterChip(
                      label: Text(site),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedSites.add(site);
                          } else {
                            _selectedSites.remove(site);
                          }
                        });
                      },
                    );
                  }).toList(),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed:
                      _selectedSites.isNotEmpty && !_isTriggering
                          ? _triggerCrawl
                          : null,
                  icon:
                      _isTriggering
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.play_arrow),
                  label: Text(_isTriggering ? 'Triggering...' : 'Start Crawl'),
                ),

                const SizedBox(width: 8),

                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedSites = Set.from(widget.availableSites);
                    });
                  },
                  icon: const Icon(Icons.select_all),
                  label: const Text('Select All'),
                ),

                const SizedBox(width: 8),

                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedSites.clear();
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('Clear All'),
                ),
              ],
            ),

            // Status display
            if (_lastRequestId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withAlpha(75)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Last crawl request: $_lastRequestId',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_lastError != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withAlpha(75)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error: $_lastError',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Server health status widget
class ServerHealthWidget extends StatefulWidget {
  const ServerHealthWidget({super.key});

  @override
  State<ServerHealthWidget> createState() => _ServerHealthWidgetState();
}

class _ServerHealthWidgetState extends State<ServerHealthWidget> {
  final CloudCrawlerService _crawlerService = CloudCrawlerService.instance;

  ServerHealthStatus? _healthStatus;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    setState(() {
      _isChecking = true;
    });

    try {
      final status = await _crawlerService.checkServerHealth();
      setState(() {
        _healthStatus = status;
      });
    } catch (e) {
      setState(() {
        _healthStatus = ServerHealthStatus(
          isHealthy: false,
          lastCrawlTime: null,
          recentCrawlCount: 0,
          message: 'Error checking health: $e',
        );
      });
    } finally {
      setState(() {
        _isChecking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _healthStatus?.isHealthy == true
                      ? Icons.health_and_safety
                      : Icons.warning,
                  color:
                      _healthStatus?.isHealthy == true
                          ? Colors.green
                          : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Server Status',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _isChecking ? null : _checkHealth,
                  icon:
                      _isChecking
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.refresh),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_healthStatus != null) ...[
              // Status indicator
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (_healthStatus!.isHealthy
                          ? Colors.green
                          : Colors.orange)
                      .withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (_healthStatus!.isHealthy
                            ? Colors.green
                            : Colors.orange)
                        .withAlpha(75),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _healthStatus!.isHealthy
                          ? Icons.check_circle
                          : Icons.warning,
                      color:
                          _healthStatus!.isHealthy
                              ? Colors.green
                              : Colors.orange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _healthStatus!.message,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Additional info
              if (_healthStatus!.lastCrawlTime != null) ...[
                Text(
                  'Last activity: ${_formatTime(_healthStatus!.lastCrawlTime!)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],

              Text(
                'Recent crawls: ${_healthStatus!.recentCrawlCount}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ] else ...[
              const Center(child: Text('Checking server status...')),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
