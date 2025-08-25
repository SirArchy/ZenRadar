// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/matcha_product.dart';
import '../services/database_service.dart';
import '../services/search_history_service.dart';
import '../services/recommendation_service.dart';
import '../widgets/product_card.dart';
import '../widgets/product_filters.dart';
import '../widgets/matcha_icon.dart';
import '../widgets/skeleton_loading.dart';
import 'product_detail_page.dart';

class HomeScreenContent extends StatefulWidget {
  const HomeScreenContent({super.key});

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

    debugPrint('Saved filter: ${filter.toString()}');
  }

  // Helper to restore filter from shared_preferences
  Future<ProductFilter> _loadFilterFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAnyFilter =
        prefs.containsKey('filter_inStock') ||
        prefs.getBool('filter_favoritesOnly') == true ||
        (prefs.getStringList('filter_sites')?.isNotEmpty == true) ||
        (prefs.getString('filter_category')?.isNotEmpty == true) ||
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

    debugPrint('Restored filter: ${restoredFilter.toString()}');
    return restoredFilter;
  }

  @override
  void initState() {
    super.initState();

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
      if (_favoriteProductIds.contains(productId)) {
        await DatabaseService.platformService.removeFavorite(productId);
        setState(() {
          _favoriteProductIds.remove(productId);
        });
      } else {
        await DatabaseService.platformService.addFavorite(productId);
        setState(() {
          _favoriteProductIds.add(productId);
        });
      }
    } catch (e) {
      print('Error toggling favorite: $e');
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final sites = await DatabaseService.platformService.getAvailableSites();
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
    return Column(
      children: [
        _buildSearchBar(),
        if (_showSearchSuggestions) _buildSearchSuggestions(),
        if (_showFilters)
          ProductFilters(
            filter: _filter,
            availableSites: _availableSites,
            availableCategories: _availableCategories,
            priceRange: _priceRange,
            onFilterChanged: _onFilterChanged,
          ),
        _buildStockStatusChips(),
        Expanded(child: _buildProductsList()),
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
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_alt : Icons.filter_alt_outlined,
              color:
                  _showFilters ? Theme.of(context).colorScheme.primary : null,
            ),
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

  Widget _buildStockStatusChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
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
                      (_filter.searchTerm == null ||
                          _filter.searchTerm!.isEmpty),
                  onSelected: (_) async {
                    // Clear all filters to show all products
                    setState(() {
                      _filter =
                          ProductFilter(); // Reset to default empty filter
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
                  labelStyle: TextStyle(
                    color:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.black87
                            : Colors.white,
                  ),
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
                  labelStyle: TextStyle(
                    color:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.black87
                            : Colors.white,
                  ),
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
                  labelStyle: TextStyle(
                    color:
                        Theme.of(context).brightness == Brightness.light
                            ? Colors.black87
                            : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSuggestions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(75),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
            ...(_recentSearches.take(3)).map(
              (search) => ListTile(
                dense: true,
                leading: const Icon(Icons.search, size: 16),
                title: Text(search),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => _removeSearchTerm(search),
                ),
                onTap: () => _selectSearchTerm(search),
              ),
            ),
          ],
          if (_recommendedProducts.isNotEmpty || _isLoadingRecommendations) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.recommend,
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
            if (_isLoadingRecommendations)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...(_recommendedProducts.take(3)).map(
                (product) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.local_cafe, size: 16),
                  title: Text(product.name),
                  subtitle: Text(product.site),
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
        ],
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
