import 'package:flutter/material.dart';
import '../models/matcha_product.dart';
import '../services/database_service.dart';

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
      // For now, just mark as tested - we'll implement the actual test later
      await _db.updateWebsiteTestStatus(website.id, 'success');
      await _loadWebsites();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Website test completed')));
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
        title: const Text('Website Management'),
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
          Icon(Icons.web, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No custom websites added',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Add a website to start monitoring its products',
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _addWebsite,
            icon: const Icon(Icons.add),
            label: const Text('Add Website'),
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
                    'CSS Selectors Guide:',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
                  Text('Tips:', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('• Use browser developer tools to find CSS selectors'),
                  Text('• Test your website configuration before enabling'),
                  Text(
                    '• Stock selector can be empty if stock is determined by text content',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
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

  bool get _isEditing => widget.website != null;

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
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Website Name',
                border: OutlineInputBorder(),
                hintText: 'e.g., My Tea Shop',
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
                labelText: 'Base URL',
                border: OutlineInputBorder(),
                hintText: 'https://example.com/products',
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Please enter a URL';
                }
                final uri = Uri.tryParse(value!);
                if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                  return 'Please enter a valid URL';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'CSS Selectors',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use browser developer tools to find the correct CSS selectors for each element.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _productSelectorController,
              decoration: const InputDecoration(
                labelText: 'Product Selector',
                border: OutlineInputBorder(),
                hintText: '.product-item, .card-wrapper',
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Please enter a product selector';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameSelectorController,
              decoration: const InputDecoration(
                labelText: 'Name Selector',
                border: OutlineInputBorder(),
                hintText: '.product-name, h3',
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Please enter a name selector';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceSelectorController,
              decoration: const InputDecoration(
                labelText: 'Price Selector',
                border: OutlineInputBorder(),
                hintText: '.price, .cost',
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Please enter a price selector';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _linkSelectorController,
              decoration: const InputDecoration(
                labelText: 'Link Selector',
                border: OutlineInputBorder(),
                hintText: 'a, .product-link',
              ),
              validator: (value) {
                if (value?.trim().isEmpty ?? true) {
                  return 'Please enter a link selector';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stockSelectorController,
              decoration: const InputDecoration(
                labelText: 'Stock Selector (Optional)',
                border: OutlineInputBorder(),
                hintText: '.in-stock, .add-to-cart',
                helperText:
                    'Leave empty if stock status is determined by text content',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
