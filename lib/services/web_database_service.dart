import 'package:flutter/foundation.dart';
import '../models/matcha_product.dart';
import '../models/scan_activity.dart';

// Web-compatible database service using browser local storage
class WebDatabaseService {
  static final WebDatabaseService _instance = WebDatabaseService._internal();
  factory WebDatabaseService() => _instance;
  WebDatabaseService._internal();

  static WebDatabaseService get instance => _instance;

  // In-memory storage for web (in a real implementation, you'd use IndexedDB)
  final Map<String, MatchaProduct> _products = {};
  final List<Map<String, dynamic>> _stockHistory = [];
  final Set<String> _favoriteProductIds = {};
  final List<ScanActivity> _scanActivities = [];

  Future<void> initDatabase() async {
    // Initialize web storage - in production you'd use shared_preferences_web
    // or IndexedDB for persistent storage
    if (kDebugMode) {
      print('Initializing web database...');
    }
  }

  Future<void> insertProduct(MatchaProduct product) async {
    _products[product.id] = product;
  }

  Future<void> updateProduct(MatchaProduct product) async {
    _products[product.id] = product;
  }

  Future<void> insertOrUpdateProduct(MatchaProduct product) async {
    final existing = _products[product.id];
    if (existing != null) {
      // Update existing product, keeping firstSeen date
      final updatedProduct = product.copyWith(firstSeen: existing.firstSeen);
      _products[product.id] = updatedProduct;
    } else {
      _products[product.id] = product;
    }
  }

  Future<void> markProductAsDiscontinued(String productId) async {
    final product = _products[productId];
    if (product != null) {
      _products[productId] = product.copyWith(isDiscontinued: true);
    }
  }

  Future<List<MatchaProduct>> getAllProducts() async {
    return _products.values.toList();
  }

  Future<PaginatedProducts> getProductsPaginated({
    int page = 1,
    int itemsPerPage = 20,
    ProductFilter? filter,
    String sortBy = 'name',
    bool sortAscending = true,
  }) async {
    List<MatchaProduct> allProducts = _products.values.toList();

    // Apply filters
    if (filter != null) {
      allProducts =
          allProducts.where((product) {
            // Handle favorites filter
            if (filter.favoritesOnly &&
                !_favoriteProductIds.contains(product.id)) {
              return false;
            }

            // Handle multiple sites filter
            if (filter.sites != null &&
                filter.sites!.isNotEmpty &&
                !filter.sites!.contains(product.site)) {
              return false;
            }

            if (filter.inStock != null && product.isInStock != filter.inStock) {
              return false;
            }

            if (!filter.showDiscontinued && product.isDiscontinued) {
              return false;
            }

            if (filter.minPrice != null &&
                (product.priceValue ?? 0) < filter.minPrice!) {
              return false;
            }

            if (filter.maxPrice != null &&
                (product.priceValue ?? double.infinity) > filter.maxPrice!) {
              return false;
            }

            if (filter.category != null &&
                product.category != filter.category) {
              return false;
            }

            if (filter.searchTerm != null && filter.searchTerm!.isNotEmpty) {
              String searchTerm = filter.searchTerm!.toLowerCase();
              if (!product.normalizedName.contains(searchTerm) &&
                  !product.name.toLowerCase().contains(searchTerm)) {
                return false;
              }
            }

            return true;
          }).toList();
    }

    // Sort products
    allProducts.sort((a, b) {
      int result = 0;
      switch (sortBy) {
        case 'name':
          result = a.name.compareTo(b.name);
          break;
        case 'lastChecked':
          result = a.lastChecked.compareTo(b.lastChecked);
          break;
        case 'firstSeen':
          result = a.firstSeen.compareTo(b.firstSeen);
          break;
        case 'site':
          result = a.site.compareTo(b.site);
          break;
        case 'priceValue':
          result = (a.priceValue ?? 0).compareTo(b.priceValue ?? 0);
          break;
        default:
          result = a.name.compareTo(b.name);
      }
      return sortAscending ? result : -result;
    });

    int totalItems = allProducts.length;
    int totalPages = (totalItems / itemsPerPage).ceil();
    int startIndex = (page - 1) * itemsPerPage;
    int endIndex = startIndex + itemsPerPage;

    List<MatchaProduct> pageProducts = allProducts.sublist(
      startIndex,
      endIndex > totalItems ? totalItems : endIndex,
    );

    return PaginatedProducts(
      products: pageProducts,
      currentPage: page,
      totalPages: totalPages,
      totalItems: totalItems,
      itemsPerPage: itemsPerPage,
    );
  }

  Future<MatchaProduct?> getProduct(String id) async {
    return _products[id];
  }

  Future<List<MatchaProduct>> getProductsBySite(String site) async {
    return _products.values.where((product) => product.site == site).toList();
  }

  Future<List<String>> getAvailableCategories() async {
    Set<String> categories = {};
    for (var product in _products.values) {
      if (product.category != null) {
        categories.add(product.category!);
      }
    }
    return categories.toList();
  }

