// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/matcha_product.dart';
import '../models/scan_activity.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/crawler_service.dart';
import '../services/crawler_logger.dart';
import '../services/search_history_service.dart';
import '../services/recommendation_service.dart';
import '../widgets/product_card.dart';
import '../widgets/product_filters.dart';
import '../widgets/matcha_icon.dart';
import '../widgets/site_selection_dialog.dart';
import 'settings_screen.dart';
import 'background_activity_screen.dart';
import 'product_detail_page.dart';
import 'website_overview_screen.dart';
import 'onboarding_screen_new.dart';

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

  // Search enhancement state
  bool _showSearchSuggestions = false;
  List<String> _recentSearches = [];
  List<MatchaProduct> _recommendedProducts = [];
  bool _isLoadingRecommendations = false;

  // Endless loading state
  ProductFilter _filter = ProductFilter();
  // Helper to persist filter to shared_preferences
  Future<void> _saveFilterToPrefs(ProductFilter filter) async {
    final prefs = await SharedPreferences.getInstance();
    // Save each field as needed
    if (filter.inStock != null) {
      prefs.setBool('filter_inStock', filter.inStock!);
    } else {
      prefs.remove('filter_inStock');
    }
    prefs.setBool('filter_favoritesOnly', filter.favoritesOnly);
    prefs.setStringList('filter_sites', filter.sites ?? []);
    prefs.setString('filter_category', filter.category ?? '');
    if (filter.minPrice != null) {
      prefs.setDouble('filter_minPrice', filter.minPrice!);
    } else {
      prefs.remove('filter_minPrice');
    }
    if (filter.maxPrice != null) {
      prefs.setDouble('filter_maxPrice', filter.maxPrice!);
    } else {
      prefs.remove('filter_maxPrice');
    }
    prefs.setString('filter_searchTerm', filter.searchTerm ?? '');

    // Debug log
    debugPrint('Saved filter: ${filter.toString()}');
  }

  // Helper to restore filter from shared_preferences
  Future<ProductFilter> _loadFilterFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    // Check if any filter is set, otherwise return default (All)
    final hasAnyFilter =
        prefs.containsKey('filter_inStock') ||
        prefs.containsKey('filter_favoritesOnly') ||
        prefs.containsKey('filter_sites') ||
        prefs.containsKey('filter_category') ||
        prefs.containsKey('filter_minPrice') ||
        prefs.containsKey('filter_maxPrice') ||
        prefs.containsKey('filter_searchTerm');

    if (!hasAnyFilter) {
      // No filters saved, return default (All)
      return ProductFilter();
    }

    final restoredFilter = ProductFilter(
      inStock:
          prefs.containsKey('filter_inStock')
              ? prefs.getBool('filter_inStock')
              : null,
      favoritesOnly: prefs.getBool('filter_favoritesOnly') ?? false,
      sites: prefs.getStringList('filter_sites'),
      category: prefs.getString('filter_category'),
      minPrice:
          prefs.containsKey('filter_minPrice')
              ? prefs.getDouble('filter_minPrice')
              : null,
      maxPrice:
          prefs.containsKey('filter_maxPrice')
              ? prefs.getDouble('filter_maxPrice')
              : null,
      searchTerm: prefs.getString('filter_searchTerm'),
    );

    // Debug log
    debugPrint('Restored filter: ${restoredFilter.toString()}');

    return restoredFilter;
  }

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

  // Favorites tracking
  Set<String> _favoriteProductIds = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadFavorites();
    _loadFilterOptions();
    _restoreFilterAndLoadProducts();
    _loadSearchEnhancements();
  }

  Future<void> _loadSearchEnhancements() async {
    // Load recent searches
    _loadRecentSearches();

    // Load recommendations
    _loadRecommendations();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final searches = await SearchHistoryService.getSearchHistory();
      setState(() {
        _recentSearches = searches;
      });
    } catch (e) {
      print('Error loading recent searches: $e');
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoadingRecommendations = true;
    });

    try {
      final recommendations = await RecommendationService.getRecommendations(
        limit: 6,
        excludeProductIds: _products.map((p) => p.id).toList(),
      );
      setState(() {
        _recommendedProducts = recommendations;
        _isLoadingRecommendations = false;
      });
    } catch (e) {
      print('Error loading recommendations: $e');
      setState(() {
        _isLoadingRecommendations = false;
      });
    }
  }

  Future<void> _restoreFilterAndLoadProducts() async {
    final restoredFilter = await _loadFilterFromPrefs();
    setState(() {
      _filter = restoredFilter;
      _searchQuery = restoredFilter.searchTerm ?? '';
      if (_searchController.text != _searchQuery) {
        _searchController.text = _searchQuery;
      }
    });
    await _loadProducts();

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

  Future<void> _loadFavorites() async {
    try {
      final favoriteIds =
          await DatabaseService.platformService.getFavoriteProductIds();
      setState(() {
        _favoriteProductIds = favoriteIds.toSet();
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite(String productId) async {
    try {
      final isFavorite = _favoriteProductIds.contains(productId);

      if (isFavorite) {
        await DatabaseService.platformService.removeFromFavorites(productId);
        setState(() {
          _favoriteProductIds.remove(productId);
        });
      } else {
        await DatabaseService.platformService.addToFavorites(productId);
        setState(() {
          _favoriteProductIds.add(productId);
        });
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating favorite: $e')));
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      // Get sites from crawler service
      final crawler = CrawlerService();
      final siteNamesMap = crawler.getSiteNamesMap();
      List<String> sites = ['All'];
      sites.addAll(siteNamesMap.values);

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

      // Debug log for query arguments
      debugPrint(
        'Query arguments: page=$_currentPage, itemsPerPage=${_userSettings.itemsPerPage}, filter=${_filter.toString()}, sortBy=${_userSettings.sortBy}, sortAscending=${_userSettings.sortAscending}',
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
    final scanStartTime = DateTime.now();
    final stopwatch = Stopwatch()..start();

    setState(() {
      _isFullCheckRunning = true;
    });

    try {
      final crawler = CrawlerService.instance;
      List<MatchaProduct> products;
      List<String> scannedSiteKeys = [];

      // Check if this is the first scan by looking at existing products
      final db = DatabaseService.platformService;
      final existingProducts = await db.getAllProducts();
      final isFirstScan = existingProducts.isEmpty;

      if (isFirstScan) {
        // For first scan, use all enabled sites from settings
        _showScanProgressDialog();
        products = await crawler.crawlAllSites();
        scannedSiteKeys = _userSettings.enabledSites;
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
        scannedSiteKeys = siteKeysToScan;

        // Show progress dialog and perform selected scan
        _showScanProgressDialog();
        products = await crawler.crawlSelectedSites(siteKeysToScan);
      }

      // Dismiss loading dialog
      Navigator.of(context).pop();

      // Log scan activity
      stopwatch.stop();
      final scanActivity = ScanActivity(
        id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: scanStartTime,
        itemsScanned: products.length,
        duration: stopwatch.elapsed.inSeconds,
        hasStockUpdates: products.any(
          (p) => p.isInStock,
        ), // Check if any products are in stock
        details: 'Manual scan of ${scannedSiteKeys.join(", ")}',
        scanType: 'manual',
      );

      try {
        await DatabaseService.platformService.insertScanActivity(scanActivity);
      } catch (e) {
        print('Failed to log scan activity: $e');
      }

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

      // Log failed scan activity
      stopwatch.stop();
      final scanActivity = ScanActivity(
        id: 'scan_${DateTime.now().millisecondsSinceEpoch}',
        timestamp: scanStartTime,
        itemsScanned: 0,
        duration: stopwatch.elapsed.inSeconds,
        hasStockUpdates: false,
        details: 'Manual scan failed: $e',
        scanType: 'manual',
      );

      try {
        await DatabaseService.platformService.insertScanActivity(scanActivity);
      } catch (logError) {
        print('Failed to log scan activity: $logError');
      }

      _showErrorSnackBar('Failed to perform scan: $e');
    } finally {
      setState(() {
        _isFullCheckRunning = false;
      });
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
                content: SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Column(
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
                          softWrap: true,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Current Site:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(150),
                          ),
                          softWrap: true,
                        ),
                        Text(
                          currentSite,
                          style: const TextStyle(fontSize: 16),
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Status:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(150),
                          ),
                          softWrap: true,
                        ),
                        Text(
                          status,
                          style: const TextStyle(fontSize: 14),
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
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
    _saveFilterToPrefs(newFilter);
    _loadProducts(); // Reset products when filter changes
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      // Update the filter with the search query
      _filter = _filter.copyWith(searchTerm: query);
    });
    _saveFilterToPrefs(_filter);

    // Save to search history if it's a meaningful search (at least 2 characters)
    if (query.trim().length >= 2) {
      SearchHistoryService.addSearchTerm(query.trim()).then((_) {
        _loadRecentSearches(); // Refresh recent searches
      });
    }

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
          // Debug button to test onboarding (only show in debug mode)
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.ondemand_video),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const OnboardingScreen(),
                  ),
                );
              },
              tooltip: 'Test Onboarding',
            ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const BackgroundActivityScreen(),
                ),
              );
            },
            tooltip: 'Recent Scans',
          ),
          IconButton(
            icon: const Icon(Icons.timeline),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WebsiteOverviewScreen(),
                ),
              );
            },
            tooltip: 'Website Analytics',
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
      body: GestureDetector(
        onTap: () {
          // Hide search suggestions when tapping outside
          if (_showSearchSuggestions) {
            setState(() {
              _showSearchSuggestions = false;
            });
          }
        },
        child: Stack(
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

            // Floating Action Button positioned in the stack (local mode only)
            if (_userSettings.appMode == 'local')
              Builder(
                builder: (context) {
                  return Positioned(
                    bottom: 64,
                    right: 16,
                    child: _buildFloatingActionButtons(),
                  );
                },
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
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: const BorderRadius.only(
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
            color: Theme.of(
              context,
            ).colorScheme.outline.withAlpha((0.3 * 255).toInt()),
          ),
        ),
      ),
      child: Column(
        children: [
          // Search input row
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      onTap: () {
                        setState(() {
                          _showSearchSuggestions = true;
                        });
                      },
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
                            color: Theme.of(context).colorScheme.outline
                                .withAlpha((0.3 * 255).toInt()),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.outline
                                .withAlpha((0.3 * 255).toInt()),
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
                    // Search suggestions
                    if (_showSearchSuggestions &&
                        (_recentSearches.isNotEmpty ||
                            _recommendedProducts.isNotEmpty))
                      _buildSearchSuggestions(),
                  ],
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
                    _showSearchSuggestions =
                        false; // Hide suggestions when showing filters
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

  Widget _buildSearchSuggestions() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: Theme.of(
            context,
          ).colorScheme.outline.withAlpha((0.3 * 255).toInt()),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).toInt()),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 300),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recent searches section
            if (_recentSearches.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Searches',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearSearchHistory,
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              ),
              ...(_recentSearches
                  .take(5)
                  .map(
                    (search) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.history, size: 18),
                      title: Text(search),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, size: 16),
                        onPressed: () => _removeSearchTerm(search),
                      ),
                      onTap: () => _selectSearchTerm(search),
                    ),
                  )),
              if (_recommendedProducts.isNotEmpty) const Divider(height: 1),
            ],

            // You might like section
            if (_recommendedProducts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'You Might Like',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoadingRecommendations)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                ...(_recommendedProducts
                    .take(3)
                    .map(
                      (product) => ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundImage:
                              product.imageUrl != null
                                  ? NetworkImage(product.imageUrl!)
                                  : null,
                          child:
                              product.imageUrl == null
                                  ? const Icon(Icons.local_cafe, size: 16)
                                  : null,
                        ),
                        title: Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${product.site}${product.price != null ? ' • ${product.price}' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Icon(
                          product.isInStock ? Icons.check_circle : Icons.cancel,
                          color: product.isInStock ? Colors.green : Colors.red,
                          size: 16,
                        ),
                        onTap: () => _selectProduct(product),
                      ),
                    )),
            ],

            // Close button
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _showSearchSuggestions = false;
                    });
                  },
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectSearchTerm(String term) {
    _searchController.text = term;
    _onSearchChanged(term);
    setState(() {
      _showSearchSuggestions = false;
    });
  }

  void _selectProduct(MatchaProduct product) {
    setState(() {
      _showSearchSuggestions = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
  }

  Future<void> _clearSearchHistory() async {
    await SearchHistoryService.clearSearchHistory();
    _loadRecentSearches();
  }

  Future<void> _removeSearchTerm(String term) async {
    await SearchHistoryService.removeSearchTerm(term);
    _loadRecentSearches();
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
                onSelected: (_) async {
                  // Clear all filters to show all products
                  setState(() {
                    _filter = ProductFilter(); // Reset to default empty filter
                    _searchQuery = '';
                    _searchController.clear();
                    _currentPage = 1;
                    _hasMoreProducts = true;
                  });
                  await _saveFilterToPrefs(_filter);
                  _loadProducts();
                },
                selectedColor:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.green.shade50
                        : Colors.green.withAlpha((0.2 * 255).toInt()),
                checkmarkColor:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.green.shade600
                        : Colors.green,
                labelStyle:
                    Theme.of(context).brightness == Brightness.light
                        ? const TextStyle(color: Colors.black87)
                        : null,
              ),
              FilterChip(
                label: const Text('In Stock'),
                selected: _filter.inStock == true,
                onSelected: (_) async {
                  setState(() {
                    if (_filter.inStock == true) {
                      // If already selected, reset to All
                      _filter = ProductFilter();
                      _searchQuery = '';
                      _searchController.clear();
                    } else {
                      _filter = _filter.copyWith(inStock: true);
                    }
                    _currentPage = 1;
                    _hasMoreProducts = true;
                  });
                  await _saveFilterToPrefs(_filter);
                  _loadProducts();
                },
                selectedColor:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.green.shade50
                        : Colors.green.withAlpha((0.2 * 255).toInt()),
                checkmarkColor:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.green.shade600
                        : Colors.green,
                labelStyle:
                    Theme.of(context).brightness == Brightness.light
                        ? const TextStyle(color: Colors.black87)
                        : null,
              ),
              FilterChip(
                label: const Text('Out of Stock'),
                selected: _filter.inStock == false,
                onSelected: (_) async {
                  setState(() {
                    if (_filter.inStock == false) {
                      // If already selected, reset to All
                      _filter = ProductFilter();
                      _searchQuery = '';
                      _searchController.clear();
                    } else {
                      _filter = _filter.copyWith(inStock: false);
                    }
                    _currentPage = 1;
                    _hasMoreProducts = true;
                  });
                  await _saveFilterToPrefs(_filter);
                  _loadProducts();
                },
                selectedColor:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.red.shade50
                        : Colors.red.withAlpha((0.2 * 255).toInt()),
                checkmarkColor:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.red.shade600
                        : Colors.red,
                labelStyle:
                    Theme.of(context).brightness == Brightness.light
                        ? const TextStyle(color: Colors.black87)
                        : null,
              ),
              FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color:
                          _filter.favoritesOnly
                              ? (Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.red.shade600
                                  : Colors.red)
                              : null,
                    ),
                    const SizedBox(width: 4),
                    const Text('Favorites'),
                  ],
                ),
                selected: _filter.favoritesOnly,
                onSelected: (_) async {
                  setState(() {
                    _filter = _filter.copyWith(
                      favoritesOnly: !_filter.favoritesOnly,
                    );
                    _currentPage = 1;
                    _hasMoreProducts = true;
                  });
                  await _saveFilterToPrefs(_filter);
                  _loadProducts();
                },
                selectedColor:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.red.shade50
                        : Colors.red.withAlpha((0.2 * 255).toInt()),
                checkmarkColor:
                    Theme.of(context).brightness == Brightness.light
                        ? Colors.red.shade600
                        : Colors.red,
                labelStyle:
                    Theme.of(context).brightness == Brightness.light
                        ? const TextStyle(color: Colors.black87)
                        : null,
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
                ).colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters or run a full check to discover new matcha products',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withAlpha((0.6 * 255).toInt()),
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
            isFavorite: _favoriteProductIds.contains(_products[index].id),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (context) => ProductDetailPage(product: _products[index]),
                ),
              );
            },
            onFavoriteToggle: () {
              _toggleFavorite(_products[index].id);
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
      ],
    );
  }
}
