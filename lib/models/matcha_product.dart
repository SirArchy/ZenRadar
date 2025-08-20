class MatchaProduct {
  final String id;
  final String name;
  final String normalizedName; // For better search/grouping
  final String site;
  final String? siteName; // Human-readable site name
  final String url;
  final bool isInStock;
  final bool isDiscontinued; // New field for discontinued products
  final int missedScans; // Track consecutive scans where product wasn't found
  final DateTime lastChecked;
  final DateTime firstSeen; // When product was first discovered
  final String? price;
  final double? priceValue; // Numeric price for filtering
  final String? currency;
  final String? imageUrl;
  final String? description;
  final String? category; // e.g., "ceremonial", "premium", "cooking"
  final int? weight; // in grams
  final Map<String, dynamic>? metadata; // Additional site-specific data

  MatchaProduct({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.site,
    this.siteName,
    required this.url,
    required this.isInStock,
    this.isDiscontinued = false,
    this.missedScans = 0,
    required this.lastChecked,
    required this.firstSeen,
    this.price,
    this.priceValue,
    this.currency,
    this.imageUrl,
    this.description,
    this.category,
    this.weight,
    this.metadata,
  });

  factory MatchaProduct.fromJson(Map<String, dynamic> json) {
    return MatchaProduct(
      id: json['id'],
      name: json['name'],
      normalizedName:
          json['normalizedName'] ?? MatchaProduct.normalizeName(json['name']),
      site: json['site'],
      siteName: json['siteName'],
      url: json['url'],
      isInStock: json['isInStock'] == 1,
      isDiscontinued: json['isDiscontinued'] == 1,
      missedScans: json['missedScans'] ?? 0,
      lastChecked: DateTime.parse(json['lastChecked']),
      firstSeen:
          json['firstSeen'] != null
              ? DateTime.parse(json['firstSeen'])
              : DateTime.parse(
                json['lastChecked'],
              ), // Fallback for existing data
      price: json['price'],
      priceValue: json['priceValue']?.toDouble(),
      currency: json['currency'],
      imageUrl: json['imageUrl'],
      description: json['description'],
      category: json['category'],
      weight: json['weight'],
      metadata:
          json['metadata'] != null
              ? Map<String, dynamic>.from(json['metadata'])
              : null,
    );
  }

  // Factory for Firestore data (for server mode)
  factory MatchaProduct.fromFirestore(String id, Map<String, dynamic> data) {
    return MatchaProduct(
      id: id,
      name: data['name'] ?? '',
      normalizedName:
          data['normalizedName'] ??
          MatchaProduct.normalizeName(data['name'] ?? ''),
      site: data['site'] ?? '',
      siteName: data['siteName'],
      url: data['url'] ?? '',
      isInStock: data['isInStock'] ?? false,
      isDiscontinued: data['isDiscontinued'] ?? false,
      missedScans: data['missedScans'] ?? 0,
      lastChecked:
          data['lastChecked'] != null
              ? (data['lastChecked'] as dynamic).toDate()
              : DateTime.now(),
      firstSeen:
          data['firstSeen'] != null
              ? (data['firstSeen'] as dynamic).toDate()
              : DateTime.now(),
      price: data['price'],
      priceValue: data['priceValue']?.toDouble(),
      currency: data['currency'],
      imageUrl: data['imageUrl'],
      description: data['description'],
      category: data['category'],
      weight: data['weight'],
      metadata:
          data['metadata'] != null
              ? Map<String, dynamic>.from(data['metadata'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'normalizedName': normalizedName,
      'site': site,
      'siteName': siteName,
      'url': url,
      'isInStock': isInStock ? 1 : 0,
      'isDiscontinued': isDiscontinued ? 1 : 0,
      'missedScans': missedScans,
      'lastChecked': lastChecked.toIso8601String(),
      'firstSeen': firstSeen.toIso8601String(),
      'price': price,
      'priceValue': priceValue,
      'currency': currency,
      'imageUrl': imageUrl,
      'description': description,
      'category': category,
      'weight': weight,
      'metadata': metadata,
    };
  }

  MatchaProduct copyWith({
    String? id,
    String? name,
    String? normalizedName,
    String? site,
    String? url,
    bool? isInStock,
    bool? isDiscontinued,
    int? missedScans,
    DateTime? lastChecked,
    DateTime? firstSeen,
    String? price,
    double? priceValue,
    String? currency,
    String? imageUrl,
    String? description,
    String? category,
    int? weight,
    Map<String, dynamic>? metadata,
  }) {
    return MatchaProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      site: site ?? this.site,
      url: url ?? this.url,
      isInStock: isInStock ?? this.isInStock,
      isDiscontinued: isDiscontinued ?? this.isDiscontinued,
      missedScans: missedScans ?? this.missedScans,
      lastChecked: lastChecked ?? this.lastChecked,
      firstSeen: firstSeen ?? this.firstSeen,
      price: price ?? this.price,
      priceValue: priceValue ?? this.priceValue,
      currency: currency ?? this.currency,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      category: category ?? this.category,
      weight: weight ?? this.weight,
      metadata: metadata ?? this.metadata,
    );
  }

  // Calculate approximate storage size in bytes
  int get approximateSize {
    int size = 0;
    size += id.length * 2; // UTF-16 encoding
    size += name.length * 2;
    size += normalizedName.length * 2;
    size += site.length * 2;
    size += url.length * 2;
    size += 50; // booleans, DateTime, numbers
    size += (price?.length ?? 0) * 2;
    size += (currency?.length ?? 0) * 2;
    size += (imageUrl?.length ?? 0) * 2;
    size += (description?.length ?? 0) * 2;
    size += (category?.length ?? 0) * 2;
    size += (metadata?.toString().length ?? 0) * 2;
    return size;
  }

  // Static method for name normalization
  static String normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  // Static method for automatic category detection
  static String detectCategory(String name, String site) {
    final String lower = name.toLowerCase();

    // Check for accessories first (most specific)
    if (lower.contains('whisk') ||
        lower.contains('bowl') ||
        lower.contains('chawan') ||
        lower.contains('chasen') ||
        lower.contains('chashaku') ||
        lower.contains('halter') ||
        lower.contains('teetasse') ||
        lower.contains('teetassen') ||
        lower.contains('teebecher') ||
        lower.contains('tea pot') ||
        lower.contains('teapot') ||
        lower.contains('pot') ||
        lower.contains('glass') ||
        lower.contains('glas') || // German spelling
        lower.contains('besen') ||
        lower.contains('geschenkgutschein') ||
        lower.contains('gutschein') ||
        lower.contains('schale') ||
        lower.contains('spoon') ||
        lower.contains('löffel') ||
        lower.contains('bamboo') ||
        lower.contains('scoop') ||
        lower.contains('sifter') ||
        lower.contains('strainer') ||
        lower.contains('accessory') ||
        lower.contains('tool')) {
      return 'Accessories';
    }

    // Check for tea sets (also specific)
    if (lower.contains('set') ||
        lower.contains('kit') ||
        lower.contains('collection')) {
      return 'Tea Set';
    }

    // Other tea types (before matcha to catch specific teas)
    if (lower.contains('genmaicha')) {
      return 'Genmaicha';
    }

    if (lower.contains('hojicha')) {
      return 'Hojicha';
    }

    if (lower.contains('black tea') ||
        lower.contains('earl grey') ||
        lower.contains('assam') ||
        lower.contains('darjeeling') ||
        lower.contains('ceylon') ||
        lower.contains('english breakfast')) {
      return 'Black Tea';
    }

    // Matcha - check last since it's most common
    if (lower.contains('matcha')) {
      return 'Matcha';
    }

    // Default category - if it's from a matcha-focused site, assume matcha
    final String lowerSite = site.toLowerCase();
    if (lowerSite.contains('matcha') ||
        lowerSite.contains('tea') ||
        lowerSite.contains('zen')) {
      return 'Matcha';
    }

    return 'Matcha'; // Default fallback
  }

  // Helper factory method
  factory MatchaProduct.create({
    required String name,
    required String site,
    required String url,
    required bool isInStock,
    String? price,
    double? priceValue,
    String? currency,
    String? imageUrl,
    String? description,
    String? category,
    int? weight,
    Map<String, dynamic>? metadata,
  }) {
    final now = DateTime.now();
    // Auto-detect category if not provided
    final String detectedCategory = category ?? detectCategory(name, site);

    return MatchaProduct(
      id:
          '${site}_${normalizeName(name).replaceAll(' ', '_')}_${now.millisecondsSinceEpoch}',
      name: name,
      normalizedName: normalizeName(name),
      site: site,
      url: url,
      isInStock: isInStock,
      lastChecked: now,
      firstSeen: now,
      price: price,
      priceValue: priceValue,
      currency: currency,
      imageUrl: imageUrl,
      description: description,
      category: detectedCategory,
      weight: weight,
      metadata: metadata,
    );
  }
}

class UserSettings {
  final int checkFrequencyMinutes; // Changed from hours to minutes
  final String startTime; // "08:00"
  final String endTime; // "20:00"
  final bool notificationsEnabled;
  final List<String> enabledSites;
  final int itemsPerPage; // Pagination
  final int maxStorageMB; // Storage limit in MB
  final String sortBy; // "name", "price", "lastChecked", "site"
  final bool sortAscending;
  final String preferredCurrency; // "EUR", "USD", "JPY", etc.
  final bool
  backgroundScanFavoritesOnly; // New setting for background scan mode
  final String
  appMode; // "local" or "server" - determines data source and crawler mode

  UserSettings({
    this.checkFrequencyMinutes = 360, // Default 6 hours = 360 minutes
    this.startTime = "08:00",
    this.endTime = "20:00",
    this.notificationsEnabled = true,
    this.enabledSites = const [
      "tokichi",
      "marukyu",
      "ippodo",
      "yoshien",
      "matcha-karu",
      "sho-cha",
      "sazentea",
      "enjoyemeri",
      "poppatea",
      "horiishichimeien",
    ],
    this.itemsPerPage = 20,
    this.maxStorageMB = 100,
    this.sortBy = "name",
    this.sortAscending = true,
    this.preferredCurrency = "EUR",
    this.backgroundScanFavoritesOnly = false, // Default: scan all products
    this.appMode = "local", // Default: local mode for existing users
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      checkFrequencyMinutes:
          json['checkFrequencyMinutes'] ??
          (json['checkFrequencyHours'] != null
              ? json['checkFrequencyHours'] * 60
              : 360), // Migration support
      startTime: json['startTime'] ?? "08:00",
      endTime: json['endTime'] ?? "20:00",
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      enabledSites: List<String>.from(
        json['enabledSites'] ??
            [
              "tokichi",
              "marukyu",
              "ippodo",
              "yoshien",
              "matcha-karu",
              "sho-cha",
              "sazentea",
              "enjoyemeri",
              "poppatea",
              "horiishichimeien",
            ],
      ),
      itemsPerPage: json['itemsPerPage'] ?? 20,
      maxStorageMB: json['maxStorageMB'] ?? 100,
      sortBy: json['sortBy'] ?? "name",
      sortAscending: json['sortAscending'] ?? true,
      preferredCurrency: json['preferredCurrency'] ?? "EUR",
      backgroundScanFavoritesOnly: json['backgroundScanFavoritesOnly'] ?? false,
      appMode: json['appMode'] ?? "local", // Default to local for migration
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'checkFrequencyMinutes': checkFrequencyMinutes,
      'startTime': startTime,
      'endTime': endTime,
      'notificationsEnabled': notificationsEnabled,
      'enabledSites': enabledSites,
      'itemsPerPage': itemsPerPage,
      'maxStorageMB': maxStorageMB,
      'sortBy': sortBy,
      'sortAscending': sortAscending,
      'preferredCurrency': preferredCurrency,
      'backgroundScanFavoritesOnly': backgroundScanFavoritesOnly,
      'appMode': appMode,
    };
  }

  UserSettings copyWith({
    int? checkFrequencyMinutes,
    String? startTime,
    String? endTime,
    bool? notificationsEnabled,
    List<String>? enabledSites,
    int? itemsPerPage,
    int? maxStorageMB,
    String? sortBy,
    bool? sortAscending,
    String? preferredCurrency,
    bool? backgroundScanFavoritesOnly,
    String? appMode,
  }) {
    return UserSettings(
      checkFrequencyMinutes:
          checkFrequencyMinutes ?? this.checkFrequencyMinutes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      enabledSites: enabledSites ?? this.enabledSites,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      maxStorageMB: maxStorageMB ?? this.maxStorageMB,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
      preferredCurrency: preferredCurrency ?? this.preferredCurrency,
      backgroundScanFavoritesOnly:
          backgroundScanFavoritesOnly ?? this.backgroundScanFavoritesOnly,
      appMode: appMode ?? this.appMode,
    );
  }
}

class ProductFilter {
  final List<String>? sites; // Changed from single site to multiple sites
  final bool? inStock;
  final double? minPrice;
  final double? maxPrice;
  final String? category;
  final String? searchTerm;
  final bool showDiscontinued;
  final bool favoritesOnly;

  ProductFilter({
    this.sites,
    this.inStock,
    this.minPrice,
    this.maxPrice,
    this.category,
    this.searchTerm,
    this.showDiscontinued = false,
    this.favoritesOnly = false,
  });

  ProductFilter copyWith({
    List<String>? sites,
    bool? inStock,
    double? minPrice,
    double? maxPrice,
    String? category,
    String? searchTerm,
    bool? showDiscontinued,
    bool? favoritesOnly,
  }) {
    return ProductFilter(
      sites: sites ?? this.sites,
      inStock: inStock ?? this.inStock,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      category: category ?? this.category,
      searchTerm: searchTerm ?? this.searchTerm,
      showDiscontinued: showDiscontinued ?? this.showDiscontinued,
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    );
  }

  @override
  String toString() {
    return 'ProductFilter(sites: $sites, inStock: $inStock, minPrice: $minPrice, maxPrice: $maxPrice, category: $category, searchTerm: $searchTerm, showDiscontinued: $showDiscontinued, favoritesOnly: $favoritesOnly)';
  }
}

class PaginatedProducts {
  final List<MatchaProduct> products;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;

  PaginatedProducts({
    required this.products,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
  });
}

class StorageInfo {
  final int totalProducts;
  final int totalSizeBytes;
  final int maxSizeBytes;
  final double usagePercentage;

  StorageInfo({
    required this.totalProducts,
    required this.totalSizeBytes,
    required this.maxSizeBytes,
  }) : usagePercentage =
           maxSizeBytes > 0 ? (totalSizeBytes / maxSizeBytes) * 100 : 0;

  String get formattedSize => _formatBytes(totalSizeBytes);
  String get formattedMaxSize => _formatBytes(maxSizeBytes);

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }
}

