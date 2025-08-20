// ignore_for_file: avoid_print

import '../models/matcha_product.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';

class RecommendationService {
  static final SettingsService _settingsService = SettingsService();
  static final DatabaseService _databaseService = DatabaseService();
  static final FirestoreService _firestoreService = FirestoreService();

  /// Get product recommendations based on user preferences and popular products
  static Future<List<MatchaProduct>> getRecommendations({
    int limit = 6,
    List<String>? excludeProductIds,
  }) async {
    try {
      final isServerMode = await _settingsService.getServerMode();

      // Get all products using paginated method and extract products
      List<MatchaProduct> allProducts;
      if (isServerMode) {
        final paginatedResult = await _firestoreService.getProductsPaginated(
          page: 1,
          itemsPerPage: 1000, // Get a large batch for recommendations
          filter: ProductFilter(),
        );
        allProducts = paginatedResult.products;
      } else {
        final paginatedResult = await _databaseService.getProductsPaginated(
          page: 1,
          itemsPerPage: 1000, // Get a large batch for recommendations
          filter: ProductFilter(),
        );
        allProducts = paginatedResult.products;
      }

      // Filter out excluded products
      if (excludeProductIds != null && excludeProductIds.isNotEmpty) {
        allProducts =
            allProducts
                .where((product) => !excludeProductIds.contains(product.id))
                .toList();
      }

      // Get user preferences for better recommendations
      final userSettings = await _settingsService.getSettings();

      // Score products based on various factors
      List<ProductScore> scoredProducts =
          allProducts.map((product) {
            double score = _calculateProductScore(product, userSettings);
            return ProductScore(product, score);
          }).toList();

      // Sort by score (highest first)
      scoredProducts.sort((a, b) => b.score.compareTo(a.score));

      // Take the top products up to the limit
      return scoredProducts
          .take(limit)
          .map((scored) => scored.product)
          .toList();
    } catch (e) {
      print('Error getting recommendations: $e');
      return [];
    }
  }

  /// Calculate a score for a product based on various factors
  static double _calculateProductScore(
    MatchaProduct product,
    dynamic userSettings,
  ) {
    double score = 0.0;

    // Base score for in-stock products
    if (product.isInStock) {
      score += 10.0;
    }

    // Score based on price (prefer mid-range prices)
    if (product.priceValue != null && product.priceValue! > 0) {
      // Normalize price score (assuming typical matcha prices range from 10 to 500)
      double normalizedPrice = (product.priceValue! - 10) / (500 - 10);
      // Prefer products in the 20-40% price range (mid-tier)
      if (normalizedPrice >= 0.2 && normalizedPrice <= 0.4) {
        score += 5.0;
      } else if (normalizedPrice >= 0.1 && normalizedPrice <= 0.6) {
        score += 3.0;
      } else {
        score += 1.0;
      }
    }

    // Boost score for products with good availability history
    // (This could be enhanced with actual history data)

    // Prefer products with complete information
    if (product.description != null && product.description!.isNotEmpty) {
      score += 2.0;
    }

    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      score += 1.0;
    }

    // Add variety by site
    switch (product.site.toLowerCase()) {
      case 'tokichi':
        score += 1.5;
        break;
      case 'ippodo':
        score += 1.3;
        break;
      case 'marukyu-koyamaen':
        score += 1.7; // Slightly prefer this premium brand
        break;
      case 'horrimeicha':
        score += 1.2;
        break;
      default:
        score += 1.0;
    }

    // Add some randomness to ensure variety
    score += (product.id.hashCode % 100) / 100.0;

    return score;
  }

  /// Get popular products (most commonly searched/viewed)
  static Future<List<MatchaProduct>> getPopularProducts({int limit = 5}) async {
    try {
      final isServerMode = await _settingsService.getServerMode();

      // For now, we'll simulate popular products by getting high-quality in-stock items
      ProductFilter popularFilter = ProductFilter(
        inStock: true,
        showDiscontinued: false,
      );

      List<MatchaProduct> products;
      if (isServerMode) {
        final paginatedResult = await _firestoreService.getProductsPaginated(
          page: 1,
          itemsPerPage: 100,
          filter: popularFilter,
        );
        products = paginatedResult.products;
      } else {
        final paginatedResult = await _databaseService.getProductsPaginated(
          page: 1,
          itemsPerPage: 100,
          filter: popularFilter,
        );
        products = paginatedResult.products;
      }

      // Sort by a combination of factors that indicate popularity
      products.sort((a, b) {
        // Prefer products with more complete information (indicates quality)
        int aCompleteness = _getProductCompleteness(a);
        int bCompleteness = _getProductCompleteness(b);

        if (aCompleteness != bCompleteness) {
          return bCompleteness.compareTo(aCompleteness);
        }

        // Then by name alphabetically for consistency
        return a.name.compareTo(b.name);
      });

      return products.take(limit).toList();
    } catch (e) {
      print('Error getting popular products: $e');
      return [];
    }
  }

  /// Calculate how complete a product's information is
  static int _getProductCompleteness(MatchaProduct product) {
    int completeness = 0;

    if (product.name.isNotEmpty) completeness++;
    if (product.description != null && product.description!.isNotEmpty) {
      completeness++;
    }
    if (product.priceValue != null && product.priceValue! > 0) completeness++;
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      completeness++;
    }
    if (product.url.isNotEmpty) completeness++;

    return completeness;
  }
}

class ProductScore {
  final MatchaProduct product;
  final double score;

  ProductScore(this.product, this.score);
}
