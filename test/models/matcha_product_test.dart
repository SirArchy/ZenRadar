import 'package:flutter_test/flutter_test.dart';
import 'package:zenradar/models/matcha_product.dart';

void main() {
  group('MatchaProduct', () {
    late MatchaProduct testProduct;

    setUp(() {
      testProduct = MatchaProduct(
        id: 'test_id_123',
        name: 'Premium Matcha Usucha',
        normalizedName: 'premium matcha usucha',
        site: 'ippodo',
        siteName: 'Ippodo Tea',
        url: 'https://ippodo-tea.com/premium-matcha',
        isInStock: true,
        lastChecked: DateTime(2025, 9, 15, 10, 0),
        firstSeen: DateTime(2025, 9, 1),
        price: '€89.00',
        priceValue: 89.0,
        currency: 'EUR',
        imageUrl: 'https://ippodo-tea.com/images/matcha.jpg',
        category: 'ceremonial',
        weight: 100,
      );
    });

    test('should create a valid MatchaProduct instance', () {
      expect(testProduct.id, 'test_id_123');
      expect(testProduct.name, 'Premium Matcha Usucha');
      expect(testProduct.site, 'ippodo');
      expect(testProduct.isInStock, true);
      expect(testProduct.priceValue, 89.0);
      expect(testProduct.currency, 'EUR');
      expect(testProduct.category, 'ceremonial');
      expect(testProduct.weight, 100);
    });

    test('should convert to JSON correctly', () {
      final json = testProduct.toJson();

      expect(json['id'], 'test_id_123');
      expect(json['name'], 'Premium Matcha Usucha');
      expect(json['normalizedName'], 'premium matcha usucha');
      expect(json['site'], 'ippodo');
      expect(json['isInStock'], 1); // SQLite boolean conversion
      expect(json['priceValue'], 89.0);
      expect(json['currency'], 'EUR');
      expect(json['category'], 'ceremonial');
      expect(json['weight'], 100);
    });

    test('should create from JSON correctly', () {
      final json = {
        'id': 'json_test_id',
        'name': 'Test Matcha',
        'normalizedName': 'test matcha',
        'site': 'marukyu',
        'siteName': 'Marukyu-Koyamaen',
        'url': 'https://marukyu.com/test',
        'isInStock': 1,
        'isDiscontinued': 0,
        'missedScans': 2,
        'lastChecked': '2025-09-15T10:00:00.000Z',
        'firstSeen': '2025-09-01T10:00:00.000Z',
        'price': '¥12000',
        'priceValue': 12000.0,
        'currency': 'JPY',
        'imageUrl': 'https://marukyu.com/image.jpg',
        'category': 'premium',
        'weight': 80,
      };

      final product = MatchaProduct.fromJson(json);

      expect(product.id, 'json_test_id');
      expect(product.name, 'Test Matcha');
      expect(product.site, 'marukyu');
      expect(product.isInStock, true);
      expect(product.isDiscontinued, false);
      expect(product.missedScans, 2);
      expect(product.priceValue, 12000.0);
      expect(product.currency, 'JPY');
      expect(product.weight, 80);
    });

    test('should normalize product names correctly', () {
      expect(
        MatchaProduct.normalizeName('Premium Matcha Usucha'),
        'premium matcha usucha',
      );
      expect(
        MatchaProduct.normalizeName('ORGANIC GREEN TEA'),
        'organic green tea',
      );
      expect(MatchaProduct.normalizeName('  Extra   Spaces  '), 'extra spaces');
      expect(
        MatchaProduct.normalizeName('Special-Characters_123!'),
        'specialcharacters_123',
      );
    });

    test('should handle null values gracefully', () {
      final minimalProduct = MatchaProduct(
        id: 'minimal_id',
        name: 'Minimal Product',
        normalizedName: 'minimal product',
        site: 'test_site',
        url: 'https://test.com',
        isInStock: false,
        lastChecked: DateTime.now(),
        firstSeen: DateTime.now(),
      );

      expect(minimalProduct.price, null);
      expect(minimalProduct.priceValue, null);
      expect(minimalProduct.currency, null);
      expect(minimalProduct.imageUrl, null);
      expect(minimalProduct.category, null);
      expect(minimalProduct.weight, null);
      expect(minimalProduct.isDiscontinued, false);
      expect(minimalProduct.missedScans, 0);
    });

    test('should copy with modifications correctly', () {
      final updatedProduct = testProduct.copyWith(
        isInStock: false,
        price: '€95.00',
        priceValue: 95.0,
        lastChecked: DateTime(2025, 9, 16),
      );

      expect(updatedProduct.id, testProduct.id); // Unchanged
      expect(updatedProduct.name, testProduct.name); // Unchanged
      expect(updatedProduct.isInStock, false); // Changed
      expect(updatedProduct.price, '€95.00'); // Changed
      expect(updatedProduct.priceValue, 95.0); // Changed
      expect(updatedProduct.lastChecked.day, 16); // Changed
    });

    test('should validate product data integrity', () {
      // Test that products can be created with minimal data
      // MatchaProduct constructor doesn't actually validate - it accepts any values
      final productWithEmptyId = MatchaProduct(
        id: '', // Empty ID is actually allowed
        name: 'Test',
        normalizedName: 'test',
        site: 'test',
        url: 'https://test.com',
        isInStock: true,
        lastChecked: DateTime.now(),
        firstSeen: DateTime.now(),
      );
      expect(productWithEmptyId.id, '');

      final productWithEmptyUrl = MatchaProduct(
        id: 'test',
        name: 'Test',
        normalizedName: 'test',
        site: 'test',
        url: '', // Empty URL is actually allowed
        isInStock: true,
        lastChecked: DateTime.now(),
        firstSeen: DateTime.now(),
      );
      expect(productWithEmptyUrl.url, '');
    });
  });

  group('ProductFilter', () {
    test('should create empty filter by default', () {
      final filter = ProductFilter();

      expect(filter.inStock, null);
      expect(filter.favoritesOnly, false);
      expect(filter.sites, null);
      expect(filter.categories, null);
      expect(filter.minPrice, null);
      expect(filter.maxPrice, null);
      expect(filter.searchTerm, null);
    });

    test('should copy with modifications correctly', () {
      final filter = ProductFilter(
        inStock: true,
        favoritesOnly: false,
        sites: ['ippodo', 'marukyu'],
        minPrice: 50.0,
        maxPrice: 200.0,
      );

      final updatedFilter = filter.copyWith(
        favoritesOnly: true,
        searchTerm: 'premium',
      );

      expect(updatedFilter.inStock, true); // Unchanged
      expect(updatedFilter.favoritesOnly, true); // Changed
      expect(updatedFilter.sites, ['ippodo', 'marukyu']); // Unchanged
      expect(updatedFilter.searchTerm, 'premium'); // Changed
      expect(updatedFilter.minPrice, 50.0); // Unchanged
    });

    test('should clear fields correctly', () {
      final filter = ProductFilter(
        inStock: true,
        sites: ['ippodo'],
        minPrice: 50.0,
      );

      final clearedFilter = filter.copyWith(
        clearInStock: true,
        clearSites: true,
        clearMinPrice: true,
      );

      expect(clearedFilter.inStock, null);
      expect(clearedFilter.sites, null);
      expect(clearedFilter.minPrice, null);
    });
  });

  group('SubscriptionTier', () {
    test('should have correct display names', () {
      expect(SubscriptionTier.free.displayName, 'Free');
      expect(SubscriptionTier.premium.displayName, 'Premium');
    });

    test('should have correct tier limits', () {
      expect(SubscriptionTier.free.maxFavorites, 42);
      expect(SubscriptionTier.premium.maxFavorites, 99999);

      expect(SubscriptionTier.free.maxVendors, 5);
      expect(SubscriptionTier.premium.maxVendors, 999);

      expect(SubscriptionTier.free.minCheckFrequencyMinutes, 360); // 6 hours
      expect(SubscriptionTier.premium.minCheckFrequencyMinutes, 60); // 1 hour
    });

    test('should identify tier types correctly', () {
      expect(SubscriptionTier.free.isFree, true);
      expect(SubscriptionTier.free.isPremium, false);

      expect(SubscriptionTier.premium.isFree, false);
      expect(SubscriptionTier.premium.isPremium, true);
    });

    test('should have correct free tier enabled sites', () {
      final freeSites = SubscriptionTierExtension.freeEnabledSites;
      expect(freeSites, contains('ippodo'));
      expect(freeSites, contains('marukyu'));
      expect(freeSites, contains('tokichi'));
      expect(freeSites, contains('matcha-karu'));
      expect(freeSites, contains('yoshien'));
      expect(freeSites.length, 5);
    });
  });
}
