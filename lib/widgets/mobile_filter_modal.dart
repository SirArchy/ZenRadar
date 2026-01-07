// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/matcha_product.dart';
import '../services/settings_service.dart';
import '../services/product_price_converter.dart';
import '../services/database_service.dart';
import '../services/subscription_service.dart';
import 'dart:math' as math;

class EnhancedPriceDistributionPainter extends CustomPainter {
  final List<double> distribution;
  final double minPrice;
  final double maxPrice;
  final double currentMin;
  final double currentMax;
  final ColorScheme colorScheme;

  EnhancedPriceDistributionPainter({
    required this.distribution,
    required this.minPrice,
    required this.maxPrice,
    required this.currentMin,
    required this.currentMax,
    required this.colorScheme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (distribution.isEmpty) return;

    // Create path for the curve
    final path = Path();
    final paint =
        Paint()
          ..style = PaintingStyle.fill
          ..strokeWidth = 2;

    // Start from bottom left
    path.moveTo(0, size.height);

    // Draw the curve
    for (int i = 0; i < distribution.length; i++) {
      final x = (i / (distribution.length - 1)) * size.width;
      final y =
          size.height -
          (distribution[i] *
              size.height *
              0.8); // Leave space at bottom for slider

      if (i == 0) {
        path.lineTo(x, y);
      } else {
        // Create smooth curve using quadratic bezier
        final prevX = ((i - 1) / (distribution.length - 1)) * size.width;
        final controlX = (prevX + x) / 2;
        final prevY = size.height - (distribution[i - 1] * size.height * 0.8);
        final controlY = (prevY + y) / 2;
        path.quadraticBezierTo(controlX, controlY, x, y);
      }
    }

    // Close the path
    path.lineTo(size.width, size.height);
    path.close();

    // Calculate slider positions for dynamic coloring
    final minSliderPos =
        ((currentMin - minPrice) / (maxPrice - minPrice)) * size.width;
    final maxSliderPos =
        ((currentMax - minPrice) / (maxPrice - minPrice)) * size.width;

    // Create gradient based on slider positions
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        colorScheme.outline.withAlpha(75), // Left area (inactive)
        colorScheme.primary.withAlpha(150), // Selected area
        colorScheme.outline.withAlpha(75), // Right area (inactive)
      ],
      stops: [
        math.max(0.0, minSliderPos / size.width),
        math.min(1.0, maxSliderPos / size.width),
        1.0,
      ],
    );

    paint.shader = gradient.createShader(
      Rect.fromLTWH(0, 0, size.width, size.height),
    );
    canvas.drawPath(path, paint);

    // Draw curve outline
    final outlinePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colorScheme.primary;

    canvas.drawPath(path, outlinePaint);
  }

  @override
  bool shouldRepaint(EnhancedPriceDistributionPainter oldDelegate) {
    return oldDelegate.currentMin != currentMin ||
        oldDelegate.currentMax != currentMax ||
        oldDelegate.distribution != distribution;
  }
}

class MobileFilterModal extends StatefulWidget {
  final ProductFilter filter;
  final Function(ProductFilter) onFilterChanged;
  final List<String> availableSites;
  final List<String> availableCategories;
  final Map<String, double> priceRange;
  final VoidCallback? onClose;

  const MobileFilterModal({
    super.key,
    required this.filter,
    required this.onFilterChanged,
    required this.availableSites,
    required this.availableCategories,
    required this.priceRange,
    this.onClose,
  });

  @override
  State<MobileFilterModal> createState() => _MobileFilterModalState();
}

class _MobileFilterModalState extends State<MobileFilterModal> {
  late ProductFilter _currentFilter;
  late RangeValues _priceRangeValues;
  String _preferredCurrency = 'EUR';
  ProductPriceConverter? _priceConverter;
  int _productCount = 0;
  double _averagePrice = 0.0;
  List<double> _priceDistribution = [];
  bool _isLoadingStatistics = true;

