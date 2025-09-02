// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/matcha_product.dart';
import '../services/database_service.dart';
import '../services/search_history_service.dart';
import '../services/recommendation_service.dart';
import '../services/backend_service.dart';
import '../services/settings_service.dart';
import '../services/subscription_service.dart';
import '../widgets/product_card.dart';
import '../widgets/product_filters.dart';
import '../widgets/mobile_filter_modal.dart';
import '../widgets/matcha_icon.dart';
import '../widgets/skeleton_loading.dart';
import '../widgets/swipe_tutorial_overlay.dart';
import 'product_detail_page.dart';
import 'subscription_upgrade_screen.dart';

class HomeScreenContent extends StatefulWidget {
  final VoidCallback? onRefreshRequested;

  const HomeScreenContent({super.key, this.onRefreshRequested});

  // Static instance to access from outside
  static _HomeScreenContentState? _currentInstance;

  // Static method to refresh from outside
  static void refreshIfActive() {
    _currentInstance?.refreshProducts();
  }

  @override
  State<HomeScreenContent> createState() => _HomeScreenContentState();
}

class _HomeScreenContentState extends State<HomeScreenContent>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Product state for endless loading
  List<MatchaProduct> _products = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMoreProducts = true;
  bool _showFilters = false;

  // Search enhancement state
  bool _showSearchSuggestions = false;
  List<String> _recentSearches = [];
  List<MatchaProduct> _recommendedProducts = [];
  bool _isLoadingRecommendations = false;

  // Endless loading state
  ProductFilter _filter = ProductFilter();
  int _currentPage = 1;
  final ScrollController _scrollController = ScrollController();

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';

  // Available filter options
  List<String> _availableSites = ['All'];
  List<String> _availableCategories = [];
  Map<String, double> _priceRange = {'min': 0.0, 'max': 1000.0};

  // Favorites tracking
  Set<String> _favoriteProductIds = {};

  // Sorting state
  String _sortBy = 'name'; // 'name', 'price', 'category'
  bool _sortAscending = true;

  // User preferences
  String _preferredCurrency = 'EUR';

  // Collapsible filter section state
  bool _isFilterSectionExpanded = true;

  // Tutorial state
  bool _showTutorialOverlay = false;

  // Public method to refresh products (can be called from parent)
  void refreshProducts() {
    _loadProducts();
    _loadSettings(); // Reload settings to get updated currency preference
  }

  // Helper to persist filter to shared_preferences
  Future<void> _saveFilterToPrefs(ProductFilter filter) async {
    final prefs = await SharedPreferences.getInstance();
    if (filter.inStock != null) {
      prefs.setBool('filter_inStock', filter.inStock!);
    } else {
      prefs.remove('filter_inStock');
    }
    prefs.setBool('filter_favoritesOnly', filter.favoritesOnly);
    prefs.setStringList('filter_sites', filter.sites ?? []);
    prefs.setStringList('filter_categories', filter.categories ?? []);
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

    debugPrint('Saved filter: ${filter.toString()}');
  }

  // Helper to restore filter from shared_preferences
  Future<ProductFilter> _loadFilterFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAnyFilter =
        prefs.containsKey('filter_inStock') ||
        prefs.getBool('filter_favoritesOnly') == true ||
        (prefs.getStringList('filter_sites')?.isNotEmpty == true) ||
        (prefs.getStringList('filter_categories')?.isNotEmpty == true) ||
        prefs.containsKey('filter_minPrice') ||
        prefs.containsKey('filter_maxPrice') ||
        (prefs.getString('filter_searchTerm')?.isNotEmpty == true);

    if (!hasAnyFilter) {
      return ProductFilter();
    }

    final restoredFilter = ProductFilter(
      inStock:
          prefs.containsKey('filter_inStock')
              ? prefs.getBool('filter_inStock')
              : null,
      favoritesOnly: prefs.getBool('filter_favoritesOnly') ?? false,
      sites: prefs.getStringList('filter_sites'),
      categories: prefs.getStringList('filter_categories'),
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

    debugPrint('Restored filter: ${restoredFilter.toString()}');
    return restoredFilter;
  }

  @override
  void initState() {
    super.initState();

    // Register this instance
    HomeScreenContent._currentInstance = this;

    // Set up focus listener for smart search history
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        setState(() {
          _showSearchSuggestions = true;
        });
        _loadSearchEnhancements();
      } else {
        setState(() {
          _showSearchSuggestions = false;
        });
        _saveSearchTermIfMeaningful();
      }
    });

    // Load critical data first, then load everything else asynchronously
    _initializeFastData();
  }

  /// Load only essential data for initial render, defer heavy operations
  Future<void> _initializeFastData() async {
    // Load settings first (usually cached)
    await _loadSettings();

    // Start loading products immediately with cached filter
    _restoreFilterAndLoadProducts();

    // Load other data in background without blocking UI
    Future.microtask(() async {
      await _loadFavorites();
      await _loadFilterOptions();
      _loadSearchEnhancements();
      _checkTutorialStatus();
    });
  }

  Future<void> _loadSearchEnhancements() async {
    // Load recent searches
    _loadRecentSearches();
    // Load recommendations
    _loadRecommendations();
  }

  Future<void> _checkTutorialStatus() async {
    try {
      final hasSeenTutorial =
          await SettingsService.instance.hasSeenHomeScreenTutorial();
      if (!hasSeenTutorial && mounted) {
        // Wait a bit for the UI to settle, then show tutorial
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() {
              _showTutorialOverlay = true;
            });
          }
        });
      }
    } catch (e) {
      print('Error checking tutorial status: $e');
    }
  }

  void _dismissTutorial() async {
    setState(() {
      _showTutorialOverlay = false;
    });

    try {
      await SettingsService.instance.markHomeScreenTutorialSeen();
    } catch (e) {
      print('Error marking tutorial as seen: $e');
    }
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
        excludeProductIds: _favoriteProductIds.toList(),
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

  int _getActiveFilterCount() {
    int count = 0;

    // Check if sites are filtered (not empty and not all sites)
    if (_filter.sites?.isNotEmpty == true) {
      count++;
    }

    // Check if categories are set
    if (_filter.categories?.isNotEmpty == true) {
      count++;
    }

    // Check if price range is set (different from default range)
    if (_filter.minPrice != null || _filter.maxPrice != null) {
      final defaultMin = _priceRange['min'] ?? 0.0;
      final defaultMax = _priceRange['max'] ?? 1000.0;
      if (_filter.minPrice != defaultMin || _filter.maxPrice != defaultMax) {
        count++;
      }
    }

    // Check if favorites only is enabled
    if (_filter.favoritesOnly) {
      count++;
    }

    // Check if search term is set
    if (_filter.searchTerm?.isNotEmpty == true) {
      count++;
    }

    return count;
  }

  Future<void> _restoreFilterAndLoadProducts() async {
    final restoredFilter = await _loadFilterFromPrefs();
    setState(() {
      _filter = restoredFilter;
      _searchController.text = restoredFilter.searchTerm ?? '';
      _searchQuery = restoredFilter.searchTerm ?? '';
    });
    await _loadProducts();

    // Setup endless scroll listener
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    // Unregister this instance
    if (HomeScreenContent._currentInstance == this) {
      HomeScreenContent._currentInstance = null;
    }

    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.instance.getSettings();
      setState(() {
        _preferredCurrency = settings.preferredCurrency;
      });
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites =
          await DatabaseService.platformService.getFavoriteProductIds();
      setState(() {
        _favoriteProductIds = favorites.toSet();
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite(String productId) async {
    try {
      bool wasFavorite = _favoriteProductIds.contains(productId);
      bool newFavoriteState = !wasFavorite;

      // Update the backend with FCM subscription management and subscription validation
      final result = await BackendService.instance.updateFavorite(
        productId: productId,
        isFavorite: newFavoriteState,
      );

      if (!result.success) {
        // Handle subscription limit or other errors
        if (result.limitReached && result.validationResult != null) {
          _showUpgradeDialog(result.validationResult!);
        } else {
          _showErrorSnackBar(result.error ?? 'Failed to update favorite');
        }
        return;
      }

      // Update local state only if backend update was successful
      setState(() {
        if (newFavoriteState) {
          _favoriteProductIds.add(productId);
        } else {
          _favoriteProductIds.remove(productId);
        }
      });

      // Show feedback to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newFavoriteState
                  ? '📱 Added to favorites - you\'ll get notifications when it\'s back in stock!'
                  : 'Removed from favorites',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating favorite: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      // Use cached data if available, otherwise load fresh
      final results = await Future.wait<dynamic>([
        DatabaseService.platformService.getUniqueSites(),
        DatabaseService.platformService.getAvailableCategories(),
        DatabaseService.platformService.getPriceRange(),
        SubscriptionService.instance.isPremiumUser(),
      ]);

      final sites = results[0] as List<String>;
      final categories = results[1] as List<String>;
      final priceRange = results[2] as Map<String, double>;
      final isPremium = results[3] as bool;

      // Filter sites based on subscription tier
      List<String> availableSites;
      if (isPremium) {
        availableSites = sites;
      } else {
        // For free users, only show allowed sites
        final freeSites = SubscriptionTierExtension.freeEnabledSites;

        // Map site display names back to keys to check against free sites
        final siteNameToKey = <String, String>{
          'Nakamura Tokichi': 'tokichi',
          'Marukyu-Koyamaen': 'marukyu',
          'Ippodo Tea': 'ippodo',
          'Yoshi En': 'yoshien',
          'Matcha Kāru': 'matcha-karu',
          'Sho-Cha': 'sho-cha',
          'Sazen Tea': 'sazentea',
          'Emeri': 'enjoyemeri',
          'Poppatea': 'poppatea',
          'Horiishichimeien': 'horiishichimeien',
        };

        availableSites =
            sites.where((siteName) {
              final siteKey = siteNameToKey[siteName] ?? siteName.toLowerCase();
              return freeSites.contains(siteKey);
            }).toList();

        if (kDebugMode) {
          print(
            '🔒 Free mode sites filter: ${availableSites.length} of ${sites.length} sites available',
          );
          print('   Available: $availableSites');
          print('   All sites: $sites');
        }
      }

      if (mounted) {
        setState(() {
          _availableSites = ['All', ...availableSites];
          _availableCategories = categories;
          _priceRange = priceRange;
        });
      }
    } catch (e) {
      print('Error loading filter options: $e');
      // Set sensible defaults
      if (mounted) {
        setState(() {
          _availableSites = ['All'];
          _availableCategories = [];
          _priceRange = {'min': 0.0, 'max': 1000.0};
        });
      }
    }
  }

  Future<void> _loadProducts({bool loadMore = false}) async {
    if (!loadMore) {
      setState(() {
        _isLoading = true;
        _currentPage = 1;
        _hasMoreProducts = true;
      });
    } else {
      if (_isLoadingMore || !_hasMoreProducts) return;
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final result = await DatabaseService.platformService.getProductsPaginated(
        page: _currentPage,
        itemsPerPage: 20,
        filter: _filter,
      );

      setState(() {
        if (loadMore) {
          _products.addAll(result.products);
          _isLoadingMore = false;
        } else {
          _products = result.products;
          _isLoading = false;
        }

        _hasMoreProducts = result.hasMorePages;
        if (result.products.isNotEmpty) {
          _currentPage++;
        }
      });

      // Apply sorting after loading products
      _applySorting();
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  // Scroll listener for endless loading
  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadProducts(loadMore: true);
    }
  }

  void _onFilterChanged(ProductFilter newFilter) {
    setState(() {
      _filter = newFilter;
    });
    _saveFilterToPrefs(newFilter);
    _loadProducts();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filter = _filter.copyWith(searchTerm: query.isEmpty ? null : query);
    });
    _saveFilterToPrefs(_filter);
    _loadProducts();
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
    _searchFocusNode.unfocus();
  }

  /// Show mobile filter modal
  void _showMobileFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => DraggableScrollableSheet(
            initialChildSize: 0.8,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder:
                (context, scrollController) => MobileFilterModal(
                  filter: _filter,
                  availableSites: _availableSites,
                  availableCategories: _availableCategories,
                  priceRange: _priceRange,
                  onFilterChanged: (newFilter) {
                    setState(() {
                      _showSearchSuggestions = false;
                    });
                    _onFilterChanged(newFilter);
                  },
                  onClose: () => Navigator.of(context).pop(),
                ),
          ),
    );
  }

  /// Save search term to history if it's meaningful
  Future<void> _saveSearchTermIfMeaningful() async {
    final query = _searchQuery.trim();
    if (query.length >= 2) {
      await SearchHistoryService.addSearchTerm(query);
      _loadRecentSearches();
    }
  }

  /// Called when user submits search (e.g., presses enter)
  void _onSearchSubmitted(String query) {
    _saveSearchTermIfMeaningful();
  }

  void _selectSearchTerm(String term) {
    _searchController.text = term;
    _onSearchChanged(term);
    setState(() {
      _showSearchSuggestions = false;
    });
  }

  Future<void> _clearSearchHistory() async {
    await SearchHistoryService.clearSearchHistory();
    _loadRecentSearches();
  }

  Future<void> _removeSearchTerm(String term) async {
    await SearchHistoryService.removeSearchTerm(term);
    _loadRecentSearches();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Column(
          children: [
            _buildSearchBar(),
            // Site filter and category filters shown above all other content (desktop only)
            if (_showFilters &&
                !_showSearchSuggestions &&
                MediaQuery.of(context).size.width >= 768)
              Flexible(
                child: ProductFilters(
                  filter: _filter,
                  availableSites: _availableSites,
                  availableCategories: _availableCategories,
                  priceRange: _priceRange,
                  onFilterChanged: (newFilter) {
                    setState(() {
                      _showSearchSuggestions = false;
                    });
                    _onFilterChanged(newFilter);
                  },
                ),
              ),
            // Stock status chips and sorting shown after filters
            _buildCollapsibleFilterSection(),
            Expanded(child: _buildProductsList()),
          ],
        ),
        // Search suggestions overlay
        if (_showSearchSuggestions)
          Positioned(
            top: 80, // Position below search bar
            left: 16,
            right: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: _buildSearchSuggestions(),
              ),
            ),
          ),

        // Tutorial overlay
        if (_showTutorialOverlay)
          Positioned.fill(
            child: SwipeTutorialOverlay(onDismiss: _dismissTutorial),
          ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchQuery.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchSubmitted,
            ),
          ),
          const SizedBox(width: 8),
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
                  color:
                      _showFilters
                          ? Theme.of(context).colorScheme.primary
                          : null,
                ),
                onPressed: () {
                  final screenWidth = MediaQuery.of(context).size.width;
                  final isMobile = screenWidth < 768;

                  if (isMobile) {
                    _showMobileFilterModal();
                  } else {
                    setState(() {
                      _showFilters = !_showFilters;
                      if (_showFilters) {
                        _showSearchSuggestions = false;
                        _searchFocusNode.unfocus();
                      }
                    });
                  }
                },
              ),
              if (_getActiveFilterCount() > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${_getActiveFilterCount()}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsibleFilterSection() {
    return Column(
      children: [
        // Header with toggle button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.tune,
                size: 20,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
              ),
              const SizedBox(width: 8),
              Text(
                'Filters & Sort',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                ),
              ),
              const Spacer(),
              if (_getActiveFilterCount() > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withAlpha(51),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_getActiveFilterCount()} active',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() {
                    _isFilterSectionExpanded = !_isFilterSectionExpanded;
                  });
                },
                icon: AnimatedRotation(
                  turns: _isFilterSectionExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more),
                ),
                tooltip:
                    _isFilterSectionExpanded
                        ? 'Collapse filters'
                        : 'Expand filters',
              ),
            ],
          ),
        ),

        // Collapsible content
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _isFilterSectionExpanded ? null : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            opacity: _isFilterSectionExpanded ? 1.0 : 0.0,
            child:
                _isFilterSectionExpanded
                    ? Column(
                      children: [
                        _buildStockStatusChips(),
                        _buildSortingOptions(),
                        _buildBulkActions(),
                      ],
                    )
                    : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildStockStatusChips() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: Text(
                      'All',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color:
                            Theme.of(context).brightness == Brightness.light
                                ? Colors.black87
                                : Colors.white,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 6 : 8,
                      vertical: isSmallScreen ? 2 : 4,
                    ),
                    selected: _filter.inStock == null && !_filter.favoritesOnly,
                    onSelected: (_) async {
                      // Clear stock filter and favorites filter, keep other filters intact
                      setState(() {
                        _filter = _filter.copyWith(
                          clearInStock: true,
                          favoritesOnly: false,
                        );
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
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                      'Favorites',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color:
                            Theme.of(context).brightness == Brightness.light
                                ? Colors.black87
                                : Colors.white,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 6 : 8,
                      vertical: isSmallScreen ? 2 : 4,
                    ),
                    selected: _filter.favoritesOnly,
                    onSelected: (isSelected) async {
                      setState(() {
                        _filter = _filter.copyWith(
                          favoritesOnly: isSelected,
                          // When favorites is selected, clear inStock filter to show both in/out of stock favorites
                          inStock: isSelected ? null : _filter.inStock,
                        );
                        _currentPage = 1;
                        _hasMoreProducts = true;
                      });
                      await _saveFilterToPrefs(_filter);
                      _loadProducts();
                    },
                    selectedColor:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.pink.shade50
                            : Colors.pink.withAlpha((0.2 * 255).toInt()),
                    checkmarkColor:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.pink.shade600
                            : Colors.pink,
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                      'In Stock',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color:
                            Theme.of(context).brightness == Brightness.light
                                ? Colors.black87
                                : Colors.white,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 6 : 8,
                      vertical: isSmallScreen ? 2 : 4,
                    ),
                    selected: _filter.inStock == true,
                    onSelected: (isSelected) async {
                      setState(() {
                        _filter = _filter.copyWith(
                          inStock: isSelected ? true : null,
                          clearInStock: !isSelected,
                          // When stock filter is selected, clear favorites filter
                          favoritesOnly:
                              isSelected ? false : _filter.favoritesOnly,
                        );
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
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                      'Out of Stock',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color:
                            Theme.of(context).brightness == Brightness.light
                                ? Colors.black87
                                : Colors.white,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 6 : 8,
                      vertical: isSmallScreen ? 2 : 4,
                    ),
                    selected: _filter.inStock == false,
                    onSelected: (isSelected) async {
                      setState(() {
                        _filter = _filter.copyWith(
                          inStock: isSelected ? false : null,
                          clearInStock: !isSelected,
                          // When stock filter is selected, clear favorites filter
                          favoritesOnly:
                              isSelected ? false : _filter.favoritesOnly,
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortingOptions() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.sort,
            size: isSmallScreen ? 18 : 20,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
          ),
          const SizedBox(width: 8),
          Text(
            'Sort by:',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(180),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSortChip('Name', 'name', isSmallScreen),
                  const SizedBox(width: 8),
                  _buildSortChip('Price', 'price', isSmallScreen),
                  const SizedBox(width: 8),
                  _buildSortChip('Category', 'category', isSmallScreen),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _sortAscending = !_sortAscending;
              });
              _applySorting();
            },
            icon: Icon(
              _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: isSmallScreen ? 18 : 20,
            ),
            tooltip: _sortAscending ? 'Sort Ascending' : 'Sort Descending',
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String sortKey, bool isSmallScreen) {
    final isSelected = _sortBy == sortKey;

    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: isSmallScreen ? 11 : 13,
          color:
              isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _sortBy = sortKey;
          });
          _applySorting();
        }
      },
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6 : 8,
        vertical: isSmallScreen ? 2 : 4,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Theme.of(context).colorScheme.onPrimary,
    );
  }

  void _applySorting() {
    setState(() {
      _products.sort((a, b) {
        int comparison = 0;

        switch (_sortBy) {
          case 'name':
            comparison = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            break;
          case 'price':
            // Handle null prices - put them at the end
            if (a.priceValue == null && b.priceValue == null) return 0;
            if (a.priceValue == null) return 1;
            if (b.priceValue == null) return -1;
            comparison = a.priceValue!.compareTo(b.priceValue!);
            break;
          case 'category':
            final aCategory = a.category ?? 'zzz'; // Put null categories at end
            final bCategory = b.category ?? 'zzz';
            comparison = aCategory.toLowerCase().compareTo(
              bCategory.toLowerCase(),
            );
            break;
        }

        return _sortAscending ? comparison : -comparison;
      });
    });
  }

  Widget _buildSearchSuggestions() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(75),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_recentSearches.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(150),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recent Searches',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _clearSearchHistory,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 30),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              ...(_recentSearches.take(3)).map(
                (search) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  leading: const Icon(Icons.search, size: 16),
                  title: Text(search, style: const TextStyle(fontSize: 14)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () => _removeSearchTerm(search),
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                  onTap: () => _selectSearchTerm(search),
                ),
              ),
              if (_recommendedProducts.isNotEmpty) const Divider(height: 1),
            ],
            if (_recommendedProducts.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(150),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Recommended',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(150),
                      ),
                    ),
                  ],
                ),
              ),
              ...(_recommendedProducts.take(2)).map(
                (product) => ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  leading: Icon(
                    Icons.local_cafe,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    product.name,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    product.site,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(120),
                    ),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ProductDetailPage(product: product),
                      ),
                    );
                    setState(() {
                      _showSearchSuggestions = false;
                    });
                  },
                ),
              ),
            ],
            if (_isLoadingRecommendations)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            if (_recentSearches.isEmpty &&
                _recommendedProducts.isEmpty &&
                !_isLoadingRecommendations)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Start typing to search for matcha products...',
                  style: TextStyle(fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList() {
    if (_isLoading) {
      return ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) => const SkeletonProductCard(),
      );
    }

    if (_products.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MatchaIcon(size: 64),
            SizedBox(height: 16),
            Text('No products found', style: TextStyle(fontSize: 18)),
            Text(
              'Try adjusting your filters or check back later',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _products.length + (_isLoadingMore ? 3 : 0),
      itemBuilder: (context, index) {
        if (index >= _products.length) {
          return const SkeletonProductCard();
        }

        final product = _products[index];
        return ProductCard(
          product: product,
          preferredCurrency: _preferredCurrency,
          isFavorite: _favoriteProductIds.contains(product.id),
          onFavoriteToggle: () => _toggleFavorite(product.id),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailPage(product: product),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBulkActions() {
    final filteredProductCount = _products.length;
    final favoriteCount =
        _products.where((p) => _favoriteProductIds.contains(p.id)).length;
    final nonFavoriteCount = filteredProductCount - favoriteCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Add all visible products to favorites
          if (nonFavoriteCount > 0)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _bulkAddToFavorites(),
                icon: Icon(
                  Icons.favorite_border,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(
                  'Add $nonFavoriteCount to Favorites',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
            ),

          // Remove all visible products from favorites
          if (favoriteCount > 0) ...[
            if (nonFavoriteCount > 0) const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _bulkRemoveFromFavorites(),
                icon: Icon(Icons.favorite, size: 18, color: Colors.red),
                label: Text(
                  'Remove $favoriteCount from Favorites',
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Add all currently filtered products to favorites
  Future<void> _bulkAddToFavorites() async {
    try {
      final nonFavoriteProducts =
          _products.where((p) => !_favoriteProductIds.contains(p.id)).toList();

      if (nonFavoriteProducts.isEmpty) return;

      // Check subscription limits before starting bulk operation
      final validationResult =
          await SubscriptionService.instance.canAddMoreFavorites();
      final availableSlots =
          validationResult.maxAllowed - validationResult.currentCount;

      if (!validationResult.canAdd) {
        _showUpgradeDialog(validationResult);
        return;
      }

      // Limit products to add based on available slots
      final productsToAdd =
          availableSlots < nonFavoriteProducts.length
              ? nonFavoriteProducts.take(availableSlots).toList()
              : nonFavoriteProducts;

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Text('Adding ${productsToAdd.length} products to favorites...'),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Add products to favorites with individual limit checking
      int successCount = 0;
      for (final product in productsToAdd) {
        final result = await BackendService.instance.updateFavorite(
          productId: product.id,
          isFavorite: true,
        );

        if (result.success) {
          successCount++;
        } else if (result.limitReached) {
          // Stop adding if we hit the limit
          if (result.validationResult != null) {
            _showUpgradeDialog(result.validationResult!);
          }
          break;
        }
      }

      // Update local state only for successfully added products
      setState(() {
        _favoriteProductIds.addAll(
          productsToAdd.take(successCount).map((p) => p.id),
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (successCount > 0) {
          String message = '✅ Added $successCount products to favorites!';
          if (successCount < productsToAdd.length) {
            message +=
                ' (${productsToAdd.length - successCount} reached subscription limit)';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 3),
              backgroundColor:
                  successCount == productsToAdd.length
                      ? Colors.green
                      : Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error bulk adding to favorites: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding products to favorites: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Remove all currently filtered products from favorites
  Future<void> _bulkRemoveFromFavorites() async {
    try {
      final favoriteProducts =
          _products.where((p) => _favoriteProductIds.contains(p.id)).toList();

      if (favoriteProducts.isEmpty) return;

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Remove from Favorites'),
              content: Text(
                'Are you sure you want to remove ${favoriteProducts.length} products from your favorites?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Remove'),
                ),
              ],
            ),
      );

      if (confirmed != true) return;

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Removing ${favoriteProducts.length} products from favorites...',
                ),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Remove all products from favorites
      for (final product in favoriteProducts) {
        final result = await BackendService.instance.updateFavorite(
          productId: product.id,
          isFavorite: false,
        );
        // Note: Removal shouldn't hit subscription limits, but we could log errors if needed
        if (!result.success) {
          print('Failed to remove favorite ${product.id}: ${result.error}');
        }
      }

      // Update local state
      setState(() {
        _favoriteProductIds.removeWhere(
          (id) => favoriteProducts.any((p) => p.id == id),
        );
      });

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Removed ${favoriteProducts.length} products from favorites!',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('Error bulk removing from favorites: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing products from favorites: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Show upgrade dialog when subscription limits are reached
  void _showUpgradeDialog(FavoriteValidationResult validationResult) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('${validationResult.tier.displayName} Limit Reached'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(validationResult.message),
              const SizedBox(height: 16),
              Text(
                'Upgrade to Premium for:',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Unlimited favorites'),
              const Text('• Monitor all vendors'),
              const Text('• Hourly check frequency'),
              const Text('• Full history access'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Maybe Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => SubscriptionUpgradeScreen(
                          validationResult: validationResult,
                          sourceScreen: 'home_favorites',
                        ),
                  ),
                );
              },
              child: const Text('Upgrade Now'),
            ),
          ],
        );
      },
    );
  }

  /// Show error message in a snack bar
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
