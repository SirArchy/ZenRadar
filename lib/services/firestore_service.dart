import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/matcha_product.dart';

/// Firestore database service for server mode
/// Handles direct integration with Cloud Firestore for real-time data
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  static FirestoreService get instance => _instance;

  late final FirebaseFirestore _firestore;

  /// Initialize Firestore service
  Future<void> initDatabase() async {
    _firestore = FirebaseFirestore.instance;

    if (kDebugMode) {
      print('Firestore service initialized');
    }
  }

  /// Get paginated products with filtering and sorting
  Future<PaginatedProducts> getProductsPaginated({
    required int page,
    required int itemsPerPage,
    ProductFilter? filter,
    String sortBy = 'lastChecked',
    bool sortAscending = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('products');

      // Apply filters
      if (filter != null) {
        if (filter.inStock != null) {
          query = query.where('isInStock', isEqualTo: filter.inStock);
        }

        if (filter.sites != null && filter.sites!.isNotEmpty) {
          query = query.where('site', whereIn: filter.sites);
        }

        if (filter.category != null && filter.category!.isNotEmpty) {
          query = query.where('category', isEqualTo: filter.category);
        }
      }

      // Apply sorting
      query = query.orderBy(sortBy, descending: !sortAscending);

      // For Firestore pagination, we'll use limit only (no offset)
      // This is a simplified approach - in production you'd use cursor pagination
      final snapshot = await query.limit(itemsPerPage * page).get();

      // Get total count separately (if needed for pagination info)
      final countQuery = _firestore.collection('products');
      final countSnapshot = await countQuery.count().get();
      final totalItems = countSnapshot.count ?? 0;
      final totalPages = (totalItems / itemsPerPage).ceil();

      // Skip items for the requested page (client-side pagination)
      final startIndex = (page - 1) * itemsPerPage;
      final allProducts =
          snapshot.docs
              .map((doc) => MatchaProduct.fromFirestore(doc.id, doc.data()))
              .toList();

      final products = allProducts.skip(startIndex).take(itemsPerPage).toList();

      // Apply additional filters that can't be done in Firestore
      List<MatchaProduct> filteredProducts = products;

      if (filter != null) {
        if (filter.searchTerm != null && filter.searchTerm!.isNotEmpty) {
          final searchLower = filter.searchTerm!.toLowerCase();
          filteredProducts =
              filteredProducts
                  .where(
                    (product) =>
                        product.name.toLowerCase().contains(searchLower) ||
                        product.site.toLowerCase().contains(searchLower),
                  )
                  .toList();
        }

        if (filter.minPrice != null) {
          filteredProducts =
              filteredProducts
                  .where(
                    (product) =>
                        product.priceValue != null &&
                        product.priceValue! >= filter.minPrice!,
                  )
                  .toList();
        }

        if (filter.maxPrice != null) {
          filteredProducts =
              filteredProducts
                  .where(
                    (product) =>
                        product.priceValue != null &&
                        product.priceValue! <= filter.maxPrice!,
                  )
                  .toList();
        }

        if (filter.favoritesOnly) {
          // Get favorite product IDs from local storage
          final favoriteIds = await _getFavoriteProductIds();
          filteredProducts =
              filteredProducts
                  .where((product) => favoriteIds.contains(product.id))
                  .toList();
        }
      }

      if (kDebugMode) {
        print(
          'Loaded ${filteredProducts.length} products from Firestore (page $page)',
        );
      }

      return PaginatedProducts(
        products: filteredProducts,
        totalItems: totalItems,
        totalPages: totalPages,
        currentPage: page,
        itemsPerPage: itemsPerPage,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error loading products from Firestore: $e');
      }
      rethrow;
    }
  }

  /// Get all products (for non-paginated queries)
  Future<List<MatchaProduct>> getAllProducts({ProductFilter? filter}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('products');

      // Apply filters
      if (filter != null) {
        if (filter.inStock != null) {
          query = query.where('isInStock', isEqualTo: filter.inStock);
        }

        if (filter.sites != null && filter.sites!.isNotEmpty) {
          query = query.where('site', whereIn: filter.sites);
        }

        if (filter.category != null && filter.category!.isNotEmpty) {
          query = query.where('category', isEqualTo: filter.category);
        }
      }

      final snapshot = await query.get();
      List<MatchaProduct> products =
          snapshot.docs
              .map((doc) => MatchaProduct.fromFirestore(doc.id, doc.data()))
              .toList();

      // Apply additional filters
      if (filter != null) {
        if (filter.searchTerm != null && filter.searchTerm!.isNotEmpty) {
          final searchLower = filter.searchTerm!.toLowerCase();
          products =
              products
                  .where(
                    (product) =>
                        product.name.toLowerCase().contains(searchLower) ||
                        product.site.toLowerCase().contains(searchLower),
                  )
                  .toList();
        }

        if (filter.minPrice != null) {
          products =
              products
                  .where(
                    (product) =>
                        product.priceValue != null &&
                        product.priceValue! >= filter.minPrice!,
                  )
                  .toList();
        }

        if (filter.maxPrice != null) {
          products =
              products
                  .where(
                    (product) =>
                        product.priceValue != null &&
                        product.priceValue! <= filter.maxPrice!,
                  )
                  .toList();
        }
      }

      if (kDebugMode) {
        print('Loaded ${products.length} products from Firestore');
      }

      return products;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading all products from Firestore: $e');
      }
      rethrow;
    }
  }

  /// Get products by site
  Future<List<MatchaProduct>> getProductsBySite(String siteName) async {
    try {
      final snapshot =
          await _firestore
              .collection('products')
              .where('site', isEqualTo: siteName)
              .orderBy('lastChecked', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => MatchaProduct.fromFirestore(doc.id, doc.data()))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading products by site from Firestore: $e');
      }
      rethrow;
    }
  }

  /// Get product by ID
  Future<MatchaProduct?> getProductById(String productId) async {
    try {
      final doc = await _firestore.collection('products').doc(productId).get();

      if (doc.exists && doc.data() != null) {
        return MatchaProduct.fromFirestore(doc.id, doc.data()!);
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading product by ID from Firestore: $e');
      }
      rethrow;
    }
  }

  /// Listen to product updates in real-time
  Stream<List<MatchaProduct>> listenToProducts({ProductFilter? filter}) {
    try {
      Query<Map<String, dynamic>> query = _firestore.collection('products');

      // Apply filters
      if (filter != null) {
        if (filter.inStock != null) {
          query = query.where('isInStock', isEqualTo: filter.inStock);
        }

        if (filter.sites != null && filter.sites!.isNotEmpty) {
          query = query.where('site', whereIn: filter.sites);
        }

        if (filter.category != null && filter.category!.isNotEmpty) {
          query = query.where('category', isEqualTo: filter.category);
        }
      }

      query = query.orderBy('lastChecked', descending: true);

      return query.snapshots().map((snapshot) {
        List<MatchaProduct> products =
            snapshot.docs
                .map((doc) => MatchaProduct.fromFirestore(doc.id, doc.data()))
                .toList();

        // Apply additional filters
        if (filter != null) {
          if (filter.searchTerm != null && filter.searchTerm!.isNotEmpty) {
            final searchLower = filter.searchTerm!.toLowerCase();
            products =
                products
                    .where(
                      (product) =>
                          product.name.toLowerCase().contains(searchLower) ||
                          product.site.toLowerCase().contains(searchLower),
                    )
                    .toList();
          }

          if (filter.minPrice != null) {
            products =
                products
                    .where(
                      (product) =>
                          product.priceValue != null &&
                          product.priceValue! >= filter.minPrice!,
                    )
                    .toList();
          }

          if (filter.maxPrice != null) {
            products =
                products
                    .where(
                      (product) =>
                          product.priceValue != null &&
                          product.priceValue! <= filter.maxPrice!,
                    )
                    .toList();
          }
        }

        return products;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error listening to products from Firestore: $e');
      }
      rethrow;
    }
  }

  /// Get unique sites from products
  Future<List<String>> getUniqueSites() async {
    try {
      final snapshot = await _firestore.collection('products').get();
      final sites =
          snapshot.docs
              .map((doc) => doc.data()['site'] as String?)
              .where((site) => site != null)
              .cast<String>()
              .toSet()
              .toList();

      sites.sort();
      return sites;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading unique sites from Firestore: $e');
      }
      return [];
    }
  }

  /// Get unique categories from products
  Future<List<String>> getUniqueCategories() async {
    try {
      final snapshot = await _firestore.collection('products').get();
      final categories =
          snapshot.docs
              .map((doc) => doc.data()['category'] as String?)
              .where((category) => category != null)
              .cast<String>()
              .toSet()
              .toList();

      categories.sort();
      return categories;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading unique categories from Firestore: $e');
      }
      return [];
    }
  }

  /// Helper method to get favorite product IDs (placeholder)
  /// In a real implementation, this would sync with user preferences
  Future<Set<String>> _getFavoriteProductIds() async {
    // TODO: Implement user favorites sync with Firestore
    // For now, return empty set
    return <String>{};
  }
}