  // Dynamic price range based on filtered products
  double _dynamicMinPrice = 0.0;
  double _dynamicMaxPrice = 1000.0;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.filter;
    _priceRangeValues = RangeValues(
      _currentFilter.minPrice ?? widget.priceRange['min']!,
      _currentFilter.maxPrice ?? widget.priceRange['max']!,
    );
    _initializeCurrency();
    _loadProductStatistics();
  }

  Future<void> _initializeCurrency() async {
    final settings = await SettingsService.instance.getSettings();
    setState(() {
      _preferredCurrency = settings.preferredCurrency;
      _priceConverter = ProductPriceConverter();
    });
  }

  Future<void> _loadProductStatistics() async {
    setState(() {
      _isLoadingStatistics = true;
    });

    try {
      // Check subscription status for free-tier restrictions
      final subscriptionService = SubscriptionService.instance;
      final isPremium = await subscriptionService.isPremiumUser();

      // Create a temporary filter without price constraints to get full price range
      ProductFilter tempFilter = _currentFilter.copyWith(
        minPrice: null,
        maxPrice: null,
      );

      // Apply free-tier site restrictions for non-premium users
      if (!isPremium) {
        const allowedSiteNames = [
          'Ippodo Tea Co',
          'Marukyu Koyamaen',
          'Nakamura Tokichi',
          'Matcha Karu',
          'Yoshien',
        ];

        List<String> restrictedSites;
        if (tempFilter.sites == null || tempFilter.sites!.isEmpty) {
          // If no sites selected, use all allowed sites
          restrictedSites = allowedSiteNames;
        } else {
          // Filter selected sites to only include allowed ones
          restrictedSites =
              tempFilter.sites!
                  .where((site) => allowedSiteNames.contains(site))
                  .toList();
        }

        tempFilter = tempFilter.copyWith(sites: restrictedSites);
      }

      // Get filtered products for both count and price distribution calculation
      final filteredProductsResult = await DatabaseService.platformService
          .getProductsPaginated(
            page: 1,
            itemsPerPage: 10000, // Get all filtered products
            filter: tempFilter, // Use filter with free-tier restrictions
          );

      double totalPrice = 0.0;
      int priceCount = 0;
      List<double> prices = [];

      for (final product in filteredProductsResult.products) {
        if (product.priceValue != null && product.priceValue! > 0) {
          double convertedPrice = product.priceValue!;

          // Convert price to user's preferred currency if different from product currency
          if (product.currency != null &&
              _preferredCurrency != 'Original' &&
              product.currency != _preferredCurrency &&
              _priceConverter != null) {
            try {
              // Use the public convertPrice method to get formatted string
              final convertedString = await _priceConverter!.convertPrice(
                rawPrice: product.price,
                productCurrency: product.currency,
                preferredCurrency: _preferredCurrency,
                siteKey: product.site,
                priceValue: product.priceValue,
              );

              if (convertedString != null) {
                // Extract numeric value from the converted formatted string
                final numericValue = _extractNumericValue(convertedString);
                if (numericValue != null) {
                  print(
                    '💱 Converted ${product.name}: ${product.priceValue} ${product.currency} → $numericValue $_preferredCurrency (formatted: $convertedString)',
                  );
                  convertedPrice = numericValue;
                }
              }
            } catch (e) {
              print('💱 Currency conversion failed for ${product.name}: $e');
              // Keep original price if conversion fails
            }
          }

          totalPrice += convertedPrice;
          priceCount++;
          prices.add(convertedPrice);
        }
      }

      // Calculate dynamic price range from filtered products
      prices.sort();
      double dynamicMin =
          prices.isNotEmpty ? prices.first : widget.priceRange['min']!;
      double dynamicMax =
          prices.isNotEmpty ? prices.last : widget.priceRange['max']!;

      print('💱 Price range calculation: ${prices.length} prices processed');
      print('💱 Currency: $_preferredCurrency');
      print('💱 Raw price range: $dynamicMin - $dynamicMax');

      // Add some padding to the range (5% on each side)
      double padding = (dynamicMax - dynamicMin) * 0.05;
      dynamicMin = math.max(dynamicMin - padding, widget.priceRange['min']!);
      // Ensure dynamic range is valid
      dynamicMin = math.max(dynamicMin - padding, widget.priceRange['min']!);
      dynamicMax = math.min(dynamicMax + padding, widget.priceRange['max']!);

      // Safety check: ensure min <= max
      if (dynamicMin >= dynamicMax) {
        dynamicMin = widget.priceRange['min']!;
        dynamicMax = widget.priceRange['max']!;
      }

      setState(() {
        _productCount =
            filteredProductsResult.products.length; // Use actual filtered count
        _averagePrice = priceCount > 0 ? totalPrice / priceCount : 0.0;
        _priceDistribution = _generatePriceDistribution(prices);
        _dynamicMinPrice = dynamicMin;
        _dynamicMaxPrice = dynamicMax;
        _isLoadingStatistics = false;

        // Update price range values if they're outside the new dynamic range
        // Also ensure the range values are valid and within bounds
        final currentStart = _priceRangeValues.start;
        final currentEnd = _priceRangeValues.end;

        // Ensure the current range values are within the dynamic range bounds
        final safeStart = currentStart.clamp(dynamicMin, dynamicMax);
        final safeEnd = currentEnd.clamp(dynamicMin, dynamicMax);

        // Ensure start <= end
        final finalStart = math.min(safeStart, safeEnd);
        final finalEnd = math.max(safeStart, safeEnd);

        // Always ensure the range values are valid and within bounds
        // This prevents the RangeSlider assertion error
        if (currentStart < dynamicMin ||
            currentStart > dynamicMax ||
            currentEnd < dynamicMin ||
            currentEnd > dynamicMax ||
            currentStart > currentEnd) {
          _priceRangeValues = RangeValues(finalStart, finalEnd);
          print(
            '🔧 Fixed price range values: $currentStart-$currentEnd -> $finalStart-$finalEnd (bounds: $dynamicMin-$dynamicMax)',
          );
        }

        // Additional safety check to prevent RangeSlider exceptions
        if (_priceRangeValues.start < _dynamicMinPrice ||
            _priceRangeValues.end > _dynamicMaxPrice ||
            _priceRangeValues.start > _priceRangeValues.end) {
          final safeStart = _priceRangeValues.start.clamp(
            _dynamicMinPrice,
            _dynamicMaxPrice,
          );
          final safeEnd = _priceRangeValues.end.clamp(
            _dynamicMinPrice,
            _dynamicMaxPrice,
          );
          _priceRangeValues = RangeValues(
            math.min(safeStart, safeEnd),
            math.max(safeStart, safeEnd),
          );
          print(
            '🛡️ Applied safety clamp to price range: ${_priceRangeValues.start}-${_priceRangeValues.end}',
          );
        }
      });

      // Debug logging to track product count updates
      print(
        '📊 Updated product count: $_productCount (filtered products: ${filteredProductsResult.products.length})',
      );
      print('📊 Total items in result: ${filteredProductsResult.totalItems}');
    } catch (e) {
      print('Error loading product statistics: $e');
      // Set default values on error
      setState(() {
        _productCount = 0;
        _averagePrice = 0.0;
        _priceDistribution = List.filled(20, 0.0);
        _isLoadingStatistics = false;
      });
    }
  }

  /// Extract numeric value from formatted price string (e.g., "€12.34" -> 12.34)
  double? _extractNumericValue(String priceString) {
    // Remove currency symbols and extra spaces
    String cleaned =
        priceString
            .replaceAll(RegExp(r'[€\$£¥]|EUR|USD|GBP|JPY|CHF|CAD|AUD'), '')
            .trim();

    // Handle different decimal separator formats
    // European format: 24,50 or 1.234,50
    // American format: 24.50 or 1,234.50

    if (cleaned.contains(',') && cleaned.contains('.')) {
      // Both separators present - determine which is decimal
      final lastComma = cleaned.lastIndexOf(',');
      final lastPeriod = cleaned.lastIndexOf('.');

      if (lastComma > lastPeriod) {
        // European format: 1.234,50
        cleaned = cleaned.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // American format: 1,234.50
        cleaned = cleaned.replaceAll(',', '');
      }
    } else if (cleaned.contains(',')) {
      // Only comma - could be decimal or thousands separator
      final parts = cleaned.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Likely decimal separator: 24,50
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        // Likely thousands separator: 1,234
        cleaned = cleaned.replaceAll(',', '');
      }
    }
    // If only period, assume it's already in correct format

    // Extract just the number
    final match = RegExp(r'(\d+(?:\.\d{1,2})?)').firstMatch(cleaned);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }

    return null;
  }

  List<double> _generatePriceDistribution(List<double> prices) {
    if (prices.isEmpty) return List.filled(20, 0.0);

    // Remove outliers using IQR method, but more aggressively for high prices
    prices.sort();
    final q1Index = (prices.length * 0.25).floor();
    final q3Index = (prices.length * 0.75).floor();
    final q1 = prices[q1Index];
    final q3 = prices[q3Index];
    final iqr = q3 - q1;

    // More aggressive outlier removal for better distribution
    final lowerBound = q1 - 1.0 * iqr;
    final upperBound = q3 + 0.5 * iqr; // More aggressive upper bound

    // Also cap at reasonable price ranges (most matcha is under 100€)
    final effectiveUpperBound = math.min(upperBound, 120.0);

    // Filter out outliers
    final filteredPrices =
        prices
            .where(
              (price) => price >= lowerBound && price <= effectiveUpperBound,
            )
            .toList();

    if (filteredPrices.isEmpty) return List.filled(20, 0.0);

    final minPrice = filteredPrices.first;
    final maxPrice = filteredPrices.last;

    // Use logarithmic scaling to better distribute the buckets
    final logMin = math.log(math.max(minPrice, 0.01));
    final logMax = math.log(maxPrice);
    final logRange = logMax - logMin;

    List<int> buckets = List.filled(20, 0);

    for (final price in filteredPrices) {
      // Convert price to logarithmic scale
      final logPrice = math.log(math.max(price, 0.01));
      final normalizedLogPrice = (logPrice - logMin) / logRange;

      int bucketIndex = (normalizedLogPrice * 19).floor().clamp(0, 19);
      buckets[bucketIndex]++;
    }

    // Apply smoothing to create a more natural curve
    List<double> smoothedBuckets = List.filled(20, 0.0);
    for (int i = 0; i < buckets.length; i++) {
      double sum = buckets[i].toDouble();
      int count = 1;

      // Add neighboring values for smoothing
      if (i > 0) {
        sum += buckets[i - 1] * 0.5;
        count++;
      }
      if (i < buckets.length - 1) {
        sum += buckets[i + 1] * 0.5;
        count++;
      }

      smoothedBuckets[i] = sum / count;
    }

    // Normalize to 0-1 range for visualization
    final maxCount =
        smoothedBuckets.isEmpty
            ? 1
            : smoothedBuckets.reduce((a, b) => a > b ? a : b);
    return smoothedBuckets
        .map((count) => maxCount > 0 ? count / maxCount : 0.0)
        .toList();
  }

  void _updateFilter(ProductFilter newFilter) {
    print('🔄 Updating filter: $newFilter');
    setState(() {
      _currentFilter = newFilter;
    });
    _loadProductStatistics(); // Refresh product count
    widget.onFilterChanged(newFilter);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline.withAlpha(125),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header with title and close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Spacer(),
                const Text(
                  'Filters',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                  style: IconButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: const CircleBorder(),
                  ),
                ),
              ],
            ),
          ),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Price Range Section
                  _buildPriceRangeSection(),
                  const SizedBox(height: 32),

                  // Sites Section
                  _buildSitesSection(),
                  const SizedBox(height: 32),

                  // Categories Section
                  _buildCategoriesSection(),
                  const SizedBox(height: 32),

                  // Switch Section
                  _buildSwitchSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Bottom buttons
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withAlpha(25),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearAllFilters,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outline.withAlpha(125),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.clearAll,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: widget.onClose,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child:
                          _isLoadingStatistics
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : Text(
                                AppLocalizations.of(
                                  context,
                                )!.showProducts(_productCount),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRangeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Price Range',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'The average product price is ${_formatPrice(_averagePrice)}',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
          ),
        ),
        const SizedBox(height: 16),

        // Custom Range Slider with Distribution Curve
        SizedBox(
          height: 80, // Increased height for better visualization
          child: Stack(
            children: [
              // Price distribution visualization
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: 30, // Leave space for slider at bottom
                child: CustomPaint(
                  painter: EnhancedPriceDistributionPainter(
                    distribution: _priceDistribution,
                    minPrice: _dynamicMinPrice,
                    maxPrice: _dynamicMaxPrice,
                    currentMin: _priceRangeValues.start,
                    currentMax: _priceRangeValues.end,
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                ),
              ),
              // Range slider positioned at bottom
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 40,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: Theme.of(context).colorScheme.primary,
                    inactiveTrackColor: Theme.of(
                      context,
                    ).colorScheme.outline.withAlpha(175),
                    thumbColor: Theme.of(context).colorScheme.primary,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 16,
                    ),
                    rangeThumbShape: const RoundRangeSliderThumbShape(
                      enabledThumbRadius: 10,
                    ),
                    rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                    showValueIndicator: ShowValueIndicator.always,
                    valueIndicatorTextStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12,
                    ),
                  ),
                  child: RangeSlider(
                    values: RangeValues(
                      _priceRangeValues.start.clamp(
                        _dynamicMinPrice,
                        _dynamicMaxPrice,
                      ),
                      _priceRangeValues.end.clamp(
                        _dynamicMinPrice,
                        _dynamicMaxPrice,
                      ),
                    ),
                    min: _dynamicMinPrice,
                    max: _dynamicMaxPrice,
                    divisions: 50,
                    labels: RangeLabels(
                      _formatPrice(_priceRangeValues.start),
                      _formatPrice(_priceRangeValues.end),
                    ),
                    onChanged: (values) {
                      setState(() {
                        _priceRangeValues = values;
                      });
                    },
                    onChangeEnd: (values) {
                      _updateFilter(
                        _currentFilter.copyWith(
                          minPrice: values.start,
                          maxPrice: values.end,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        // Price inputs
        Row(
          children: [
            Expanded(
              child: _buildPriceInput(
                'Min Price',
                _priceRangeValues.start,
                true,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildPriceInput(
                'Max Price',
                _priceRangeValues.end,
                false,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPriceInput(String label, double value, bool isMin) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(125),
        ),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: InkWell(
        onTap: () => _showPriceInputDialog(isMin, value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(179),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatPrice(value),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSitesSection() {
    final selectedSites = _currentFilter.sites ?? <String>[];
    final availableSitesWithoutAll =
        widget.availableSites.where((site) => site != 'All').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.sites,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _updateFilter(
                      _currentFilter.copyWith(
                        sites: List<String>.from(availableSitesWithoutAll),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.selectAll,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _updateFilter(_currentFilter.copyWith(sites: <String>[]));
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.clearAll,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Sites in 2-column grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: availableSitesWithoutAll.length,
          itemBuilder: (context, index) {
            final site = availableSitesWithoutAll[index];
            final isSelected = selectedSites.contains(site);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final newSelectedSites = List<String>.from(selectedSites);
                  if (isSelected) {
                    newSelectedSites.remove(site);
                  } else {
                    newSelectedSites.add(site);
                  }
                  _updateFilter(
                    _currentFilter.copyWith(sites: newSelectedSites),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(25)
                            : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                context,
                              ).colorScheme.outline.withAlpha(125),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          site,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoriesSection() {
    if (widget.availableCategories.isEmpty) return const SizedBox.shrink();

    final selectedCategories = _currentFilter.categories ?? <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppLocalizations.of(context)!.categories,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _updateFilter(
                      _currentFilter.copyWith(
                        categories: List<String>.from(
                          widget.availableCategories,
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.selectAll,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    _updateFilter(
                      _currentFilter.copyWith(categories: <String>[]),
                    );
                  },
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.clearAll,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Categories in 2-column grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 4,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: widget.availableCategories.length,
          itemBuilder: (context, index) {
            final category = widget.availableCategories[index];
            final isSelected = selectedCategories.contains(category);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final newSelectedCategories = List<String>.from(
                    selectedCategories,
                  );
                  if (isSelected) {
                    newSelectedCategories.remove(category);
                  } else {
                    newSelectedCategories.add(category);
                  }
                  _updateFilter(
                    _currentFilter.copyWith(categories: newSelectedCategories),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Theme.of(
                              context,
                            ).colorScheme.primary.withAlpha(25)
                            : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                    border: Border.all(
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(
                                context,
                              ).colorScheme.outline.withAlpha(125),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color:
                            isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outline,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight:
                                isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                            color:
                                isSelected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSwitchSection() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Show discontinued products',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Include products that are no longer available',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _currentFilter.showDiscontinued,
            onChanged: (value) {
              HapticFeedback.lightImpact();
              _updateFilter(_currentFilter.copyWith(showDiscontinued: value));
            },
            activeColor: Theme.of(context).colorScheme.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (_priceConverter == null) {
      return '€${price.toStringAsFixed(2)}';
    }

    final symbol = _priceConverter!.getCurrencySymbol(_preferredCurrency);

    switch (_preferredCurrency) {
      case 'JPY':
        return '$symbol${price.round()}';
      case 'EUR':
        return '$symbol${price.toStringAsFixed(2).replaceAll('.', ',')}';
      default:
        return '$symbol${price.toStringAsFixed(2)}';
    }
  }

  Future<void> _showPriceInputDialog(bool isMin, double currentValue) async {
    final controller = TextEditingController(
      text:
          isMin
              ? _priceRangeValues.start.toStringAsFixed(2)
              : _priceRangeValues.end.toStringAsFixed(2),
    );

    final result = await showDialog<double>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Enter ${isMin ? 'Minimum' : 'Maximum'} Price'),
            content: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Price in $_preferredCurrency',
                prefixText:
                    _priceConverter?.getCurrencySymbol(_preferredCurrency) ??
                    '€',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  final value = double.tryParse(controller.text);
                  if (value != null) {
                    Navigator.of(context).pop(value);
                  }
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );

    if (result != null) {
      final minPrice = widget.priceRange['min']!;
      final maxPrice = widget.priceRange['max']!;
      final clampedValue = result.clamp(minPrice, maxPrice);

      setState(() {
        if (isMin) {
          _priceRangeValues = RangeValues(
            clampedValue.clamp(minPrice, _priceRangeValues.end),
            _priceRangeValues.end,
          );
        } else {
          _priceRangeValues = RangeValues(
            _priceRangeValues.start,
            clampedValue.clamp(_priceRangeValues.start, maxPrice),
          );
        }
      });

      _updateFilter(
        _currentFilter.copyWith(
          minPrice: _priceRangeValues.start,
          maxPrice: _priceRangeValues.end,
        ),
      );
    }
  }

  void _clearAllFilters() {
    final clearedFilter = ProductFilter(
      inStock: _currentFilter.inStock, // Preserve stock filter
      showDiscontinued: false,
      favoritesOnly: false,
    );

    setState(() {
      _currentFilter = clearedFilter;
      _priceRangeValues = RangeValues(
        widget.priceRange['min']!,
        widget.priceRange['max']!,
      );
    });

    _updateFilter(clearedFilter);
  }
}

// Custom painter for price distribution visualization
class PriceDistributionPainter extends CustomPainter {
  final List<double> distribution;
  final Color color;

  PriceDistributionPainter({required this.distribution, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (distribution.isEmpty) return;

    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;

    final strokePaint =
        Paint()
          ..color = color.withAlpha(204)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    final path = Path();
    final stepWidth = size.width / distribution.length;

    // Start from bottom left
    path.moveTo(0, size.height);

    // Create points for the curve
    List<Offset> points = [];
    for (int i = 0; i < distribution.length; i++) {
      final x = i * stepWidth + stepWidth / 2; // Center point of bucket
      final y =
          size.height -
          (distribution[i] * size.height * 0.7); // 70% of height max
      points.add(Offset(x, y));
    }

    // Create smooth curve through points
    if (points.isNotEmpty) {
      path.lineTo(points.first.dx, points.first.dy);

      for (int i = 1; i < points.length; i++) {
        final current = points[i];
        final previous = points[i - 1];

        // Create control points for smooth curve
        final controlPoint1 = Offset(
          previous.dx + (current.dx - previous.dx) * 0.3,
          previous.dy,
        );
        final controlPoint2 = Offset(
          previous.dx + (current.dx - previous.dx) * 0.7,
          current.dy,
        );

        path.cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          current.dx,
          current.dy,
        );
      }
    }

    // Close the path
    path.lineTo(size.width, size.height);
    path.close();

    // Draw filled area
    canvas.drawPath(path, paint);

    // Draw stroke line for the curve only (not the base)
    final strokePath = Path();
    if (points.isNotEmpty) {
      strokePath.moveTo(points.first.dx, points.first.dy);

      for (int i = 1; i < points.length; i++) {
        final current = points[i];
        final previous = points[i - 1];

        final controlPoint1 = Offset(
          previous.dx + (current.dx - previous.dx) * 0.3,
          previous.dy,
        );
        final controlPoint2 = Offset(
          previous.dx + (current.dx - previous.dx) * 0.7,
          current.dy,
        );

        strokePath.cubicTo(
          controlPoint1.dx,
          controlPoint1.dy,
          controlPoint2.dx,
          controlPoint2.dy,
          current.dx,
          current.dy,
        );
      }
    }

    canvas.drawPath(strokePath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is PriceDistributionPainter) {
      return oldDelegate.distribution != distribution ||
          oldDelegate.color != color;
    }
    return true;
  }
}
