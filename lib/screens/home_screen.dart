import 'package:flutter/material.dart';
import '../models/matcha_product.dart';
import '../services/database_service.dart';
import '../services/background_service.dart';
import '../widgets/product_card.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<MatchaProduct> _products = [];
  bool _isLoading = false;
  bool _isServiceRunning = false;
  String _selectedSite = 'All';

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _checkServiceStatus();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<MatchaProduct> products =
          await DatabaseService.instance.getAllProducts();
      setState(() {
        _products = products;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to load products: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkServiceStatus() async {
    bool isRunning =
        await BackgroundServiceController.instance.isServiceRunning();
    setState(() {
      _isServiceRunning = isRunning;
    });
  }

  Future<void> _performManualCheck() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Trigger manual check via background service
      await BackgroundServiceController.instance.triggerManualCheck();

      // Wait a moment for the check to complete
      await Future.delayed(const Duration(seconds: 2));

      // Reload products
      await _loadProducts();

      _showSuccessSnackBar('Stock check completed!');
    } catch (e) {
      _showErrorSnackBar('Failed to check stock: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBackgroundService() async {
    try {
      if (_isServiceRunning) {
        await BackgroundServiceController.instance.stopService();
        _showSuccessSnackBar('Background monitoring stopped');
      } else {
        await BackgroundServiceController.instance.startService();
        _showSuccessSnackBar('Background monitoring started');
      }
      await _checkServiceStatus();
    } catch (e) {
      _showErrorSnackBar('Failed to toggle service: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  List<MatchaProduct> get _filteredProducts {
    if (_selectedSite == 'All') {
      return _products;
    }
    return _products.where((product) => product.site == _selectedSite).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZenRadar'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _performManualCheck,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Service status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color:
                  _isServiceRunning
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
              border: Border(
                bottom: BorderSide(
                  color: _isServiceRunning ? Colors.green : Colors.orange,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isServiceRunning ? Icons.check_circle : Icons.warning,
                  color: _isServiceRunning ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isServiceRunning
                        ? 'Background monitoring is active'
                        : 'Background monitoring is paused',
                    style: TextStyle(
                      color:
                          _isServiceRunning
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: _toggleBackgroundService,
                  child: Text(_isServiceRunning ? 'Stop' : 'Start'),
                ),
              ],
            ),
          ),

          // Site filter
          Container(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              value: _selectedSite,
              decoration: const InputDecoration(
                labelText: 'Filter by Site',
                border: OutlineInputBorder(),
              ),
              items:
                  ['All', 'Tokichi', 'Marukyu-Koyamaen', 'Ippodo Tea']
                      .map(
                        (site) =>
                            DropdownMenuItem(value: site, child: Text(site)),
                      )
                      .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSite = value!;
                });
              },
            ),
          ),

          // Products list
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredProducts.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No products found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap the refresh button to check for matcha products',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _loadProducts,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16.0),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          return ProductCard(
                            product: _filteredProducts[index],
                            onTap: () {
                              // In a real app, you might open product details
                              _showProductDetails(_filteredProducts[index]);
                            },
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _performManualCheck,
        icon:
            _isLoading
                ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.radar),
        label: Text(_isLoading ? 'Checking...' : 'Check Stock'),
      ),
    );
  }

  void _showProductDetails(MatchaProduct product) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(product.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Site: ${product.site}'),
                const SizedBox(height: 8),
                Text(
                  'Status: ${product.isInStock ? "In Stock" : "Out of Stock"}',
                ),
                const SizedBox(height: 8),
                if (product.price != null) ...[
                  Text('Price: ${product.price}'),
                  const SizedBox(height: 8),
                ],
                Text(
                  'Last Checked: ${product.lastChecked.toString().substring(0, 16)}',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if (product.url.isNotEmpty)
                TextButton(
                  onPressed: () {
                    // In a real app, you'd open the URL
                    Navigator.pop(context);
                    _showSuccessSnackBar('Would open: ${product.url}');
                  },
                  child: const Text('View Product'),
                ),
            ],
          ),
    );
  }
}
