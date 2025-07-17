import 'package:flutter/material.dart';
import '../models/matcha_product.dart';
import '../services/database_service.dart';
import '../services/smart_selector_service.dart';

class WebsiteManagementScreen extends StatefulWidget {
  const WebsiteManagementScreen({super.key});

  @override
  State<WebsiteManagementScreen> createState() =>
      _WebsiteManagementScreenState();
}

class _WebsiteManagementScreenState extends State<WebsiteManagementScreen> {
  final DatabaseService _db = DatabaseService();
  List<CustomWebsite> _websites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWebsites();
  }

  Future<void> _loadWebsites() async {
    setState(() => _isLoading = true);
    try {
      final websites = await _db.getCustomWebsites();
      setState(() {
        _websites = websites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading websites: $e')));
      }
    }
  }

  Future<void> _addWebsite() async {
    final result = await Navigator.push<CustomWebsite>(
      context,
      MaterialPageRoute(builder: (context) => const AddEditWebsiteScreen()),
    );

    if (result != null) {
      await _db.insertCustomWebsite(result);
      await _loadWebsites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Website added successfully')),
        );
      }
    }
  }

  Future<void> _editWebsite(CustomWebsite website) async {
    final result = await Navigator.push<CustomWebsite>(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditWebsiteScreen(website: website),
      ),
    );

    if (result != null) {
      await _db.updateCustomWebsite(result);
      await _loadWebsites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Website updated successfully')),
        );
      }
    }
  }

  Future<void> _deleteWebsite(CustomWebsite website) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Website'),
            content: Text(
              'Are you sure you want to delete "${website.name}"? This will also remove all products from this website.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _db.deleteCustomWebsite(website.id);
      await _loadWebsites();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Website deleted successfully')),
        );
      }
    }
  }

  Future<void> _toggleWebsite(CustomWebsite website) async {
    final updated = website.copyWith(isEnabled: !website.isEnabled);
    await _db.updateCustomWebsite(updated);
    await _loadWebsites();
  }

  Future<void> _testWebsite(CustomWebsite website) async {
    try {
      final smartSelector = SmartSelectorService.instance;

      // Test the existing selectors
      final selectors = {
        'productSelector': website.productSelector,
        'nameSelector': website.nameSelector,
        'priceSelector': website.priceSelector,
        'linkSelector': website.linkSelector,
        'stockSelector': website.stockSelector,
      };

      final testResults = await smartSelector.testSelectors(
        website.baseUrl,
        selectors,
      );

      await _db.updateWebsiteTestStatus(website.id, 'success');
      await _loadWebsites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Test completed! Found ${testResults['productCount']} products.\n'
              'Name: ${testResults['nameFound'] ? "✓" : "✗"} '
              'Price: ${testResults['priceFound'] ? "✓" : "✗"} '
              'Link: ${testResults['linkFound'] ? "✓" : "✗"}',
            ),
          ),
        );
      }
    } catch (e) {
      await _db.updateWebsiteTestStatus(website.id, 'failed');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Test failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [const Text('Website Management')]),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(),
            tooltip: 'Help',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _websites.isEmpty
              ? _buildEmptyState()
              : _buildWebsiteList(),
      floatingActionButton: FloatingActionButton(
        onPressed: _addWebsite,
        tooltip: 'Add Website',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          const Text(
            'No custom matcha websites added',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a matcha website to start monitoring its products',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            '✨ Now with smart auto-detection!',
            style: TextStyle(
              color: Colors.blue[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addWebsite,
            icon: const Icon(Icons.add),
            label: const Text('Add Website'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _websites.length,
      itemBuilder: (context, index) {
        final website = _websites[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            website.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            website.baseUrl,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: website.isEnabled,
                      onChanged: (_) => _toggleWebsite(website),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (website.testStatus != null) ...[
                  Row(
                    children: [
                      Icon(
                        website.testStatus == 'success'
                            ? Icons.check_circle
                            : Icons.error,
                        size: 16,
                        color:
                            website.testStatus == 'success'
                                ? Colors.green
                                : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Test ${website.testStatus}',
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              website.testStatus == 'success'
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                      if (website.lastTested != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Last tested: ${_formatDate(website.lastTested!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _testWebsite(website),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Test'),
                    ),
                    TextButton.icon(
                      onPressed: () => _editWebsite(website),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => _deleteWebsite(website),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Website Management Help'),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '🎯 Smart Auto-Detection',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Simply enter the website URL and click "Auto-Detect Settings"',
                  ),
                  Text(
                    '• Our AI will automatically find the best CSS selectors',
                  ),
                  Text('• Review and adjust the results if needed'),
                  SizedBox(height: 16),
                  Text(
                    '🛠️ Manual Configuration',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Product Selector: Select individual product containers',
                  ),
                  Text('• Name Selector: Select product name elements'),
                  Text('• Price Selector: Select price elements'),
                  Text(
                    '• Link Selector: Select link elements for product URLs',
                  ),
                  Text(
                    '• Stock Selector: Select elements that indicate if item is in stock',
                  ),
                  SizedBox(height: 16),
                  Text(
                    '💡 Tips:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• Try auto-detection first - it works for most websites',
                  ),
                  Text('• Use browser developer tools for manual selectors'),
                  Text('• Test your configuration before saving'),
                  Text(
                    '• Stock selector can be empty if stock is determined by text content',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it!'),
              ),
            ],
          ),
    );
  }
}

class AddEditWebsiteScreen extends StatefulWidget {
  final CustomWebsite? website;

  const AddEditWebsiteScreen({super.key, this.website});

  @override
  State<AddEditWebsiteScreen> createState() => _AddEditWebsiteScreenState();
}

class _AddEditWebsiteScreenState extends State<AddEditWebsiteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();
  final _productSelectorController = TextEditingController();
  final _nameSelectorController = TextEditingController();
  final _priceSelectorController = TextEditingController();
  final _linkSelectorController = TextEditingController();
  final _stockSelectorController = TextEditingController();
  final SmartSelectorService _smartSelector = SmartSelectorService.instance;

  bool get _isEditing => widget.website != null;
  bool _isAnalyzing = false;
  bool _showAdvanced = false;
  Map<String, dynamic>? _testResults;

  String _generateId() {
    final random = DateTime.now().millisecondsSinceEpoch;
    return 'custom_$random';
  }

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final website = widget.website!;
      _nameController.text = website.name;
      _urlController.text = website.baseUrl;
      _productSelectorController.text = website.productSelector;
      _nameSelectorController.text = website.nameSelector;
      _priceSelectorController.text = website.priceSelector;
      _linkSelectorController.text = website.linkSelector;
      _stockSelectorController.text = website.stockSelector;
      _showAdvanced = true; // Show advanced for existing websites
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _productSelectorController.dispose();
    _nameSelectorController.dispose();
    _priceSelectorController.dispose();
    _linkSelectorController.dispose();
    _stockSelectorController.dispose();
    super.dispose();
  }

  Future<void> _analyzeWebsite() async {
    if (_urlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a URL first')));
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _testResults = null;
    });

    try {
      final selectors = await _smartSelector.analyzeWebsite(
        _urlController.text.trim(),
      );

      _productSelectorController.text = selectors['productSelector'] ?? '';
      _nameSelectorController.text = selectors['nameSelector'] ?? '';
      _priceSelectorController.text = selectors['priceSelector'] ?? '';
      _linkSelectorController.text = selectors['linkSelector'] ?? '';
      _stockSelectorController.text = selectors['stockSelector'] ?? '';

      // Test the selectors
      final testResults = await _smartSelector.testSelectors(
        _urlController.text.trim(),
        selectors,
      );

      setState(() {
        _testResults = testResults;
        _showAdvanced = true;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Found ${testResults['productCount']} products! Review the settings below.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analysis failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _showAdvanced = true; // Show manual configuration on failure
        });
      }
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final website = CustomWebsite(
        id: _isEditing ? widget.website!.id : _generateId(),
        name: _nameController.text.trim(),
        baseUrl: _urlController.text.trim(),
        productSelector: _productSelectorController.text.trim(),
        nameSelector: _nameSelectorController.text.trim(),
        priceSelector: _priceSelectorController.text.trim(),
        linkSelector: _linkSelectorController.text.trim(),
        stockSelector: _stockSelectorController.text.trim(),
        isEnabled: _isEditing ? widget.website!.isEnabled : true,
        createdAt: _isEditing ? widget.website!.createdAt : DateTime.now(),
        lastTested: widget.website?.lastTested,
        testStatus: widget.website?.testStatus,
      );

      Navigator.pop(context, website);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Website' : 'Add Website'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Basic Information
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Website Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Website Name',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., My Tea Shop',
                        prefixIcon: Icon(Icons.store),
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Please enter a website name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Website URL',
                        border: OutlineInputBorder(),
                        hintText: 'https://example.com/products',
                        prefixIcon: Icon(Icons.link),
                      ),
                      validator: (value) {
                        if (value?.trim().isEmpty ?? true) {
                          return 'Please enter a URL';
                        }
                        final uri = Uri.tryParse(value!);
                        if (uri == null ||
                            !uri.hasScheme ||
                            !uri.hasAuthority) {
                          return 'Please enter a valid URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (!_showAdvanced)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isAnalyzing ? null : _analyzeWebsite,
                          icon:
                              _isAnalyzing
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.auto_fix_high),
                          label: Text(
                            _isAnalyzing
                                ? 'Analyzing...'
                                : 'Auto-Detect Settings',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                    if (!_showAdvanced) const SizedBox(height: 8),
                    if (!_showAdvanced)
                      TextButton.icon(
                        onPressed: () => setState(() => _showAdvanced = true),
                        icon: const Icon(Icons.settings),
                        label: const Text('Manual Configuration'),
                      ),
                  ],
                ),
              ),
            ),

            // Test Results
            if (_testResults != null) ...[
              const SizedBox(height: 16),
              Card(
                color:
                    _testResults!['productCount'] > 0
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _testResults!['productCount'] > 0
                                ? Icons.check_circle
                                : Icons.error,
                            color:
                                _testResults!['productCount'] > 0
                                    ? Colors.green
                                    : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Analysis Results',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Products found: ${_testResults!['productCount']}'),
                      if (_testResults!['sampleName'].isNotEmpty)
                        Text('Sample name: "${_testResults!['sampleName']}"'),
                      if (_testResults!['samplePrice'].isNotEmpty)
                        Text('Sample price: "${_testResults!['samplePrice']}"'),

                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          _buildStatusChip('Name', _testResults!['nameFound']),
                          _buildStatusChip(
                            'Price',
                            _testResults!['priceFound'],
                          ),
                          _buildStatusChip('Link', _testResults!['linkFound']),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Advanced Configuration
            if (_showAdvanced) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.code),
                          const SizedBox(width: 8),
                          const Text(
                            'CSS Selectors',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (_showAdvanced && !_isEditing)
                            TextButton.icon(
                              onPressed:
                                  () => setState(() {
                                    _showAdvanced = false;
                                    _testResults = null;
                                  }),
                              icon: const Icon(Icons.auto_fix_high),
                              label: const Text('Auto-Detect'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Use browser developer tools to find the correct CSS selectors for each element.',
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      _buildSelectorField(
                        controller: _productSelectorController,
                        label: 'Product Selector',
                        hint: '.product-item, .card-wrapper',
                        description: 'Selects individual product containers',
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),
                      _buildSelectorField(
                        controller: _nameSelectorController,
                        label: 'Name Selector',
                        hint: '.product-name, h3',
                        description: 'Selects product name elements',
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),
                      _buildSelectorField(
                        controller: _priceSelectorController,
                        label: 'Price Selector',
                        hint: '.price, .cost',
                        description: 'Selects price elements',
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),
                      _buildSelectorField(
                        controller: _linkSelectorController,
                        label: 'Link Selector',
                        hint: 'a, .product-link',
                        description: 'Selects link elements for product URLs',
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),
                      _buildSelectorField(
                        controller: _stockSelectorController,
                        label: 'Stock Selector (Optional)',
                        hint: '.in-stock, .add-to-cart',
                        description:
                            'Selects elements that indicate if item is in stock. Leave empty if stock is determined by text content.',
                        isRequired: false,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, bool found) {
    return Chip(
      label: Text(label),
      avatar: Icon(
        found ? Icons.check : Icons.close,
        size: 16,
        color: found ? Colors.green : Colors.red,
      ),
      backgroundColor: found ? Colors.green.shade100 : Colors.red.shade100,
    );
  }

  Widget _buildSelectorField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String description,
    required bool isRequired,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            hintText: hint,
            prefixIcon: const Icon(Icons.code),
          ),
          validator:
              isRequired
                  ? (value) {
                    if (value?.trim().isEmpty ?? true) {
                      return 'Please enter a ${label.toLowerCase()}';
                    }
                    return null;
                  }
                  : null,
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
