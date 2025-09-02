import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/matcha_product.dart';
import '../models/stock_history.dart';
import '../models/price_history.dart';

/// Firestore database service for server mode
/// Handles direct integration with Cloud Firestore for real-time data
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  static FirestoreService get instance => _instance;

  FirebaseFirestore? _firestore;
  bool _isInitialized = false;

  /// Get the Firestore instance, ensuring it's initialized
  FirebaseFirestore get firestore {
    if (_firestore == null) {
      throw StateError(
        'FirestoreService not initialized. Call initDatabase() first.',
      );
    }
    return _firestore!;
  }

  /// Initialize Firestore service
  Future<void> initDatabase() async {
    if (!_isInitialized) {
      _firestore = FirebaseFirestore.instance;
      _isInitialized = true;
      if (kDebugMode) {
        print('Firestore service initialized');
      }
    }
  }

  /// Convert site display names to site keys for Firestore queries
  List<String> _convertSiteNamesToKeys(List<String> siteNames) {
    // Site mapping: display name -> site key
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

    final siteKeys = <String>[];
    for (final siteName in siteNames) {
      final siteKey = siteNameToKey[siteName];
      if (siteKey != null) {
        siteKeys.add(siteKey);
      } else {
        // If not found in mapping, try to use the name as-is (in case it's already a key)
        siteKeys.add(siteName.toLowerCase());
      }
    }

    if (kDebugMode) {
      print('🔄 Converted site names $siteNames to keys $siteKeys');
    }

    return siteKeys;
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
      Query<Map<String, dynamic>> query = firestore.collection('products');

      // Apply filters
      if (filter != null) {
        if (kDebugMode) {
          print('🔍 Applying filter: ${filter.toString()}');
        }

        if (filter.inStock != null) {
          query = query.where('isInStock', isEqualTo: filter.inStock);
        }

        if (filter.sites != null && filter.sites!.isNotEmpty) {
          // Convert display names to site keys for Firestore query
          final siteKeys = _convertSiteNamesToKeys(filter.sites!);
          if (kDebugMode) {
            print('🌐 Filtering by sites: ${filter.sites} -> $siteKeys');
          }
          query = query.where('site', whereIn: siteKeys);
        }

        if (filter.categories != null && filter.categories!.isNotEmpty) {
          query = query.where('category', whereIn: filter.categories);
        }
      }

      // Apply sorting
      query = query.orderBy(sortBy, descending: !sortAscending);

      // For Firestore pagination, we'll use limit only (no offset)
      // This is a simplified approach - in production you'd use cursor pagination
      final snapshot = await query.limit(itemsPerPage * page).get();

      // Get total count separately (if needed for pagination info)
      // Get total count
      final countQuery = firestore.collection('products');
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
          final favoriteIds = await getFavoriteProductIds();
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
      Query<Map<String, dynamic>> query = firestore.collection('products');

      // Apply filters
      if (filter != null) {
        if (filter.inStock != null) {
          query = query.where('isInStock', isEqualTo: filter.inStock);
        }

        if (filter.sites != null && filter.sites!.isNotEmpty) {
          // Convert display names to site keys for Firestore query
          final siteKeys = _convertSiteNamesToKeys(filter.sites!);
          query = query.where('site', whereIn: siteKeys);
        }

        if (filter.categories != null && filter.categories!.isNotEmpty) {
          query = query.where('category', whereIn: filter.categories);
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

  /// Get product by ID
  Future<MatchaProduct?> getProductById(String productId) async {
    try {
      final doc = await firestore.collection('products').doc(productId).get();

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
      Query<Map<String, dynamic>> query = firestore.collection('products');

      // Apply filters
      if (filter != null) {
        if (filter.inStock != null) {
          query = query.where('isInStock', isEqualTo: filter.inStock);
        }

        if (filter.sites != null && filter.sites!.isNotEmpty) {
          query = query.where('site', whereIn: filter.sites);
        }

        if (filter.categories != null && filter.categories!.isNotEmpty) {
          query = query.where('category', whereIn: filter.categories);
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

  /// Convert site keys to display names for UI
  List<String> _convertSiteKeysToNames(List<String> siteKeys) {
    // Site mapping: site key -> display name
    final siteKeyToName = <String, String>{
      'tokichi': 'Nakamura Tokichi',
      'marukyu': 'Marukyu-Koyamaen',
      'ippodo': 'Ippodo Tea',
      'yoshien': 'Yoshi En',
      'matcha-karu': 'Matcha Kāru',
      'sho-cha': 'Sho-Cha',
      'sazentea': 'Sazen Tea',
      'enjoyemeri': 'Emeri',
      'poppatea': 'Poppatea',
      'horiishichimeien': 'Horiishichimeien',
    };

    final siteNames = <String>[];
    for (final siteKey in siteKeys) {
      final siteName = siteKeyToName[siteKey];
      if (siteName != null) {
        siteNames.add(siteName);
      } else {
        // If not found in mapping, use the key as-is (capitalized)
        siteNames.add(
          siteKey
              .split('-')
              .map(
                (word) =>
                    word.isEmpty
                        ? word
                        : word[0].toUpperCase() + word.substring(1),
              )
              .join(' '),
        );
      }
    }

    return siteNames;
  }

  /// Get unique sites from products
  Future<List<String>> getUniqueSites() async {
    try {
      final snapshot = await firestore.collection('products').get();
      final siteKeys =
          snapshot.docs
              .map((doc) => doc.data()['site'] as String?)
              .where((site) => site != null)
              .cast<String>()
              .toSet()
              .toList();

      siteKeys.sort();

      // Convert site keys to display names
      final siteNames = _convertSiteKeysToNames(siteKeys);

      if (kDebugMode) {
        print('🌐 Found sites: $siteKeys -> $siteNames');
      }

      return siteNames;
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
      final snapshot = await firestore.collection('products').get();
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

  /// Get favorite product IDs from Firestore for the current user
  Future<Set<String>> getFavoriteProductIds() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('No authenticated user for favorites');
        }
        return <String>{};
      }

      final querySnapshot =
          await firestore
              .collection('user_favorites')
              .where('userId', isEqualTo: user.uid)
              .get();

      final favoriteIds = <String>{};

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final productId = data['productId'] as String?;
        if (productId != null) {
          favoriteIds.add(productId);
        }
      }

      return favoriteIds;
    } catch (e) {
      if (kDebugMode) {
        print('Error loading user favorites from Firestore: $e');
      }
      return <String>{};
    }
  }

  /// Add a product to user favorites in Firestore
  Future<void> addToFavorites(String productId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('No authenticated user - cannot add to favorites');
        }
        return;
      }

      // Check if already exists to avoid duplicates
      final existingQuery =
          await firestore
              .collection('user_favorites')
              .where('userId', isEqualTo: user.uid)
              .where('productId', isEqualTo: productId)
              .limit(1)
              .get();

      if (existingQuery.docs.isEmpty) {
        await firestore.collection('user_favorites').add({
          'userId': user.uid,
          'productId': productId,
          'addedAt': FieldValue.serverTimestamp(),
        });

        if (kDebugMode) {
          print('Product $productId added to favorites in Firestore');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error adding favorite to Firestore: $e');
      }
    }
  }

  /// Remove a product from user favorites in Firestore
  Future<void> removeFromFavorites(String productId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (kDebugMode) {
          print('No authenticated user - cannot remove from favorites');
        }
        return;
      }

      // Find and delete the document
      final querySnapshot =
          await firestore
              .collection('user_favorites')
              .where('userId', isEqualTo: user.uid)
              .where('productId', isEqualTo: productId)
              .get();

      for (final doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      if (kDebugMode) {
        print('Product $productId removed from favorites in Firestore');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error removing favorite from Firestore: $e');
      }
    }
  }

  /// Get products for a specific site
  Future<List<MatchaProduct>> getProductsBySite(String siteKey) async {
    try {
      final querySnapshot =
          await firestore
              .collection('products')
              .where('site', isEqualTo: siteKey)
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return MatchaProduct(
          id: data['id'] ?? doc.id,
          name: data['name'] ?? '',
          normalizedName:
              data['normalizedName'] ?? data['name']?.toLowerCase() ?? '',
          site: data['site'] ?? '',
          url: data['url'] ?? '',
          isInStock: data['isInStock'] ?? false,
          isDiscontinued: data['isDiscontinued'] ?? false,
          missedScans: data['missedScans'] ?? 0,
          lastChecked:
              (data['lastChecked'] as Timestamp?)?.toDate() ?? DateTime.now(),
          firstSeen:
              (data['firstSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
          price: data['price'] ?? '',
          priceValue: (data['priceValue'] as num?)?.toDouble() ?? 0.0,
          currency: data['currency'] ?? 'EUR',
          category: data['category'] ?? 'Matcha',
          weight:
              data['weight'] is int
                  ? data['weight']
                  : (data['weight'] as num?)?.toInt(),
          imageUrl: data['imageUrl'],
          description: data['description'],
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching products for site $siteKey: $e');
      }
      return [];
    }
  }

  /// Get stock history for a site within a date range
  Future<List<StockHistory>> getStockHistoryForSite(
    String siteKey,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final querySnapshot =
          await firestore
              .collection('stock_history')
              .where('site', isEqualTo: siteKey)
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
              )
              .where(
                'timestamp',
                isLessThanOrEqualTo: Timestamp.fromDate(endDate),
              )
              .orderBy('timestamp', descending: true)
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return StockHistory(
          id: null, // Firestore documents don't have integer IDs
          productId: data['productId'] ?? '',
          isInStock: data['isInStock'] ?? false,
          timestamp:
              (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching stock history for site $siteKey: $e');
      }
      return [];
    }
  }

  /// Get crawl requests for background activity screen
  Future<List<Map<String, dynamic>>> getCrawlRequests({int limit = 20}) async {
    try {
      final querySnapshot =
          await firestore
              .collection('crawl_requests')
              .orderBy('createdAt', descending: true)
              .limit(limit)
              .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'status': data['status'] ?? 'unknown',
          'createdAt': data['createdAt'],
          'completedAt': data['completedAt'],
          'duration': data['duration'] ?? 0,
          'totalProducts': data['totalProducts'] ?? 0,
          'stockUpdates': data['stockUpdates'] ?? 0,
          'sitesProcessed': data['sitesProcessed'] ?? 0,
          'triggerType': data['triggerType'] ?? 'unknown',
          'results': data['results'] ?? {},
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching crawl requests: $e');
      }
      return [];
    }
  }

  /// Get price range from all products
  Future<Map<String, double>> getPriceRange() async {
    try {
      final querySnapshot = await firestore.collection('products').get();

      double minPrice = double.infinity;
      double maxPrice = 0.0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final priceValue = (data['priceValue'] as num?)?.toDouble();
        if (priceValue != null && priceValue > 0) {
          if (priceValue < minPrice) minPrice = priceValue;
          if (priceValue > maxPrice) maxPrice = priceValue;
        }
      }

      return {
        'min': minPrice == double.infinity ? 0.0 : minPrice,
        'max': maxPrice,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error getting price range from Firestore: $e');
      }
      return {'min': 0.0, 'max': 1000.0};
    }
  }

  /// Get custom websites (placeholder - not applicable for server mode)
  Future<List<dynamic>> getCustomWebsites() async {
    // Custom websites are only available in local mode
    // Return empty list for server mode
    return [];
  }

  /// Insert scan activity (placeholder - activities are server-generated in server mode)
  Future<void> insertScanActivity(dynamic scanActivity) async {
    // Scan activities are generated by the server in server mode
    // This is a no-op for client-side
    if (kDebugMode) {
      print('insertScanActivity: Not applicable in server mode');
    }
  }

  /// Get price analytics for a product
  Future<PriceAnalytics> getPriceAnalyticsForProduct(String productId) async {
    try {
      final priceHistory = await getPriceHistoryForProduct(productId);
      return PriceAnalytics.fromHistory(priceHistory);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting price analytics from Firestore: $e');
      }
      return PriceAnalytics.fromHistory([]);
    }
  }

  /// Get price history for a product
  Future<List<PriceHistory>> getPriceHistoryForProduct(String productId) async {
    try {
      if (kDebugMode) {
        print('🔍 Loading price history for product: $productId');

        // Check authentication status
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          print('👤 Authenticated as: ${user.email ?? user.uid}');
        } else {
          print('❌ No authenticated user - this will fail!');
          return [];
        }
      }

      final snapshot =
          await firestore
              .collection('price_history')
              .where('productId', isEqualTo: productId)
              .orderBy('date', descending: false)
              .get();

      if (kDebugMode) {
        print('📊 Found ${snapshot.docs.length} price history entries');
      }

      final priceHistory =
          snapshot.docs.map((doc) {
            final data = doc.data();

            if (kDebugMode) {
              print(
                '💰 Price entry: ${data['date']} - ${data['price']} ${data['currency']}',
              );
            }

            // Handle the price field which might be a large number that needs conversion
            double priceValue = 0.0;
            final rawPrice = data['price'];
            if (rawPrice is num) {
              priceValue = rawPrice.toDouble();
              // Check if this looks like it needs to be converted based on currency
              final currency = data['currency'] ?? 'EUR';

              if (currency == 'EUR' && priceValue > 10000) {
                // Large EUR values are likely in cents, convert to euros
                priceValue = priceValue / 100.0;
              } else if (currency == 'JPY' && priceValue > 100000) {
                // Very large JPY values might be incorrectly stored
                priceValue = priceValue / 100.0;
              }

              if (kDebugMode) {
                print('💰 Price converted: $rawPrice -> $priceValue $currency');
              }
            }

            return PriceHistory(
              id: doc.id,
              productId: data['productId'] ?? '',
              date: (data['date'] as Timestamp).toDate(),
              price: priceValue,
              currency: data['currency'] ?? 'EUR',
              isInStock: data['isInStock'] ?? false,
            );
          }).toList();

      if (kDebugMode) {
        print('✅ Processed ${priceHistory.length} price history entries');
      }

      return priceHistory;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting price history from Firestore: $e');
      }
      return [];
    }
  }

  /// Get stock analytics for a product
  Future<StockAnalytics> getStockAnalyticsForProduct(
    String productId, {
    int? limitDays,
  }) async {
    try {
      final stockHistory = await getStockHistoryForProduct(
        productId,
        limitDays: limitDays,
      );
      return StockAnalytics.fromHistory(stockHistory);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting stock analytics from Firestore: $e');
      }
      return StockAnalytics.fromHistory([]);
    }
  }

  /// Get stock history for a product
  Future<List<StockHistory>> getStockHistoryForProduct(
    String productId, {
    int? limitDays,
  }) async {
    try {
      if (kDebugMode) {
        print(
          '🔍 Loading stock history for product: $productId (limitDays: $limitDays)',
        );

        // Check authentication status
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          print('👤 Authenticated as: ${user.email ?? user.uid}');
        } else {
          print('❌ No authenticated user for stock history - this will fail!');
          return [];
        }
      }

      Query<Map<String, dynamic>> query = firestore
          .collection('stock_history')
          .where('productId', isEqualTo: productId)
          .orderBy('timestamp', descending: false);

      // Apply date filter if specified
      if (limitDays != null) {
        final cutoffDate = DateTime.now().subtract(Duration(days: limitDays));
        query = query.where(
          'timestamp',
          isGreaterThan: Timestamp.fromDate(cutoffDate),
        );
      }

      final snapshot =
          await query.limit(1000).get(); // Limit to prevent huge queries

      if (kDebugMode) {
        print('📊 Found ${snapshot.docs.length} stock history entries');
      }

      final stockHistory =
          snapshot.docs.map((doc) {
            final data = doc.data();

            if (kDebugMode) {
              print(
                '📈 Stock entry: ${data['timestamp']} - inStock: ${data['isInStock']}',
              );
            }

            return StockHistory(
              productId: data['productId'] ?? '',
              isInStock: data['isInStock'] ?? false,
              timestamp: (data['timestamp'] as Timestamp).toDate(),
            );
          }).toList();

      if (kDebugMode) {
        print('✅ Processed ${stockHistory.length} stock history entries');
      }

      return stockHistory;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting stock history from Firestore: $e');
      }
      return [];
    }
  }

  /// Get stock history for a specific day
  Future<List<StockHistory>> getStockHistoryForDay(
    String productId,
    DateTime day,
  ) async {
    try {
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final snapshot =
          await firestore
              .collection('stock_history')
              .where('productId', isEqualTo: productId)
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart),
              )
              .where('timestamp', isLessThan: Timestamp.fromDate(dayEnd))
              .orderBy('timestamp', descending: false)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return StockHistory(
          productId: data['productId'] ?? '',
          isInStock: data['isInStock'] ?? false,
          timestamp: (data['timestamp'] as Timestamp).toDate(),
        );
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting stock history for day from Firestore: $e');
      }
      return [];
    }
  }
}
