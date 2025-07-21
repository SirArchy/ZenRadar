// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/matcha_product.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/crawler_service.dart';
import '../services/crawler_logger.dart';
import '../services/background_service.dart';
import '../widgets/product_card.dart';
import '../widgets/product_filters.dart';
import '../widgets/matcha_icon.dart';
import '../widgets/site_selection_dialog.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Product state for endless loading
  List<MatchaProduct> _products = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreProducts = true;
  bool _isFullCheckRunning = false;
  bool _showFilters = false;

  // Endless loading state
  ProductFilter _filter = ProductFilter();
  int _currentPage = 1;
  UserSettings _userSettings = UserSettings();
  final ScrollController _scrollController = ScrollController();

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Available filter options
  List<String> _availableSites = ['All'];
  List<String> _availableCategories = [];
  Map<String, double> _priceRange = {'min': 0.0, 'max': 1000.0};

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadFilterOptions();
    _loadProducts();

    // Setup endless scroll listener
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
      // Built-in sites
      List<String> sites = [
        'All',
        'Nakamura Tokichi',
        'Marukyu-Koyamaen',
        'Ippodo Tea',
        'Yoshi En',
        'Matcha Kāru',
        'Sho-Cha',
        'Sazen Tea',
        'Mamecha',
        'Emeri',
      ];

      // Add custom websites
      final customWebsites =
          await DatabaseService.platformService.getCustomWebsites();
      sites.addAll(customWebsites.map((w) => w.name).cast<String>());

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

  Future<void> _loadProducts({bool loadMore = false}) async {
    if (loadMore) {
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMoreProducts = true;
      });
    }

    try {
      print('Loading products with filter: ${_filter.toString()}');

      final paginatedProducts = await DatabaseService.platformService
          .getProductsPaginated(
            page: _currentPage,
            itemsPerPage: _userSettings.itemsPerPage,
            filter: _filter,
            sortBy: _userSettings.sortBy,
            sortAscending: _userSettings.sortAscending,
          );

      print(
        'Found ${paginatedProducts.products.length} products on page $_currentPage',
      );
      print(
        'Total pages: ${paginatedProducts.totalPages}, Total items: ${paginatedProducts.totalItems}',
      );

      setState(() {
        if (loadMore) {
          // Append new products to existing list
          _products.addAll(paginatedProducts.products);
          _currentPage++;
        } else {
          // Replace products with new ones (initial load or filter change)
          _products = paginatedProducts.products;
          _currentPage = 2; // Next page to load
        }

        // Check if there are more products to load
        _hasMoreProducts = _currentPage <= paginatedProducts.totalPages;
      });
    } catch (e) {
      print('Error loading products: $e');
      _showErrorSnackBar('Failed to load products: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  // Scroll listener for endless loading
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMoreProducts) {
      _loadProducts(loadMore: true);
    }
  }

  Future<void> _performComprehensiveScan() async {
    setState(() {
      _isFullCheckRunning = true;
    });

    try {
      final crawler = CrawlerService.instance;
      List<MatchaProduct> products;

      // Check if this is the first scan by looking at existing products
      final db = DatabaseService.platformService;
      final existingProducts = await db.getAllProducts();
      final isFirstScan = existingProducts.isEmpty;

      if (isFirstScan) {
        // For first scan, use all enabled sites from settings
        _showScanProgressDialog();
        products = await crawler.crawlAllSites();
      } else {
        // For subsequent scans, show site selection dialog
        final availableSites = crawler.getSiteNamesMap();

        // Convert enabled site keys to display names for pre-selection
        final enabledSiteKeys = _userSettings.enabledSites;
        final preSelectedSiteNames =
            enabledSiteKeys
                .where((key) => availableSites.containsKey(key))
                .map((key) => availableSites[key]!)
                .toList();

        final selectedSiteKeys = await showSiteSelectionDialog(
          context: context,
          availableSites: availableSites.values.toList(),
          preSelectedSites: preSelectedSiteNames,
        );

        if (selectedSiteKeys == null || selectedSiteKeys.isEmpty) {
          // User cancelled or didn't select any sites
          return;
        }

        // Convert display names back to site keys
        final siteKeysToScan = <String>[];
        for (final selectedName in selectedSiteKeys) {
          final siteKey =
              availableSites.entries
                  .firstWhere((entry) => entry.value == selectedName)
                  .key;
          siteKeysToScan.add(siteKey);
        }

        // Show progress dialog and perform selected scan
        _showScanProgressDialog();
        products = await crawler.crawlSelectedSites(siteKeysToScan);
      }

      // Dismiss loading dialog
      Navigator.of(context).pop();

      // Show success message with more details about enabled sites
      final scannedSiteCount = products.map((p) => p.site).toSet().length;

      _showSuccessSnackBar(
        'Scan completed! Found ${products.length} products from $scannedSiteCount sites.',
      );

      // Reload products and options
      await _loadProducts();
      await _loadFilterOptions();
    } catch (e) {
      // Dismiss loading dialog if still open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      _showErrorSnackBar('Failed to perform scan: $e');
    } finally {
      setState(() {
        _isFullCheckRunning = false;
      });
    }
  }

  Future<void> _performBackgroundCheck() async {
    try {
      await BackgroundServiceController.instance.triggerManualCheck();

      _showSuccessSnackBar(
        'Background stock check started! Check notifications for progress.',
      );
    } catch (e) {
      _showErrorSnackBar('Failed to start background check: $e');
    }
  }

  void _showScanProgressDialog() {
    // Count enabled sites for better user feedback
    final enabledBuiltInSites = _userSettings.enabledSites.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => StreamBuilder<CrawlerActivity>(
            stream: CrawlerLogger.instance.activityStream,
            builder: (context, snapshot) {
              String currentSite = 'Initializing...';
              String status = 'Preparing to scan enabled sites...';

              if (snapshot.hasData) {
                final activity = snapshot.data!;
                currentSite = activity.siteName ?? 'System';
                status = activity.message;
              }

              return AlertDialog(
                title: Row(
                  children: [
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    const Text('Scanning Sites'),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enabled Sites: $enabledBuiltInSites built-in sites',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Current Site:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(currentSite, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    Text(
                      'Status:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(status, style: const TextStyle(fontSize: 14)),
                  ],
                ),
              );
            },
          ),
    );
  }

  void _onFilterChanged(ProductFilter newFilter) {
    setState(() {
      _filter = newFilter;
    });
    _loadProducts(); // Reset products when filter changes
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      // Update the filter with the search query
      _filter = _filter.copyWith(searchTerm: query);
    });
    _loadProducts(); // Reset products when search changes
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
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
        title: Row(
          children: [
            const MatchaIcon(size: 24, withSteam: false),
            const SizedBox(width: 8),
            const Text('ZenRadar'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
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
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Search bar
              _buildSearchBar(),

              // Products list with pagination
              Expanded(child: _buildProductsList()),
            ],
          ),

          // Floating Action Button positioned in the stack
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildFloatingActionButtons(),
          ),

          // Filter overlay
          if (_showFilters)
            GestureDetector(
              onTap: () {
                setState(() {
                  _showFilters = false;
                });
              },
              child: Container(
                color: Colors.black54,
                child: GestureDetector(
                  onTap: () {}, // Prevent closing when tapping inside filter
                  child: DraggableScrollableSheet(
                    initialChildSize: 0.6,
                    minChildSize: 0.3,
                    maxChildSize: 0.9,
                    builder: (context, scrollController) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: ProductFilters(
                          filter: _filter,
                          onFilterChanged: _onFilterChanged,
                          availableSites: _availableSites,
                          availableCategories: _availableCategories,
                          priceRange: _priceRange,
                          scrollController: scrollController,
                          onClose: () {
                            setState(() {
                              _showFilters = false;
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          // Search input row
          Row(
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
                      borderSide: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                      ),
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

          // Stock status chips
          const SizedBox(height: 12),
          _buildStockStatusChips(),
        ],
      ),
    );
  }

  Widget _buildStockStatusChips() {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilterChip(
                label: const Text('All'),
                selected:
                    _filter.inStock == null &&
                    (_filter.sites == null || _filter.sites!.isEmpty) &&
                    _filter.category == null &&
                    _filter.minPrice == null &&
                    _filter.maxPrice == null &&
                    (_filter.searchTerm == null || _filter.searchTerm!.isEmpty),
                onSelected: (_) {
                  // Clear all filters to show all products
                  setState(() {
                    _filter = ProductFilter(); // Reset to default empty filter
                    _searchQuery = '';
                    _searchController.clear();
                    _currentPage = 1;
                    _hasMoreProducts = true;
                  });
                  _loadProducts();
                },
                selectedColor: Theme.of(
                  context,
                ).primaryColor.withValues(alpha: 0.2),
                checkmarkColor: Theme.of(context).primaryColor,
              ),
              FilterChip(
                label: const Text('In Stock'),
                selected: _filter.inStock == true,
                onSelected: (_) {
                  setState(() {
                    _filter = _filter.copyWith(
                      inStock: _filter.inStock == true ? null : true,
                    );
                    _currentPage = 1;
                    _hasMoreProducts = true;
                  });
                  _loadProducts();
                },
                selectedColor: Colors.green.withValues(alpha: 0.2),
                checkmarkColor: Colors.green,
              ),
              FilterChip(
                label: const Text('Out of Stock'),
                selected: _filter.inStock == false,
                onSelected: (_) {
                  setState(() {
                    _filter = _filter.copyWith(
                      inStock: _filter.inStock == false ? null : false,
                    );
                    _currentPage = 1;
                    _hasMoreProducts = true;
                  });
                  _loadProducts();
                },
                selectedColor: Colors.red.withValues(alpha: 0.2),
                checkmarkColor: Colors.red,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductsList() {
    if (_isLoading && _products.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No matcha products found',
              style: TextStyle(
                fontSize: 18,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or run a full check to discover new matcha products',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadProducts(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        itemCount: _products.length + (_hasMoreProducts ? 1 : 0),
        itemBuilder: (context, index) {
          // Show loading indicator at the bottom when loading more
          if (index == _products.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return ProductCard(
            product: _products[index],
            preferredCurrency: _userSettings.preferredCurrency,
            onTap: () {
              _openProductUrl(_products[index].url);
            },
          );
        },
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const SizedBox(height: 16),
        // Comprehensive scan button
        FloatingActionButton(
          heroTag: "comprehensive_scan",
          onPressed: _isFullCheckRunning ? null : _performComprehensiveScan,
          shape: const CircleBorder(),
          child:
              _isFullCheckRunning
                  ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                  : const Icon(Icons.radar, size: 28),
        ),
        const SizedBox(height: 16),
        // Background check button
        FloatingActionButton(
          heroTag: "background_check",
          onPressed: _performBackgroundCheck,
          backgroundColor: Theme.of(context).colorScheme.secondary,
          shape: const CircleBorder(),
          child: const Icon(Icons.notifications_active, size: 24),
        ),
      ],
    );
  }

  Future<void> _openProductUrl(String url) async {
    if (url.isEmpty) {
      _showErrorSnackBar('Product URL not available');
      return;
    }

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showSuccessSnackBar('Opening product page...');
      } else {
        _showErrorSnackBar('Could not open product page');
      }
    } catch (e) {
      _showErrorSnackBar('Error opening URL: $e');
    }
  }
}
