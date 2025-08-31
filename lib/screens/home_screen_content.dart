// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/matcha_product.dart';
import '../services/database_service.dart';
import '../services/search_history_service.dart';
import '../services/recommendation_service.dart';
import '../services/backend_service.dart';
import '../widgets/product_card.dart';
import '../widgets/product_filters.dart';
import '../widgets/mobile_filter_modal.dart';
import '../widgets/matcha_icon.dart';
import '../widgets/skeleton_loading.dart';
import 'product_detail_page.dart';

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

  // Collapsible filter section state
  bool _isFilterSectionExpanded = true;

  // Public method to refresh products (can be called from parent)
  void refreshProducts() {
    _loadProducts();
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
    setState(() {});
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

      // Update the backend with FCM subscription management
      await BackendService.instance.updateFavorite(
        productId: productId,
        isFavorite: newFavoriteState,
      );

      // Update local state
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
      final sites = await DatabaseService.platformService.getUniqueSites();
      final categories =
          await DatabaseService.platformService.getAvailableCategories();
      final priceRange = await DatabaseService.platformService.getPriceRange();

      print('Loaded sites: $sites');
      print('Loaded categories: $categories');
      print('Loaded price range: $priceRange');

      setState(() {
        _availableSites = ['All', ...sites];
        _availableCategories = categories;
        _priceRange = priceRange;
      });
    } catch (e) {
      print('Error loading filter options: $e');
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
                    selected: _filter.inStock == null,
                    onSelected: (_) async {
                      // Only clear stock filter, keep other filters intact
                      setState(() {
                        _filter = _filter.copyWith(inStock: null);
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
                        _filter = _filter.copyWith(favoritesOnly: isSelected);
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
}
