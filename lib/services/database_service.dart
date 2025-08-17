// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/matcha_product.dart';
import '../models/scan_activity.dart';
import '../models/price_history.dart';
import '../models/stock_history.dart';
import 'web_database_service.dart';
import 'firestore_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static DatabaseService get instance => _instance;

  Database? _database;
  static const int _currentVersion = 7; // Increment for schema changes

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite not supported on web. Use WebDatabaseService instead.',
      );
    }
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Factory method to get the appropriate database service
  static dynamic get platformService {
    return _PlatformDatabaseService();
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'zenradar.db');
    return await openDatabase(
      path,
      version: _currentVersion,
      onCreate: _createDatabase,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE matcha_products (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        normalizedName TEXT NOT NULL,
        site TEXT NOT NULL,
        url TEXT NOT NULL,
        isInStock INTEGER NOT NULL,
        isDiscontinued INTEGER DEFAULT 0,
        missedScans INTEGER DEFAULT 0,
        lastChecked TEXT NOT NULL,
        firstSeen TEXT NOT NULL,
        price TEXT,
        priceValue REAL,
        currency TEXT,
        imageUrl TEXT,
        description TEXT,
        category TEXT,
        weight INTEGER,
        metadata TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId TEXT NOT NULL,
        isInStock INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES matcha_products (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE custom_websites (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        baseUrl TEXT NOT NULL,
        stockSelector TEXT NOT NULL,
        productSelector TEXT NOT NULL,
        nameSelector TEXT NOT NULL,
        priceSelector TEXT NOT NULL,
        linkSelector TEXT NOT NULL,
        isEnabled INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        lastTested TEXT,
        testStatus TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE favorite_products (
        productId TEXT PRIMARY KEY,
        addedAt TEXT NOT NULL,
        FOREIGN KEY (productId) REFERENCES matcha_products (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE scan_activities (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        itemsScanned INTEGER NOT NULL,
        duration INTEGER NOT NULL,
        hasStockUpdates INTEGER NOT NULL,
        details TEXT,
        scanType TEXT DEFAULT 'background'
      )
    ''');

    await db.execute('''
      CREATE TABLE price_history (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL,
        date TEXT NOT NULL,
        price REAL NOT NULL,
        currency TEXT NOT NULL,
        isInStock INTEGER NOT NULL,
        FOREIGN KEY (productId) REFERENCES matcha_products (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_site ON matcha_products(site)');
    await db.execute(
      'CREATE INDEX idx_normalized_name ON matcha_products(normalizedName)',
    );
    await db.execute(
      'CREATE INDEX idx_price_value ON matcha_products(priceValue)',
    );
    await db.execute(
      'CREATE INDEX idx_last_checked ON matcha_products(lastChecked)',
    );
    await db.execute(
      'CREATE INDEX idx_discontinued ON matcha_products(isDiscontinued)',
    );
    await db.execute(
      'CREATE INDEX idx_custom_website_enabled ON custom_websites(isEnabled)',
    );
    await db.execute(
      'CREATE INDEX idx_scan_activities_timestamp ON scan_activities(timestamp)',
    );
    await db.execute(
      'CREATE INDEX idx_price_history_product_date ON price_history(productId, date)',
    );
    await db.execute(
      'CREATE INDEX idx_price_history_date ON price_history(date)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for version 2
      await db.execute(
        'ALTER TABLE matcha_products ADD COLUMN normalizedName TEXT DEFAULT ""',
      );
      await db.execute(
        'ALTER TABLE matcha_products ADD COLUMN isDiscontinued INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE matcha_products ADD COLUMN firstSeen TEXT DEFAULT ""',
      );
      await db.execute(
        'ALTER TABLE matcha_products ADD COLUMN priceValue REAL',
      );
      await db.execute('ALTER TABLE matcha_products ADD COLUMN currency TEXT');
      await db.execute(
        'ALTER TABLE matcha_products ADD COLUMN description TEXT',
      );
      await db.execute('ALTER TABLE matcha_products ADD COLUMN category TEXT');
      await db.execute('ALTER TABLE matcha_products ADD COLUMN weight INTEGER');
      await db.execute('ALTER TABLE matcha_products ADD COLUMN metadata TEXT');

      // Populate normalized names and firstSeen for existing products
      List<Map<String, dynamic>> existingProducts = await db.query(
        'matcha_products',
      );
      for (Map<String, dynamic> product in existingProducts) {
        String normalizedName = MatchaProduct.normalizeName(product['name']);
        String firstSeen =
            product['lastChecked']; // Use lastChecked as fallback

        await db.update(
          'matcha_products',
          {'normalizedName': normalizedName, 'firstSeen': firstSeen},
          where: 'id = ?',
          whereArgs: [product['id']],
        );
      }

      // Create new indexes
      await db.execute('CREATE INDEX idx_site ON matcha_products(site)');
      await db.execute(
        'CREATE INDEX idx_normalized_name ON matcha_products(normalizedName)',
      );
      await db.execute(
        'CREATE INDEX idx_price_value ON matcha_products(priceValue)',
      );
      await db.execute(
        'CREATE INDEX idx_last_checked ON matcha_products(lastChecked)',
      );
      await db.execute(
        'CREATE INDEX idx_discontinued ON matcha_products(isDiscontinued)',
      );
    }

    if (oldVersion < 3) {
      // Add custom websites table for version 3
      await db.execute('''
        CREATE TABLE custom_websites (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          baseUrl TEXT NOT NULL,
          stockSelector TEXT NOT NULL,
          productSelector TEXT NOT NULL,
          nameSelector TEXT NOT NULL,
          priceSelector TEXT NOT NULL,
          linkSelector TEXT NOT NULL,
          isEnabled INTEGER DEFAULT 1,
          createdAt TEXT NOT NULL,
          lastTested TEXT,
          testStatus TEXT
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_custom_website_enabled ON custom_websites(isEnabled)',
      );
    }

    if (oldVersion < 4) {
      // Add missedScans column for version 4
      await db.execute(
        'ALTER TABLE matcha_products ADD COLUMN missedScans INTEGER DEFAULT 0',
      );
    }

    if (oldVersion < 5) {
      // Add favorite_products table for version 5
      await db.execute('''
        CREATE TABLE favorite_products (
          productId TEXT PRIMARY KEY,
          addedAt TEXT NOT NULL,
          FOREIGN KEY (productId) REFERENCES matcha_products (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 6) {
      // Add scan_activities table for version 6
      await db.execute('''
        CREATE TABLE scan_activities (
          id TEXT PRIMARY KEY,
          timestamp TEXT NOT NULL,
          itemsScanned INTEGER NOT NULL,
          duration INTEGER NOT NULL,
          hasStockUpdates INTEGER NOT NULL,
          details TEXT,
          scanType TEXT DEFAULT 'background'
        )
      ''');
      await db.execute(
        'CREATE INDEX idx_scan_activities_timestamp ON scan_activities(timestamp)',
      );
    }

    if (oldVersion < 7) {
      // Add price_history table for version 7
      // Check if table already exists to avoid conflicts
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='price_history'",
      );

      if (tables.isEmpty) {
        await db.execute('''
          CREATE TABLE price_history (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            date TEXT NOT NULL,
            price REAL NOT NULL,
            currency TEXT NOT NULL,
            isInStock INTEGER NOT NULL,
            FOREIGN KEY (productId) REFERENCES matcha_products (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_price_history_product_date ON price_history(productId, date)',
        );
        await db.execute(
          'CREATE INDEX idx_price_history_date ON price_history(date)',
        );
      }
    }
  }

  Future<void> initDatabase() async {
    if (kIsWeb) {
      await WebDatabaseService.instance.initDatabase();
    } else {
      await database;
    }
  }

  Future<void> insertProduct(MatchaProduct product) async {
    final db = await database;
    Map<String, dynamic> productJson = product.toJson();
    // Convert metadata map to JSON string for storage
    if (productJson['metadata'] != null) {
      productJson['metadata'] = productJson['metadata'].toString();
    }
    await db.insert(
      'matcha_products',
      productJson,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateProduct(MatchaProduct product) async {
    final db = await database;
    Map<String, dynamic> productJson = product.toJson();
    // Convert metadata map to JSON string for storage
    if (productJson['metadata'] != null) {
      productJson['metadata'] = productJson['metadata'].toString();
    }
    await db.update(
      'matcha_products',
      productJson,
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> insertOrUpdateProduct(MatchaProduct product) async {
    final existing = await getProduct(product.id);
    if (existing != null) {
      // Update existing product, keeping firstSeen date
      final updatedProduct = product.copyWith(firstSeen: existing.firstSeen);
      await updateProduct(updatedProduct);
    } else {
      await insertProduct(product);
    }
  }

  Future<void> markProductAsDiscontinued(String productId) async {
    final db = await database;
    await db.update(
      'matcha_products',
      {'isDiscontinued': 1},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<List<MatchaProduct>> getAllProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('matcha_products');
    return _mapToProducts(maps);
  }

  Future<PaginatedProducts> getProductsPaginated({
    int page = 1,
    int itemsPerPage = 20,
    ProductFilter? filter,
    String sortBy = 'name',
    bool sortAscending = true,
  }) async {
    final db = await database;

    String whereClause = '1=1';
    List<dynamic> whereArgs = [];
    String joinClause = '';

    if (filter != null) {
      // Handle favorites filter - this requires a JOIN with the favorites table
      if (filter.favoritesOnly) {
        joinClause =
            'INNER JOIN favorite_products f ON matcha_products.id = f.productId';
      }

      // Handle multiple sites filter
      if (filter.sites != null && filter.sites!.isNotEmpty) {
        // Create IN clause for multiple sites
        String sitePlaceholders = filter.sites!.map((_) => '?').join(',');
        whereClause += ' AND site IN ($sitePlaceholders)';
        whereArgs.addAll(filter.sites!);
      }

      if (filter.inStock != null) {
        whereClause += ' AND isInStock = ?';
        whereArgs.add(filter.inStock! ? 1 : 0);
      }

      if (!filter.showDiscontinued) {
        whereClause += ' AND isDiscontinued = 0';
      }

      if (filter.minPrice != null) {
        whereClause += ' AND priceValue >= ?';
        whereArgs.add(filter.minPrice);
      }

      if (filter.maxPrice != null) {
        whereClause += ' AND priceValue <= ?';
        whereArgs.add(filter.maxPrice);
      }

      if (filter.category != null && filter.category!.isNotEmpty) {
        whereClause += ' AND category = ?';
        whereArgs.add(filter.category);
      }

      if (filter.searchTerm != null && filter.searchTerm!.isNotEmpty) {
        whereClause += ' AND (normalizedName LIKE ? OR name LIKE ?)';

        String searchPattern = '%${filter.searchTerm!.toLowerCase()}%';
        whereArgs.add(searchPattern);
        whereArgs.add(searchPattern);
      }
    }

    // Get total count
    String countQuery =
        'SELECT COUNT(*) as count FROM matcha_products $joinClause WHERE $whereClause';
    final countResult = await db.rawQuery(countQuery, whereArgs);
    int totalItems = countResult.first['count'] as int;
    int totalPages = (totalItems / itemsPerPage).ceil();

    print('Database query - WHERE: $whereClause');
    print('Database query - ARGS: $whereArgs');
    print('Database query - Total items found: $totalItems');

    // Get paginated results
    String orderBy =
        'matcha_products.$sortBy ${sortAscending ? 'ASC' : 'DESC'}';
    int offset = (page - 1) * itemsPerPage;

    String selectQuery = '''
      SELECT matcha_products.* FROM matcha_products $joinClause 
      WHERE $whereClause 
      ORDER BY $orderBy 
      LIMIT $itemsPerPage OFFSET $offset
    ''';

    print('Database query - SELECT: $selectQuery');

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      selectQuery,
      whereArgs,
    );

    List<MatchaProduct> products = _mapToProducts(maps);

    return PaginatedProducts(
      products: products,
      currentPage: page,
      totalPages: totalPages,
      totalItems: totalItems,
      itemsPerPage: itemsPerPage,
    );
  }

  List<MatchaProduct> _mapToProducts(List<Map<String, dynamic>> maps) {
    return maps.map((map) {
      // Handle metadata deserialization
      Map<String, dynamic> productMap = Map<String, dynamic>.from(map);
      if (productMap['metadata'] != null && productMap['metadata'] is String) {
        try {
          // In a real app, you'd use proper JSON parsing
          productMap['metadata'] = {}; // Simplified for now
        } catch (e) {
          productMap['metadata'] = null;
        }
      }
      return MatchaProduct.fromJson(productMap);
    }).toList();
  }

  Future<MatchaProduct?> getProduct(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'matcha_products',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _mapToProducts(maps).first;
    }
    return null;
  }

  Future<List<MatchaProduct>> getProductsBySite(String site) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'matcha_products',
      where: 'site = ?',
      whereArgs: [site],
    );
    return _mapToProducts(maps);
  }

  Future<List<String>> getAvailableCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'matcha_products',
      columns: ['DISTINCT category'],
      where: 'category IS NOT NULL',
    );
    return result.map((row) => row['category'] as String).toList();
  }

  Future<Map<String, double>> getPriceRange() async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'matcha_products',
      columns: ['MIN(priceValue) as minPrice', 'MAX(priceValue) as maxPrice'],
      where: 'priceValue IS NOT NULL',
    );

    if (result.isNotEmpty && result.first['minPrice'] != null) {
      return {
        'min': result.first['minPrice'] as double,
        'max': result.first['maxPrice'] as double,
      };
    }
    return {'min': 0.0, 'max': 1000.0};
  }

  Future<StorageInfo> getStorageInfo(int maxStorageMB) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.query(
      'matcha_products',
      columns: ['COUNT(*) as count'],
    );

    int totalProducts = result.first['count'] as int;

    // Calculate approximate size
    // This is a simplified calculation - in real app you'd measure actual DB size
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
      final db = await database;
      // Remove oldest products that are discontinued or out of stock
      await db.delete(
        'matcha_products',
        where: '(isDiscontinued = 1 OR isInStock = 0) AND firstSeen < ?',
        whereArgs: [
          DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        ],
      );
    }
  }

  Future<void> recordStockChange(String productId, bool isInStock) async {
    final db = await database;
    await db.insert('stock_history', {
      'productId': productId,
      'isInStock': isInStock ? 1 : 0,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getStockHistory(String productId) async {
    final db = await database;
    return await db.query(
      'stock_history',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'timestamp DESC',
      limit: 50,
    );
  }

  Future<void> deleteOldHistory() async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    await db.delete(
      'stock_history',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  // Enhanced Stock History Methods
  Future<void> recordStockStatus(String productId, bool isInStock) async {
    final db = await database;
    await db.insert('stock_history', {
      'productId': productId,
      'isInStock': isInStock ? 1 : 0,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<StockHistory>> getStockHistoryForProduct(
    String productId, {
    int? limitDays,
  }) async {
    final db = await database;

    String whereClause = 'productId = ?';
    List<dynamic> whereArgs = [productId];

    if (limitDays != null) {
      final cutoffDate = DateTime.now().subtract(Duration(days: limitDays));
      whereClause += ' AND timestamp >= ?';
      whereArgs.add(cutoffDate.toIso8601String());
    }

    final maps = await db.query(
      'stock_history',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => StockHistory.fromJson(map)).toList();
  }

  Future<StockAnalytics> getStockAnalyticsForProduct(
    String productId, {
    int? limitDays,
  }) async {
    final stockHistory = await getStockHistoryForProduct(
      productId,
      limitDays: limitDays,
    );
    return StockAnalytics.fromHistory(stockHistory);
  }

  Future<List<StockHistory>> getStockHistoryForDay(
    String productId,
    DateTime day,
  ) async {
    final db = await database;
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final maps = await db.query(
      'stock_history',
      where: 'productId = ? AND timestamp >= ? AND timestamp < ?',
      whereArgs: [
        productId,
        dayStart.toIso8601String(),
        dayEnd.toIso8601String(),
      ],
      orderBy: 'timestamp ASC',
    );

    return maps.map((map) => StockHistory.fromJson(map)).toList();
  }

  Future<Map<String, int>> getStockHistoryStats(String productId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT 
        COUNT(*) as totalChecks,
        SUM(CASE WHEN isInStock = 1 THEN 1 ELSE 0 END) as inStockCount,
        SUM(CASE WHEN isInStock = 0 THEN 1 ELSE 0 END) as outOfStockCount,
        MIN(timestamp) as firstCheck,
        MAX(timestamp) as lastCheck
      FROM stock_history
      WHERE productId = ?
    ''',
      [productId],
    );

    if (result.isNotEmpty) {
      final row = result.first;
      return {
        'totalChecks': row['totalChecks'] as int,
        'inStockCount': row['inStockCount'] as int,
        'outOfStockCount': row['outOfStockCount'] as int,
      };
    }

    return {'totalChecks': 0, 'inStockCount': 0, 'outOfStockCount': 0};
  }

  Future<void> deleteStockHistoryForProduct(String productId) async {
    final db = await database;
    await db.delete(
      'stock_history',
      where: 'productId = ?',
      whereArgs: [productId],
    );
  }

  Future<void> clearOldStockHistory({int keepDays = 90}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    await db.delete(
      'stock_history',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  // Custom Website Management Methods
  Future<void> insertCustomWebsite(CustomWebsite website) async {
    final db = await database;
    await db.insert(
      'custom_websites',
      website.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateCustomWebsite(CustomWebsite website) async {
    final db = await database;
    await db.update(
      'custom_websites',
      website.toJson(),
      where: 'id = ?',
      whereArgs: [website.id],
    );
  }

  Future<void> deleteCustomWebsite(String id) async {
    final db = await database;
    await db.delete('custom_websites', where: 'id = ?', whereArgs: [id]);

    // Also delete products from this website
    await db.delete('matcha_products', where: 'site = ?', whereArgs: [id]);
  }

  Future<List<CustomWebsite>> getCustomWebsites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('custom_websites');
    return List.generate(maps.length, (i) {
      return CustomWebsite.fromJson(maps[i]);
    });
  }

  Future<List<CustomWebsite>> getEnabledCustomWebsites() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_websites',
      where: 'isEnabled = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) {
      return CustomWebsite.fromJson(maps[i]);
    });
  }

  Future<CustomWebsite?> getCustomWebsite(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'custom_websites',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return CustomWebsite.fromJson(maps.first);
    }
    return null;
  }

  Future<void> updateWebsiteTestStatus(String id, String status) async {
    final db = await database;
    await db.update(
      'custom_websites',
      {'lastTested': DateTime.now().toIso8601String(), 'testStatus': status},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Favorites management methods
  Future<void> addToFavorites(String productId) async {
    final db = await database;
    await db.insert('favorite_products', {
      'productId': productId,
      'addedAt': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFromFavorites(String productId) async {
    final db = await database;
    await db.delete(
      'favorite_products',
      where: 'productId = ?',
      whereArgs: [productId],
    );
  }

  Future<bool> isFavorite(String productId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorite_products',
      where: 'productId = ?',
      whereArgs: [productId],
    );
    return maps.isNotEmpty;
  }

  Future<List<String>> getFavoriteProductIds() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('favorite_products');
    return maps.map((map) => map['productId'] as String).toList();
  }

  Future<List<MatchaProduct>> getFavoriteProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT p.* FROM matcha_products p
      INNER JOIN favorite_products f ON p.id = f.productId
      ORDER BY f.addedAt DESC
    ''');
    return List.generate(maps.length, (i) {
      return MatchaProduct.fromJson(maps[i]);
    });
  }

  Future<int> getFavoriteProductsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM favorite_products');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Scan activities management methods
  Future<void> insertScanActivity(ScanActivity activity) async {
    final db = await database;
    await db.insert(
      'scan_activities',
      activity.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ScanActivity>> getScanActivities({
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scan_activities',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
    return List.generate(maps.length, (i) {
      return ScanActivity.fromJson(maps[i]);
    });
  }

  Future<int> getScanActivitiesCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM scan_activities');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> deleteScanActivity(String id) async {
    final db = await database;
    await db.delete('scan_activities', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearOldScanActivities({int keepDays = 30}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    await db.delete(
      'scan_activities',
      where: 'timestamp < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  Future<void> clearAllScanActivities() async {
    final db = await database;
    await db.delete('scan_activities');
  }

  Future<List<Map<String, dynamic>>> getStockUpdatesForScan(
    String scanActivityId,
  ) async {
    final db = await database;

    // Find the scan timestamp for the given scanActivityId
    final scanActivity = await db.query(
      'scan_activities',
      where: 'id = ?',
      whereArgs: [scanActivityId],
      limit: 1,
    );
    if (scanActivity.isEmpty) return [];

    final scanTimestamp = DateTime.parse(
      scanActivity.first['timestamp'] as String,
    );
    final start =
        scanTimestamp.subtract(const Duration(minutes: 1)).toIso8601String();
    final end = scanTimestamp.add(const Duration(minutes: 1)).toIso8601String();

    // Get all stock_history entries for products checked at this scan timestamp
    final updates = await db.rawQuery(
      '''
    SELECT 
      sh.productId, 
      sh.isInStock, 
      sh.timestamp, 
      p.name, p.site, p.url, p.price, p.priceValue, p.currency, p.imageUrl, p.description, p.category, p.weight, p.metadata,
      (
        SELECT prev.isInStock
        FROM stock_history prev
        WHERE prev.productId = sh.productId AND prev.timestamp < sh.timestamp
        ORDER BY prev.timestamp DESC
        LIMIT 1
      ) as previousIsInStock
    FROM stock_history sh
    LEFT JOIN matcha_products p ON sh.productId = p.id
    WHERE sh.timestamp BETWEEN ? AND ?
    ORDER BY sh.productId ASC
  ''',
      [start, end],
    );

    return updates;
  }

  // Price History Methods
  Future<void> insertPriceHistory(PriceHistory priceHistory) async {
    final db = await database;
    await db.insert(
      'price_history',
      priceHistory.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> savePriceForProduct(MatchaProduct product) async {
    if (product.priceValue == null || product.priceValue! <= 0) {
      return; // Don't save invalid prices
    }

    final now = DateTime.now();
    final dailyKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // Check if we already have a price for today
    final db = await database;
    final existing = await db.query(
      'price_history',
      where: 'productId = ? AND date LIKE ?',
      whereArgs: [product.id, '$dailyKey%'],
      orderBy: 'price ASC',
      limit: 1,
    );

    final newPrice = PriceHistory(
      id: '${product.id}_${now.millisecondsSinceEpoch}',
      productId: product.id,
      date: now,
      price: product.priceValue!,
      currency: product.currency ?? 'EUR',
      isInStock: product.isInStock,
    );

    if (existing.isNotEmpty) {
      // Only save if this price is lower than the existing one for today
      final existingPrice = existing.first['price'] as double;
      if (product.priceValue! < existingPrice) {
        // Delete the existing entry and insert the new lower price
        await db.delete(
          'price_history',
          where: 'productId = ? AND date LIKE ?',
          whereArgs: [product.id, '$dailyKey%'],
        );
        await insertPriceHistory(newPrice);
      }
    } else {
      // No price for today, insert the new one
      await insertPriceHistory(newPrice);
    }
  }

  Future<List<PriceHistory>> getPriceHistoryForProduct(String productId) async {
    final db = await database;
    final maps = await db.query(
      'price_history',
      where: 'productId = ?',
      whereArgs: [productId],
      orderBy: 'date ASC',
    );
    return maps.map((map) => PriceHistory.fromJson(map)).toList();
  }

  Future<PriceAnalytics> getPriceAnalyticsForProduct(String productId) async {
    final priceHistory = await getPriceHistoryForProduct(productId);
    return PriceAnalytics.fromHistory(priceHistory);
  }

  Future<void> deletePriceHistoryForProduct(String productId) async {
    final db = await database;
    await db.delete(
      'price_history',
      where: 'productId = ?',
      whereArgs: [productId],
    );
  }

  Future<void> clearOldPriceHistory({int keepDays = 365}) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    await db.delete(
      'price_history',
      where: 'date < ?',
      whereArgs: [cutoffDate.toIso8601String()],
    );
  }

  Future<Map<String, int>> getPriceHistoryStats() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as totalEntries,
        COUNT(DISTINCT productId) as trackedProducts,
        MIN(date) as oldestEntry,
        MAX(date) as newestEntry
      FROM price_history
    ''');

    if (result.isNotEmpty) {
      return {
        'totalEntries': result.first['totalEntries'] as int,
        'trackedProducts': result.first['trackedProducts'] as int,
      };
    }

    return {'totalEntries': 0, 'trackedProducts': 0};
  }
}

/// Platform-aware database service that automatically chooses between local and server modes
class _PlatformDatabaseService {
  Future<bool> _isServerMode() async {
    final prefs = await SharedPreferences.getInstance();
    final appMode = prefs.getString('appMode') ?? 'local';
    return appMode == 'server';
  }

  Future<PaginatedProducts> getProductsPaginated({
    int page = 1,
    int itemsPerPage = 20,
    ProductFilter? filter,
    String sortBy = 'name',
    bool sortAscending = true,
  }) async {
    if (await _isServerMode()) {
      // Use Firestore for server mode
      await FirestoreService.instance.initDatabase();
      return await FirestoreService.instance.getProductsPaginated(
        page: page,
        itemsPerPage: itemsPerPage,
        filter: filter,
        sortBy: sortBy,
        sortAscending: sortAscending,
      );
    } else {
      // Use local database for local mode
      if (kIsWeb) {
        return await WebDatabaseService.instance.getProductsPaginated(
          page: page,
          itemsPerPage: itemsPerPage,
          filter: filter,
          sortBy: sortBy,
          sortAscending: sortAscending,
        );
      } else {
        return await DatabaseService.instance.getProductsPaginated(
          page: page,
          itemsPerPage: itemsPerPage,
          filter: filter,
          sortBy: sortBy,
          sortAscending: sortAscending,
        );
      }
    }
  }

  Future<List<MatchaProduct>> getAllProducts({ProductFilter? filter}) async {
    if (await _isServerMode()) {
      // Use Firestore for server mode
      await FirestoreService.instance.initDatabase();
      return await FirestoreService.instance.getAllProducts(filter: filter);
    } else {
      // Use local database for local mode
      if (kIsWeb) {
        return await WebDatabaseService.instance.getAllProducts();
      } else {
        return await DatabaseService.instance.getAllProducts();
      }
    }
  }

  Future<List<MatchaProduct>> getProductsBySite(String site) async {
    if (await _isServerMode()) {
      // Use Firestore for server mode
      await FirestoreService.instance.initDatabase();
      return await FirestoreService.instance.getProductsBySite(site);
    } else {
      // Use local database for local mode
      if (kIsWeb) {
        return await WebDatabaseService.instance.getProductsBySite(site);
      } else {
        return await DatabaseService.instance.getProductsBySite(site);
      }
    }
  }

  Future<MatchaProduct?> getProduct(String id) async {
    if (await _isServerMode()) {
      // Use Firestore for server mode
      await FirestoreService.instance.initDatabase();
      return await FirestoreService.instance.getProductById(id);
    } else {
      // Use local database for local mode
      if (kIsWeb) {
        return await WebDatabaseService.instance.getProduct(id);
      } else {
        return await DatabaseService.instance.getProduct(id);
      }
    }
  }

  Future<List<String>> getAvailableCategories() async {
    if (await _isServerMode()) {
      // Use Firestore for server mode
      await FirestoreService.instance.initDatabase();
      return await FirestoreService.instance.getUniqueCategories();
    } else {
      // Use local database for local mode
      if (kIsWeb) {
        return await WebDatabaseService.instance.getAvailableCategories();
      } else {
        return await DatabaseService.instance.getAvailableCategories();
      }
    }
  }

  Future<List<String>> getUniqueSites() async {
    if (await _isServerMode()) {
      // Use Firestore for server mode
      await FirestoreService.instance.initDatabase();
      return await FirestoreService.instance.getUniqueSites();
    } else {
      // Use local database for local mode - these services don't have getUniqueSites, so we'll extract from products
      final products = await getAllProducts();
      final sites = products.map((p) => p.site).toSet().toList();
      sites.sort();
      return sites;
    }
  }

  // For server mode, these methods will only work locally as Firestore doesn't store favorites locally
  Future<bool> isFavorite(String productId) async {
    // Favorites are always stored locally regardless of mode
    if (kIsWeb) {
      return await WebDatabaseService.instance.isFavorite(productId);
    } else {
      return await DatabaseService.instance.isFavorite(productId);
    }
  }

  Future<void> addToFavorites(String productId) async {
    // Favorites are always stored locally regardless of mode
    if (kIsWeb) {
      await WebDatabaseService.instance.addToFavorites(productId);
    } else {
      await DatabaseService.instance.addToFavorites(productId);
    }
  }

  Future<void> removeFromFavorites(String productId) async {
    // Favorites are always stored locally regardless of mode
    if (kIsWeb) {
      await WebDatabaseService.instance.removeFromFavorites(productId);
    } else {
      await DatabaseService.instance.removeFromFavorites(productId);
    }
  }

  Future<List<String>> getFavoriteProductIds() async {
    // Favorites are always stored locally regardless of mode
    if (kIsWeb) {
      return await WebDatabaseService.instance.getFavoriteProductIds();
    } else {
      return await DatabaseService.instance.getFavoriteProductIds();
    }
  }

  // Delegate other methods to local database service
  Future<void> initDatabase() async {
    if (kIsWeb) {
      await WebDatabaseService.instance.initDatabase();
    } else {
      await DatabaseService.instance.initDatabase();
    }

    // Also initialize Firestore if in server mode
    if (await _isServerMode()) {
      await FirestoreService.instance.initDatabase();
    }
  }
}
