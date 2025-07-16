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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // Product state for endless loading
  List<MatchaProduct> _products = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreProducts = true;
  bool _isServiceRunning = false;
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

  // Speed dial state
  bool _isSpeedDialOpen = false;
  late AnimationController _animationController;
  late Animation<double> _buttonAnimatedIcon;
  late Animation<double> _translateButton;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadFilterOptions();
    _loadProducts();
    if (!kIsWeb) {
      _checkServiceStatus();
    }

    // Setup endless scroll listener
    _scrollController.addListener(_onScroll);

    // Initialize speed dial animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _buttonAnimatedIcon = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_animationController);
    _translateButton = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
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
        'Nakamura',
        'Marukyu-Koyamaen',
        'Ippodo Tea',
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
      final paginatedProducts = await DatabaseService.platformService
          .getProductsPaginated(
            page: _currentPage,
            itemsPerPage: _userSettings.itemsPerPage,
            filter: _filter,
            sortBy: _userSettings.sortBy,
            sortAscending: _userSettings.sortAscending,
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

  void _toggleSpeedDial() {
    if (_isSpeedDialOpen) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
    setState(() {
      _isSpeedDialOpen = !_isSpeedDialOpen;
    });
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
      body: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Service status banner (mobile only)
              if (!kIsWeb) _buildServiceStatusBanner(),

              // Search bar
              _buildSearchBar(),

              // Products list with pagination
              Expanded(child: _buildProductsList()),
            ],
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
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(color: Colors.grey[300]!),
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
                selected: _filter.inStock == null,
                onSelected: (selected) {
                  // Always set to "All" when this chip is tapped
                  setState(() {
                    _filter = _filter.copyWith(inStock: null);
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
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      // Selecting "In Stock"
                      _filter = _filter.copyWith(inStock: true);
                    } else {
                      // Deselecting "In Stock" - go back to "All"
                      _filter = _filter.copyWith(inStock: null);
                    }
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
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      // Selecting "Out of Stock"
                      _filter = _filter.copyWith(inStock: false);
                    } else {
                      // Deselecting "Out of Stock" - go back to "All"
                      _filter = _filter.copyWith(inStock: null);
                    }
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
            onTap: () {
              _showProductDetails(_products[index]);
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
        // Full Check Button (when expanded)
        AnimatedBuilder(
          animation: _translateButton,
          builder: (context, child) {
            return Transform(
              transform: Matrix4.translationValues(
                0.0,
                _translateButton.value * -80.0, // Reduced from -140.0
                0.0,
              ),
              child: Opacity(
                opacity: _translateButton.value,
                child: FloatingActionButton.extended(
                  onPressed:
                      _isLoading || _isFullCheckRunning
                          ? null
                          : () {
                            _toggleSpeedDial();
                            _performFullCheck();
                          },
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
              ),
            );
          },
        ),

        // Quick Check Button (when expanded)
        AnimatedBuilder(
          animation: _translateButton,
          builder: (context, child) {
            return Transform(
              transform: Matrix4.translationValues(
                0.0,
                _translateButton.value * -40.0, // Reduced from -70.0
                0.0,
              ),
              child: Opacity(
                opacity: _translateButton.value,
                child: FloatingActionButton.extended(
                  onPressed:
                      _isLoading || _isFullCheckRunning
                          ? null
                          : () {
                            _toggleSpeedDial();
                            _performLightweightCheck();
                          },
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
              ),
            );
          },
        ),

        // Main Radar Button
        FloatingActionButton(
          onPressed: _toggleSpeedDial,
          shape: const CircleBorder(), // Ensures perfectly round shape
          child: AnimatedBuilder(
            animation: _buttonAnimatedIcon,
            builder: (context, child) {
              return Icon(
                _isSpeedDialOpen ? Icons.close : Icons.radar,
                size: 28,
              );
            },
          ),
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
