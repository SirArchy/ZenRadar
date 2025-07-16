class MatchaProduct {
  final String id;
  final String name;
  final String normalizedName; // For better search/grouping
  final String site;
  final String url;
  final bool isInStock;
  final bool isDiscontinued; // New field for discontinued products
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
    required this.url,
    required this.isInStock,
    this.isDiscontinued = false,
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
      url: json['url'],
      isInStock: json['isInStock'] == 1,
      isDiscontinued: json['isDiscontinued'] == 1,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'normalizedName': normalizedName,
      'site': site,
      'url': url,
      'isInStock': isInStock ? 1 : 0,
      'isDiscontinued': isDiscontinued ? 1 : 0,
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
      category: category,
      weight: weight,
      metadata: metadata,
    );
  }
}

class UserSettings {
  final int checkFrequencyHours;
  final String startTime; // "08:00"
  final String endTime; // "20:00"
  final bool notificationsEnabled;
  final bool headModeEnabled; // Show crawler activity
  final List<String> enabledSites;
  final int itemsPerPage; // Pagination
  final int maxStorageMB; // Storage limit in MB
  final bool showOutOfStock; // Show/hide out of stock items
  final String sortBy; // "name", "price", "lastChecked", "site"
  final bool sortAscending;

  UserSettings({
    this.checkFrequencyHours = 6,
    this.startTime = "08:00",
    this.endTime = "20:00",
    this.notificationsEnabled = true,
    this.headModeEnabled = false,
    this.enabledSites = const ["tokichi", "marukyu", "ippodo"],
    this.itemsPerPage = 20,
    this.maxStorageMB = 100,
    this.showOutOfStock = true,
    this.sortBy = "name",
    this.sortAscending = true,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      checkFrequencyHours: json['checkFrequencyHours'] ?? 6,
      startTime: json['startTime'] ?? "08:00",
      endTime: json['endTime'] ?? "20:00",
      notificationsEnabled: json['notificationsEnabled'] ?? true,
      headModeEnabled: json['headModeEnabled'] ?? false,
      enabledSites: List<String>.from(
        json['enabledSites'] ?? ["tokichi", "marukyu", "ippodo"],
      ),
      itemsPerPage: json['itemsPerPage'] ?? 20,
      maxStorageMB: json['maxStorageMB'] ?? 100,
      showOutOfStock: json['showOutOfStock'] ?? true,
      sortBy: json['sortBy'] ?? "name",
      sortAscending: json['sortAscending'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'checkFrequencyHours': checkFrequencyHours,
      'startTime': startTime,
      'endTime': endTime,
      'notificationsEnabled': notificationsEnabled,
      'headModeEnabled': headModeEnabled,
      'enabledSites': enabledSites,
      'itemsPerPage': itemsPerPage,
      'maxStorageMB': maxStorageMB,
      'showOutOfStock': showOutOfStock,
      'sortBy': sortBy,
      'sortAscending': sortAscending,
    };
  }

  UserSettings copyWith({
    int? checkFrequencyHours,
    String? startTime,
    String? endTime,
    bool? notificationsEnabled,
    bool? headModeEnabled,
    List<String>? enabledSites,
    int? itemsPerPage,
    int? maxStorageMB,
    bool? showOutOfStock,
    String? sortBy,
    bool? sortAscending,
  }) {
    return UserSettings(
      checkFrequencyHours: checkFrequencyHours ?? this.checkFrequencyHours,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      headModeEnabled: headModeEnabled ?? this.headModeEnabled,
      enabledSites: enabledSites ?? this.enabledSites,
      itemsPerPage: itemsPerPage ?? this.itemsPerPage,
      maxStorageMB: maxStorageMB ?? this.maxStorageMB,
      showOutOfStock: showOutOfStock ?? this.showOutOfStock,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}

class ProductFilter {
  final String? site;
  final bool? inStock;
  final double? minPrice;
  final double? maxPrice;
  final String? category;
  final String? searchTerm;
  final bool showDiscontinued;

  ProductFilter({
    this.site,
    this.inStock,
    this.minPrice,
    this.maxPrice,
    this.category,
    this.searchTerm,
    this.showDiscontinued = false,
  });

  ProductFilter copyWith({
    String? site,
    bool? inStock,
    double? minPrice,
    double? maxPrice,
    String? category,
    String? searchTerm,
    bool? showDiscontinued,
  }) {
    return ProductFilter(
      site: site ?? this.site,
      inStock: inStock ?? this.inStock,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      category: category ?? this.category,
      searchTerm: searchTerm ?? this.searchTerm,
      showDiscontinued: showDiscontinued ?? this.showDiscontinued,
    );
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