  Future<Map<String, double>> getPriceRange() async {
    double min = double.infinity;
    double max = 0.0;

    for (var product in _products.values) {
      if (product.priceValue != null) {
        if (product.priceValue! < min) min = product.priceValue!;
        if (product.priceValue! > max) max = product.priceValue!;
      }
    }

    if (min == double.infinity) {
      return {'min': 0.0, 'max': 1000.0};
    }

    return {'min': min, 'max': max};
  }

  Future<StorageInfo> getStorageInfo(int maxStorageMB) async {
    int totalProducts = _products.length;
    int avgProductSize = 2000; // bytes per product (estimated)
    int totalSizeBytes = totalProducts * avgProductSize;
    int maxSizeBytes = maxStorageMB * 1024 * 1024;

    return StorageInfo(
      totalProducts: totalProducts,
      totalSizeBytes: totalSizeBytes,
      maxSizeBytes: maxSizeBytes,
    );
  }

  Future<void> cleanupOldProducts(int maxStorageMB) async {
    final storageInfo = await getStorageInfo(maxStorageMB);

    if (storageInfo.usagePercentage > 90) {
      // Remove oldest discontinued or out-of-stock products
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      _products.removeWhere(
        (key, product) =>
            (product.isDiscontinued || !product.isInStock) &&
            product.firstSeen.isBefore(cutoffDate),
      );
    }
  }

  Future<void> recordStockChange(String productId, bool isInStock) async {
    _stockHistory.add({
      'productId': productId,
      'isInStock': isInStock,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<void> recordStockStatus(String productId, bool isInStock) async {
    // This is the same as recordStockChange for web implementation
    await recordStockChange(productId, isInStock);
  }

  Future<List<Map<String, dynamic>>> getStockHistory(String productId) async {
    return _stockHistory
        .where((history) => history['productId'] == productId)
        .toList()
        .reversed
        .take(50)
        .toList();
  }

  Future<void> deleteOldHistory() async {
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    _stockHistory.removeWhere(
      (history) => DateTime.parse(history['timestamp']).isBefore(cutoffDate),
    );
  }

  // Custom Website Management Methods (Web Implementation)
  final Map<String, CustomWebsite> _customWebsites = {};

  Future<void> insertCustomWebsite(CustomWebsite website) async {
    _customWebsites[website.id] = website;
  }

  Future<void> updateCustomWebsite(CustomWebsite website) async {
    _customWebsites[website.id] = website;
  }

  Future<void> deleteCustomWebsite(String id) async {
    _customWebsites.remove(id);

    // Also delete products from this website
    _products.removeWhere((key, product) => product.site == id);
  }

  Future<List<CustomWebsite>> getCustomWebsites() async {
    return _customWebsites.values.toList();
  }

  Future<List<CustomWebsite>> getEnabledCustomWebsites() async {
    return _customWebsites.values.where((w) => w.isEnabled).toList();
  }

  Future<CustomWebsite?> getCustomWebsite(String id) async {
    return _customWebsites[id];
  }

  Future<void> updateWebsiteTestStatus(String id, String status) async {
    final website = _customWebsites[id];
    if (website != null) {
      _customWebsites[id] = website.copyWith(
        lastTested: DateTime.now(),
        testStatus: status,
      );
    }
  }

  // Favorites management methods
  Future<void> addToFavorites(String productId) async {
    _favoriteProductIds.add(productId);
  }

  Future<void> removeFromFavorites(String productId) async {
    _favoriteProductIds.remove(productId);
  }

  Future<bool> isFavorite(String productId) async {
    return _favoriteProductIds.contains(productId);
  }

  Future<List<String>> getFavoriteProductIds() async {
    return _favoriteProductIds.toList();
  }

  Future<List<MatchaProduct>> getFavoriteProducts() async {
    return _products.values
        .where((product) => _favoriteProductIds.contains(product.id))
        .toList();
  }

  Future<int> getFavoriteProductsCount() async {
    return _favoriteProductIds.length;
  }

  // Scan activities management methods
  Future<void> insertScanActivity(ScanActivity activity) async {
    _scanActivities.add(activity);
    // Keep only the latest 100 activities to prevent memory issues
    if (_scanActivities.length > 100) {
      _scanActivities.removeAt(0);
    }
  }

  Future<List<ScanActivity>> getScanActivities({
    int limit = 50,
    int offset = 0,
  }) async {
    final sortedActivities = List<ScanActivity>.from(_scanActivities)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final endIndex = (offset + limit).clamp(0, sortedActivities.length);
    if (offset >= sortedActivities.length) {
      return [];
    }

    return sortedActivities.sublist(offset, endIndex);
  }

  Future<int> getScanActivitiesCount() async {
    return _scanActivities.length;
  }

  Future<void> deleteScanActivity(String id) async {
    _scanActivities.removeWhere((activity) => activity.id == id);
  }

  Future<void> clearOldScanActivities({int keepDays = 30}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    _scanActivities.removeWhere(
      (activity) => activity.timestamp.isBefore(cutoffDate),
    );
  }

  Future<void> clearAllScanActivities() async {
    _scanActivities.clear();
  }

  Future<void> savePriceForProduct(MatchaProduct product) async {
    // For web implementation, this is a no-op since we don't have
    // a separate price history table. Price history would be implemented
    // with IndexedDB in a full production version.
    if (kDebugMode) {
      print('Web: savePriceForProduct called for ${product.id}');
    }
  }
}