class CustomWebsite {
  final String id;
  final String name;
  final String baseUrl;
  final String stockSelector;
  final String productSelector;
  final String nameSelector;
  final String priceSelector;
  final String linkSelector;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime? lastTested;
  final String? testStatus;

  CustomWebsite({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.stockSelector,
    required this.productSelector,
    required this.nameSelector,
    required this.priceSelector,
    required this.linkSelector,
    this.isEnabled = true,
    required this.createdAt,
    this.lastTested,
    this.testStatus,
  });

  factory CustomWebsite.fromJson(Map<String, dynamic> json) {
    return CustomWebsite(
      id: json['id'],
      name: json['name'],
      baseUrl: json['baseUrl'],
      stockSelector: json['stockSelector'],
      productSelector: json['productSelector'],
      nameSelector: json['nameSelector'],
      priceSelector: json['priceSelector'],
      linkSelector: json['linkSelector'],
      isEnabled: json['isEnabled'] == 1,
      createdAt: DateTime.parse(json['createdAt']),
      lastTested:
          json['lastTested'] != null
              ? DateTime.parse(json['lastTested'])
              : null,
      testStatus: json['testStatus'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'stockSelector': stockSelector,
      'productSelector': productSelector,
      'nameSelector': nameSelector,
      'priceSelector': priceSelector,
      'linkSelector': linkSelector,
      'isEnabled': isEnabled ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'lastTested': lastTested?.toIso8601String(),
      'testStatus': testStatus,
    };
  }

  CustomWebsite copyWith({
    String? id,
    String? name,
    String? baseUrl,
    String? stockSelector,
    String? productSelector,
    String? nameSelector,
    String? priceSelector,
    String? linkSelector,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? lastTested,
    String? testStatus,
  }) {
    return CustomWebsite(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      stockSelector: stockSelector ?? this.stockSelector,
      productSelector: productSelector ?? this.productSelector,
      nameSelector: nameSelector ?? this.nameSelector,
      priceSelector: priceSelector ?? this.priceSelector,
      linkSelector: linkSelector ?? this.linkSelector,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastTested: lastTested ?? this.lastTested,
      testStatus: testStatus ?? this.testStatus,
    );
  }
}
