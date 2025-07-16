// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/matcha_product.dart';
import '../services/database_service.dart';
import '../services/background_service.dart';
import '../services/settings_service.dart';
import '../services/crawler_service.dart';
import '../widgets/product_card.dart';
import '../widgets/product_filters.dart';
import 'settings_screen.dart';
import 'crawler_activity_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  PaginatedProducts? _paginatedProducts;
  bool _isLoading = false;
  bool _isServiceRunning = false;
  bool _isFullCheckRunning = false;
  bool _showFilters = false;

  // Filter and pagination state
  ProductFilter _filter = ProductFilter();
  int _currentPage = 1;
  UserSettings _userSettings = UserSettings();

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Available filter options
  List<String> _availableSites = ['All'];
  List<String> _availableCategories = [];
  Map<String, double> _priceRange = {'min': 0.0, 'max': 1000.0};
  StorageInfo? _storageInfo;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadFilterOptions();
    _loadProducts();
    if (!kIsWeb) {
      _checkServiceStatus();
    }
    _loadStorageInfo();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await SettingsService.instance.getSettings();
    setState(() {
      _userSettings = settings;
    });
  }

  Future<void> _loadFilterOptions() async {
    try {
      final sites = ['All', 'Nakamura', 'Marukyu-Koyamaen', 'Ippodo Tea'];
      final categories =
          await DatabaseService.platformService.getAvailableCategories();
      final priceRange = await DatabaseService.platformService.getPriceRange();

      setState(() {
        _availableSites = sites;
        _availableCategories = categories;
        _priceRange = priceRange;
      });
    } catch (e) {
      print('Error loading filter options: $e');
    }
  }

  Future<void> _loadStorageInfo() async {
    try {
      final storageInfo = await DatabaseService.platformService.getStorageInfo(
        _userSettings.maxStorageMB,
      );
      setState(() {
        _storageInfo = storageInfo;
      });
    } catch (e) {
      print('Error loading storage info: $e');
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final paginatedProducts = await DatabaseService.platformService
          .getProductsPaginated(
            page: _currentPage,
            itemsPerPage: _userSettings.itemsPerPage,
            filter: _filter,
            sortBy: _userSettings.sortBy,
            sortAscending: _userSettings.sortAscending,
          );

      setState(() {
        _paginatedProducts = paginatedProducts;
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

  Future<void> _performLightweightCheck() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // On web or when testing: Direct crawler call
      if (kIsWeb) {
        final crawler = CrawlerService.instance;
        await crawler.crawlAllSites();
      } else {
        // On mobile: Use background service
        await BackgroundServiceController.instance.triggerManualCheck();
      }

      // Wait a moment for the check to complete
      await Future.delayed(const Duration(seconds: 2));

      // Reload products
      await _loadProducts();
      await _loadStorageInfo();

      _showSuccessSnackBar('Stock check completed!');
    } catch (e) {
      _showErrorSnackBar('Failed to check stock: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _performFullCheck() async {
    setState(() {
      _isFullCheckRunning = true;
    });

    try {
      // Perform a comprehensive crawl of all sites
      final crawler = CrawlerService.instance;
      List<MatchaProduct> products = await crawler.crawlAllSites();

      _showSuccessSnackBar(
        'Full discovery completed! Found ${products.length} products.',
      );

      // Reload products and options
      await _loadProducts();
      await _loadFilterOptions();
      await _loadStorageInfo();
    } catch (e) {
      _showErrorSnackBar('Failed to perform full check: $e');
    } finally {
      setState(() {
        _isFullCheckRunning = false;
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

  void _onFilterChanged(ProductFilter newFilter) {
    setState(() {
      _filter = newFilter;
      _currentPage = 1; // Reset to first page when filter changes
    });
    _loadProducts();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      // Update the filter with the search query
      _filter = _filter.copyWith(searchTerm: query);
      _currentPage = 1; // Reset to first page when search changes
    });
    _loadProducts();
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    _loadProducts();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ZenRadar'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_userSettings.headModeEnabled && !kIsWeb)
            IconButton(
              icon: const Icon(Icons.timeline),
              tooltip: 'Crawler Activity',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CrawlerActivityScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
              // Reload settings when returning from settings screen
              await _loadSettings();
              await _loadProducts();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Service status banner (mobile only)
          if (!kIsWeb) _buildServiceStatusBanner(),

          // Storage info banner
          if (_storageInfo != null) _buildStorageInfoBanner(),

          // Search bar
          _buildSearchBar(),

          // Filters panel
          if (_showFilters)
            ProductFilters(
              filter: _filter,
              onFilterChanged: _onFilterChanged,
              availableSites: _availableSites,
              availableCategories: _availableCategories,
              priceRange: _priceRange,
            ),

          // Products list with pagination
          Expanded(child: _buildProductsList()),
        ],
      ),
      floatingActionButton: _buildFloatingActionButtons(),
    );
  }

  Widget _buildServiceStatusBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color:
            _isServiceRunning ? Colors.green.shade100 : Colors.orange.shade100,
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
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search matcha products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 12.0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter button
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list : Icons.filter_list_outlined,
              color: _showFilters ? Theme.of(context).primaryColor : null,
            ),
            tooltip: 'Filters',
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStorageInfoBanner() {
    if (_storageInfo == null) return const SizedBox.shrink();

    final info = _storageInfo!;
    final isNearLimit = info.usagePercentage > 80;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isNearLimit ? Colors.orange.shade100 : Colors.blue.shade50,
        border: Border(
          bottom: BorderSide(
            color: isNearLimit ? Colors.orange : Colors.blue,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isNearLimit ? Icons.warning : Icons.storage,
            color: isNearLimit ? Colors.orange : Colors.blue,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Storage: ${info.formattedSize} / ${info.formattedMaxSize} (${info.usagePercentage.toStringAsFixed(1)}%) • ${info.totalProducts} products',
              style: TextStyle(
                color:
                    isNearLimit ? Colors.orange.shade700 : Colors.blue.shade700,
                fontSize: 12,
              ),
            ),
          ),
          if (isNearLimit)
            TextButton(
              onPressed: () async {
                await DatabaseService.platformService.cleanupOldProducts(
                  _userSettings.maxStorageMB,
                );
                await _loadStorageInfo();
                _showSuccessSnackBar('Storage cleaned up!');
              },
              child: const Text('Clean Up', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_paginatedProducts == null || _paginatedProducts!.products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or run a full check to discover new products',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Products grid/list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadProducts,
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _paginatedProducts!.products.length,
              itemBuilder: (context, index) {
                return ProductCard(
                  product: _paginatedProducts!.products[index],
                  onTap: () {
                    _showProductDetails(_paginatedProducts!.products[index]);
                  },
                );
              },
            ),
          ),
        ),

        // Pagination controls
        if (_paginatedProducts!.totalPages > 1) _buildPaginationControls(),
      ],
    );
  }

  Widget _buildPaginationControls() {
    final pagination = _paginatedProducts!;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous page button
          ElevatedButton.icon(
            onPressed:
                pagination.currentPage > 1
                    ? () => _goToPage(pagination.currentPage - 1)
                    : null,
            icon: const Icon(Icons.chevron_left),
            label: const Text('Previous'),
          ),

          // Page indicator
          Text(
            'Page ${pagination.currentPage} of ${pagination.totalPages} (${pagination.totalItems} items)',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),

          // Next page button
          ElevatedButton.icon(
            onPressed:
                pagination.currentPage < pagination.totalPages
                    ? () => _goToPage(pagination.currentPage + 1)
                    : null,
            icon: const Icon(Icons.chevron_right),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Full Check FAB
        FloatingActionButton.extended(
          onPressed:
              _isLoading || _isFullCheckRunning ? null : _performFullCheck,
          heroTag: "fullCheck",
          backgroundColor: Colors.deepPurple,
          icon:
              _isFullCheckRunning
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Icon(Icons.search, color: Colors.white),
          label: Text(
            _isFullCheckRunning ? 'Discovering...' : 'Run Full Check',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),

        // Quick Check FAB
        FloatingActionButton.extended(
          onPressed:
              _isLoading || _isFullCheckRunning
                  ? null
                  : _performLightweightCheck,
          heroTag: "quickCheck",
          icon:
              _isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Icon(Icons.refresh),
          label: Text(_isLoading ? 'Checking...' : 'Quick Check'),
        ),
      ],
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
